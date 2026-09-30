import XCTest
@testable import TFYSwiftRouterCore

@MainActor
final class TFYSwiftRouterConcurrencyTests: XCTestCase {
    private struct Route: TFYSwiftRoute { let id: String }

    @MainActor
    private final class Latch {
        private var continuation: CheckedContinuation<Void, Never>?
        private(set) var entered = false
        func wait() async {
            await withCheckedContinuation { continuation = $0; entered = true }
        }
        func release() { continuation?.resume(); continuation = nil }
    }

    @MainActor
    private final class Driver: TFYSwiftNavigationDriver {
        var stacks: [TFYSwiftNavigationScopeID: [TFYSwiftAnyRoute]] = [:]
        var onPresent: ((TFYSwiftRouteTransaction) async throws -> Void)?
        var presented: [TFYSwiftAnyRoute] = []
        var backCalls = 0

        func present(destination: TFYSwiftDestinationDescriptor, route: TFYSwiftAnyRoute,
                     transaction: TFYSwiftRouteTransaction, interaction: TFYSwiftRouteInteraction?) async throws {
            try await onPresent?(transaction)
            let scope = transaction.context.scope
            if case .root = transaction.presentation { stacks[scope] = [route] }
            else { stacks[scope, default: []].append(route) }
            presented.append(route)
        }
        func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool { stacks[scope]?.last == route }
        func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
            guard let stack = stacks[scope], let index = stack.lastIndex(of: route) else { return false }
            stacks[scope] = Array(stack.prefix(through: index))
            return true
        }
        func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] { stacks[scope] ?? [] }
        func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws { backCalls += 1 }
        func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {}
    }

    private func makeRouter(_ driver: Driver) throws -> TFYSwiftRouter {
        let router = TFYSwiftRouter(driver: driver)
        try router.registry.register(Route.self) { _, _ in .init(identifier: "route") }
        return router
    }

    private func waitForEntry(_ latch: Latch) async {
        for _ in 0..<200 where !latch.entered { await Task.yield() }
        XCTAssertTrue(latch.entered, "Expected controlled suspension point")
    }

    func testConcurrentSingleTopRechecksAfterBothResolversSuspend() async throws {
        let driver = Driver()
        let router = TFYSwiftRouter(driver: driver)
        let firstGate = Latch()
        let secondGate = Latch()
        var resolutions = 0
        try router.registry.register(Route.self) { _, _ in
            resolutions += 1
            if resolutions == 1 { await firstGate.wait() }
            else { await secondGate.wait() }
            return .init(identifier: "route")
        }
        let route = Route(id: "same")
        let first = Task { try await router.open(route, deduplication: .singleTop) }
        await waitForEntry(firstGate)
        let second = Task { try await router.open(route, deduplication: .singleTop) }
        await waitForEntry(secondGate)
        secondGate.release()
        try await second.value
        firstGate.release()
        try await first.value
        XCTAssertEqual(resolutions, 2)
        XCTAssertEqual(driver.presented, [TFYSwiftAnyRoute(route)])
    }

    func testSameScopeCommitsWaitWhileOtherScopeRemainsAvailable() async throws {
        let driver = Driver()
        let router = try makeRouter(driver)
        let gate = Latch()
        driver.onPresent = { transaction in
            if transaction.route.cast(to: Route.self)?.id == "first" { await gate.wait() }
        }
        let first = Task { try await router.open(Route(id: "first"), scope: "a") }
        await waitForEntry(gate)
        let second = Task { try await router.open(Route(id: "second"), scope: "a") }
        let back = Task { try await router.back(scope: "a") }
        try await router.open(Route(id: "other"), scope: "b")
        XCTAssertEqual(driver.presented, [TFYSwiftAnyRoute(Route(id: "other"))])
        XCTAssertEqual(driver.backCalls, 0)
        gate.release()
        try await first.value
        try await second.value
        try await back.value
        XCTAssertEqual(driver.stacks["a"], [TFYSwiftAnyRoute(Route(id: "first")), TFYSwiftAnyRoute(Route(id: "second"))])
        XCTAssertEqual(driver.backCalls, 1)
    }

    func testCancelledQueuedRequestDoesNotPresentOrBlockNextRequest() async throws {
        let driver = Driver()
        let router = try makeRouter(driver)
        let gate = Latch()
        driver.onPresent = { transaction in
            if transaction.route.cast(to: Route.self)?.id == "first" { await gate.wait() }
        }
        let first = Task { try await router.open(Route(id: "first")) }
        await waitForEntry(gate)
        let cancelled = Task { try await router.open(Route(id: "cancelled")) }
        for _ in 0..<20 { await Task.yield() }
        cancelled.cancel()
        do { try await cancelled.value; XCTFail("Expected cancellation while queued") }
        catch { XCTAssertTrue(error is CancellationError || error as? TFYSwiftRouteError == .cancelled) }
        let next = Task { try await router.open(Route(id: "next")) }
        gate.release()
        try await first.value
        try await next.value
        XCTAssertEqual(driver.presented, [TFYSwiftAnyRoute(Route(id: "first")), TFYSwiftAnyRoute(Route(id: "next"))])
    }

    func testReentrantSameScopePresentationFailsInsteadOfDeadlocking() async throws {
        let driver = Driver()
        let router = try makeRouter(driver)
        var rejected = false
        driver.onPresent = { transaction in
            guard transaction.route.cast(to: Route.self)?.id == "outer" else { return }
            do { try await router.open(Route(id: "inner")); XCTFail("Expected reentrant rejection") }
            catch { guard case .presentationFailed = error as? TFYSwiftRouteError else { return XCTFail("Unexpected error: \(error)") }; rejected = true }
        }
        try await router.open(Route(id: "outer"))
        XCTAssertTrue(rejected)
        XCTAssertEqual(driver.presented, [TFYSwiftAnyRoute(Route(id: "outer"))])
        driver.onPresent = nil
    }

    func testRestorationRejectsUnrelatedAndOverlappingRequestsButAllowsOtherScope() async throws {
        let driver = Driver()
        let router = try makeRouter(driver)
        let gate = Latch()
        let restoration = Task {
            try await router.withNavigationRestoration(scopes: ["a"]) { await gate.wait() }
        }
        await waitForEntry(gate)
        for source in [TFYSwiftRouteSource.userInteraction, .restoration] {
            do { try await router.open(Route(id: "blocked"), source: source, scope: "a"); XCTFail("Expected scope reservation") }
            catch { guard case .restorationFailed = error as? TFYSwiftRouteError else { return XCTFail("Unexpected error: \(error)") } }
        }
        do { try await router.withNavigationRestoration(scopes: ["a", "b"]) {}; XCTFail("Expected overlapping reservation failure") }
        catch { guard case .restorationFailed = error as? TFYSwiftRouteError else { return XCTFail("Unexpected error: \(error)") } }
        try await router.open(Route(id: "other"), scope: "b")
        gate.release()
        try await restoration.value
        try await router.open(Route(id: "released"), scope: "a")
        XCTAssertEqual(driver.presented.count, 2)
    }

    private func makeSession(_ gate: Latch) -> TFYSwiftRouteSession<Int, Int, String> {
        let commands = TFYSwiftRouteCommandChannel(Int.self)
        let events = TFYSwiftRouteEventChannel(Int.self)
        let interaction = TFYSwiftRouteInteraction(commands: commands, events: events)
        let result = Task<String, Error> { await gate.wait(); interaction.finishChannels(); return "done" }
        return TFYSwiftRouteSession(events: try! events.stream(of: Int.self), commands: commands,
                                    interaction: interaction, resultTask: result)
    }

    func testCancellingOneSessionWaiterKeepsOtherWaiterAndCommandsAlive() async throws {
        let gate = Latch()
        let session = makeSession(gate)
        await waitForEntry(gate)
        let cancelled = Task { try await session.value }
        let surviving = Task { try await session.value }
        for _ in 0..<20 { await Task.yield() }
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Expected subscriber cancellation") }
        catch { XCTAssertEqual(error as? TFYSwiftRouteError, .cancelled) }
        try session.send(1)
        gate.release()
        let output = try await surviving.value
        XCTAssertEqual(output, "done")
        let repeated = try await session.value
        XCTAssertEqual(repeated, "done")
    }

    func testSessionCancellationUnblocksAllWaitersWithoutWaitingForProducer() async throws {
        let gate = Latch()
        let session = makeSession(gate)
        await waitForEntry(gate)
        defer { gate.release() }
        let first = Task { try await session.value }
        let second = Task { try await session.value }
        session.cancel()
        for waiter in [first, second] {
            do { _ = try await waiter.value; XCTFail("Expected session cancellation") }
            catch { XCTAssertEqual(error as? TFYSwiftRouteError, .cancelled) }
        }
        XCTAssertThrowsError(try session.send(1))
        var events = session.events.makeAsyncIterator()
        let end = await events.next()
        XCTAssertNil(end)
    }

    func testSessionTimeoutEndsAllWaitersAndChannels() async throws {
        let gate = Latch()
        let session = makeSession(gate)
        await waitForEntry(gate)
        defer { gate.release() }
        let waiting = Task { try await session.value }
        do { _ = try await session.value(timeout: 0.01); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? TFYSwiftRouteError, .timeout) }
        do { _ = try await waiting.value; XCTFail("Other waiter must receive same timeout") }
        catch { XCTAssertEqual(error as? TFYSwiftRouteError, .timeout) }
        XCTAssertThrowsError(try session.send(1))
    }

    func testCancellingTimedWaiterDoesNotEndSessionOrTriggerTimeout() async throws {
        let gate = Latch()
        let session = makeSession(gate)
        await waitForEntry(gate)
        let waiting = Task { try await session.value(timeout: 60) }
        for _ in 0..<20 { await Task.yield() }
        waiting.cancel()
        do { _ = try await waiting.value; XCTFail("Expected subscriber cancellation") }
        catch { XCTAssertEqual(error as? TFYSwiftRouteError, .cancelled) }
        try session.send(1)
        gate.release()
        let output = try await session.value
        XCTAssertEqual(output, "done")
    }

    func testHistoryShrinksImmediatelyAndClampsMutatedCapacity() {
        let history = TFYSwiftRouteHistory(capacity: 4)
        for _ in 0..<4 {
            history.routerDidEmit(.init(transactionID: UUID(), name: .created, routeName: "route", scope: .main, elapsedMilliseconds: 0))
        }
        let lastID = history.events.last?.id
        var notifications = 0
        history.onChange = { notifications += 1 }
        history.capacity = -10
        XCTAssertEqual(history.capacity, 1)
        XCTAssertEqual(history.events.count, 1)
        XCTAssertEqual(history.events.last?.id, lastID)
        XCTAssertEqual(notifications, 1)
    }
}

import XCTest
@testable import TFYSwiftRouterCore

final class TFYSwiftRouterCoreRegressionTests: XCTestCase {
    private struct Route: TFYSwiftRoute {
        let id: String
    }

    @MainActor
    private final class ResolverGate {
        private(set) var isWaiting = false
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            isWaiting = true
            await withCheckedContinuation { continuation = $0 }
        }

        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    @MainActor
    private final class Driver: TFYSwiftNavigationDriver {
        var stack: [TFYSwiftAnyRoute] = []
        var immediateResult: String?
        var afterImmediateResult: (() -> Void)?
        var presentationError: Error?
        var activationCalls = 0

        func present(
            destination: TFYSwiftDestinationDescriptor,
            route: TFYSwiftAnyRoute,
            transaction: TFYSwiftRouteTransaction,
            interaction: TFYSwiftRouteInteraction?
        ) async throws {
            stack.append(route)
            if let immediateResult {
                interaction?.result?.finish(with: immediateResult)
                afterImmediateResult?()
            }
            if let presentationError { throw presentationError }
        }

        func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
            stack.last == route
        }

        func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
            activationCalls += 1
            guard let index = stack.lastIndex(of: route) else { return false }
            stack = Array(stack.prefix(through: index))
            return true
        }

        func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] { stack }
        func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {}
        func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {}
    }

    @MainActor
    func testCancellingResultWhileResolvingPreventsPresentation() async throws {
        let gate = ResolverGate()
        let driver = Driver()
        let router = TFYSwiftRouter(driver: driver)
        try router.registry.register(Route.self) { _, _ in
            await gate.wait()
            return TFYSwiftDestinationDescriptor(identifier: "route")
        }

        let task = Task { @MainActor in
            try await router.open(Route(id: "cancel"), expecting: String.self)
        }
        for _ in 0..<100 where !gate.isWaiting { await Task.yield() }
        XCTAssertTrue(gate.isWaiting)

        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {}
        gate.resume()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertTrue(driver.stack.isEmpty)
        XCTAssertEqual(router.transactionStates.values.first, .cancelled)
    }

    @MainActor
    func testImmediateResultKeepsCompletedAsTerminalState() async throws {
        let driver = Driver()
        driver.immediateResult = "done"
        let router = TFYSwiftRouter(driver: driver)
        let history = TFYSwiftRouteHistory()
        router.events.add(history)
        try router.registry.register(Route.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "route")
        }

        let result = try await router.open(Route(id: "instant"), expecting: String.self)

        XCTAssertEqual(result, "done")
        XCTAssertEqual(router.transactionStates.values.first, .completed)
        XCTAssertEqual(history.events.last?.name, .completed)
    }

    @MainActor
    func testClearingDiagnosticsDuringPresentationStillRecordsFinalState() async throws {
        let driver = Driver()
        driver.immediateResult = "done"
        let router = TFYSwiftRouter(driver: driver)
        driver.afterImmediateResult = { router.removeAllTransactionStates() }
        try router.registry.register(Route.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "route")
        }

        let result = try await router.open(Route(id: "instant"), expecting: String.self)

        XCTAssertEqual(result, "done")
        XCTAssertEqual(router.transactionStates.values.first, .completed)
    }

    @MainActor
    func testSingleTaskWithResultDoesNotActivateExistingRouteBeforeRejecting() async throws {
        let driver = Driver()
        let route = TFYSwiftAnyRoute(Route(id: "existing"))
        driver.stack = [route, TFYSwiftAnyRoute(Route(id: "child"))]
        let router = TFYSwiftRouter(driver: driver)

        do {
            let _: String = try await router.open(
                Route(id: "existing"),
                deduplication: .singleTask,
                expecting: String.self
            )
            XCTFail("Expected result/reuse rejection")
        } catch let error as TFYSwiftRouteError {
            guard case .destinationUnavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(driver.activationCalls, 0)
        XCTAssertEqual(driver.stack, [route, TFYSwiftAnyRoute(Route(id: "child"))])
    }

    @MainActor
    func testPresentationFailureWinsOverResultFinishedDuringPresentation() async throws {
        let driver = Driver()
        driver.immediateResult = "too-early"
        driver.presentationError = TFYSwiftRouteError.presentationFailed("failed after callback")
        let router = TFYSwiftRouter(driver: driver)
        let history = TFYSwiftRouteHistory()
        router.events.add(history)
        try router.registry.register(Route.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "route")
        }

        do {
            let _: String = try await router.open(Route(id: "failure"), expecting: String.self)
            XCTFail("Expected presentation failure")
        } catch let error as TFYSwiftRouteError {
            guard case .presentationFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        guard case .failed(let message)? = router.transactionStates.values.first else {
            return XCTFail("Expected failed terminal state")
        }
        XCTAssertTrue(message.contains("failed after callback"))
        XCTAssertFalse(history.events.contains { $0.name == .completed })
    }

    @MainActor
    func testSingleTaskWithInputDoesNotActivateExistingRoute() async throws {
        let driver = Driver()
        let route = TFYSwiftAnyRoute(Route(id: "existing"))
        driver.stack = [route, TFYSwiftAnyRoute(Route(id: "child"))]
        let router = TFYSwiftRouter(driver: driver)

        do {
            try await router.open(
                Route(id: "existing"),
                input: "replacement",
                deduplication: .singleTask
            )
            XCTFail("Expected input/reuse rejection")
        } catch let error as TFYSwiftRouteError {
            guard case .destinationUnavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(driver.activationCalls, 0)
        XCTAssertEqual(driver.stack, [route, TFYSwiftAnyRoute(Route(id: "child"))])
    }

    @MainActor
    func testSingleTopWithInputDoesNotSilentlyDiscardInput() async throws {
        let driver = Driver()
        let route = TFYSwiftAnyRoute(Route(id: "top"))
        driver.stack = [route]
        let router = TFYSwiftRouter(driver: driver)

        do {
            try await router.open(Route(id: "top"), input: 42, deduplication: .singleTop)
            XCTFail("Expected input/reuse rejection")
        } catch let error as TFYSwiftRouteError {
            guard case .destinationUnavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(driver.stack, [route])
    }
}

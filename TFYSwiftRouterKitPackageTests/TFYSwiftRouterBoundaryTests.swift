import XCTest
@testable import TFYSwiftRouterCore
import TFYSwiftRouterDeepLink
import TFYSwiftRouterTesting

@MainActor
final class TFYSwiftRouterBoundaryTests: XCTestCase {
    private struct Route: TFYSwiftRoute { let id: String }

    @MainActor
    private final class Latch {
        private var continuation: CheckedContinuation<Void, Never>?
        private(set) var entered = false

        func wait() async {
            await withCheckedContinuation {
                continuation = $0
                entered = true
            }
        }

        func release() {
            continuation?.resume()
            continuation = nil
        }
    }

    private struct Parser: TFYSwiftDeepLinkParser {
        let identifier: String
        let handler: @MainActor @Sendable () async -> TFYSwiftAnyRoute?
        func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
            await handler()
        }
    }

    func testCancelledDeepLinkStopsBeforeNextParser() async throws {
        let latch = Latch()
        var nextParserCalls = 0
        let engine = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tests"))
        await engine.add(Parser(identifier: "first") { await latch.wait(); return nil }, priority: 10)
        await engine.add(Parser(identifier: "next") {
            nextParserCalls += 1
            return TFYSwiftAnyRoute(Route(id: "next"))
        })
        let request = TFYSwiftDeepLinkRequest(url: try XCTUnwrap(URL(string: "tests://detail")))
        let task = Task { try await engine.route(for: request) }
        for _ in 0..<200 where !latch.entered { await Task.yield() }
        XCTAssertTrue(latch.entered)
        task.cancel()
        latch.release()

        do { _ = try await task.value; XCTFail("Cancelled parsing must not return a route") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(nextParserCalls, 0)
    }

    func testCancelledDeepLinkDiscardsLateParserResult() async throws {
        let latch = Latch()
        let engine = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tests"))
        await engine.add(Parser(identifier: "late") {
            await latch.wait()
            return TFYSwiftAnyRoute(Route(id: "late"))
        })
        let request = TFYSwiftDeepLinkRequest(url: try XCTUnwrap(URL(string: "tests://detail")))
        let task = Task { try await engine.route(for: request) }
        for _ in 0..<200 where !latch.entered { await Task.yield() }
        XCTAssertTrue(latch.entered)
        task.cancel()
        latch.release()
        do { _ = try await task.value; XCTFail("Late success must not override cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testCancelledInterceptorStopsBeforeNextHandler() async throws {
        let latch = Latch()
        let pipeline = TFYSwiftInterceptorPipeline()
        var nextHandlerCalls = 0
        pipeline.add(identifier: "first", priority: 10) { _ in
            await latch.wait()
            return .proceed
        }
        pipeline.add(identifier: "next") { _ in nextHandlerCalls += 1; return .proceed }
        let transaction = TFYSwiftRouteTransaction(
            route: TFYSwiftAnyRoute(Route(id: "cancel")), context: .init(),
            presentation: .automatic, deduplication: .none
        )
        let task = Task { await pipeline.run(transaction) }
        for _ in 0..<200 where !latch.entered { await Task.yield() }
        XCTAssertTrue(latch.entered)
        task.cancel()
        latch.release()
        guard case .reject(.cancelled) = await task.value else {
            return XCTFail("Pipeline must return cancellation")
        }
        XCTAssertEqual(nextHandlerCalls, 0)
    }

    func testOlderTestSessionDoesNotRemoveNewerInteraction() async throws {
        let router = TFYSwiftTestRouter()
        let route = Route(id: "same")
        let firstLatch = Latch()
        let secondLatch = Latch()
        var calls = 0
        router.provide(String.self, asyncResult: {
            calls += 1
            if calls == 1 { await firstLatch.wait() }
            else { await secondLatch.wait() }
            return "done"
        })
        let first = router.openSession(route, input: "first", commands: Int.self, events: Int.self, expecting: String.self)
        for _ in 0..<200 where !firstLatch.entered { await Task.yield() }
        XCTAssertTrue(firstLatch.entered)
        let second = router.openSession(route, input: "second", commands: Int.self, events: Int.self, expecting: String.self)
        let newest = try XCTUnwrap(router.interaction(for: route))
        for _ in 0..<200 where !secondLatch.entered { await Task.yield() }
        XCTAssertTrue(secondLatch.entered)
        firstLatch.release()
        _ = try await first.value
        XCTAssertTrue(router.interaction(for: route) === newest)
        try XCTUnwrap(newest.events).send(42)
        var iterator = second.events.makeAsyncIterator()
        let event = await iterator.next()
        XCTAssertEqual(event, 42)
        secondLatch.release()
        _ = try await second.value
        XCTAssertNil(router.interaction(for: route))
    }

    func testImmediatelyCancelledTestSessionDoesNotCallProvider() async throws {
        let router = TFYSwiftTestRouter()
        var calls = 0
        router.provide(String.self) { calls += 1; return "unexpected" }
        let route = Route(id: "cancel")
        let session = router.openSession(route, input: (), commands: Int.self, events: Int.self, expecting: String.self)
        session.cancel()
        do { _ = try await session.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? TFYSwiftRouteError, .cancelled) }
        // Allow the provider task to run its cancellation cleanup.
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(calls, 0)
        XCTAssertNil(router.interaction(for: route))
    }

    func testCancelledTestResultDiscardsNonCooperativeProviderSuccess() async throws {
        let router = TFYSwiftTestRouter()
        let latch = Latch()
        router.provide(String.self, asyncResult: { await latch.wait(); return "late" })
        let task = Task { try await router.open(Route(id: "cancel"), expecting: String.self) }
        for _ in 0..<200 where !latch.entered { await Task.yield() }
        XCTAssertTrue(latch.entered)
        task.cancel()
        latch.release()
        do { _ = try await task.value; XCTFail("Late success must not override cancellation") }
        catch { XCTAssertEqual(error as? TFYSwiftRouteError, .cancelled) }
    }
}

import XCTest
import SwiftUI
@testable import TFYSwiftRouterKit

final class TFYSwiftRouterKitTests: XCTestCase {
    private enum TestRoute: Hashable, Codable, Sendable, TFYSwiftRoute {
        case detail(id: String)
        case legacy(id: String)
    }

    private enum OtherRoute: Hashable, Sendable, TFYSwiftRoute { case other }
    private struct ProductInput: Sendable, Equatable { let id: String; let attributes: [String: String] }
    private enum ProductCommand: Sendable, Equatable { case refresh; case select(Int) }
    private enum ProductEvent: Sendable, Equatable { case tapped(String) }
    private struct ProductOutput: Sendable, Equatable { let accepted: Bool }

    private struct ContractRoute: Hashable, Sendable, TFYSwiftRouteContract {
        typealias Input = ProductInput
        typealias Output = ProductOutput
        let id: String
    }

    private protocol CartServicing: TFYSwiftComponentService {
        func count() async -> Int
    }

    private actor CartService: CartServicing {
        func count() async -> Int { 7 }
    }

    private struct TestParser: TFYSwiftDeepLinkParser {
        let identifier = "tests"
        func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
            guard request.url.host == "detail", let id = request.url.pathComponents.last, id != "/" else { return nil }
            return TFYSwiftAnyRoute(TestRoute.detail(id: id))
        }
    }

    @MainActor
    private final class RedirectInterceptor: TFYSwiftRouteInterceptor {
        let identifier = "redirect"
        func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
            guard case .legacy(let id)? = transaction.route.cast(to: TestRoute.self) else { return .proceed }
            return .redirect(TFYSwiftAnyRoute(TestRoute.detail(id: id)))
        }
    }

    @MainActor
    private final class RepeatingSuspensionInterceptor: TFYSwiftRouteInterceptor {
        let identifier = "repeating-suspension"
        func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
            .suspend(TFYSwiftRouteSuspension(reason: "repeat") { true })
        }
    }

    @MainActor
    private final class Driver: TFYSwiftNavigationDriver {
        var presented: [TFYSwiftAnyRoute] = []
        var interaction: TFYSwiftRouteInteraction?
        func present(destination: TFYSwiftDestinationDescriptor, route: TFYSwiftAnyRoute, transaction: TFYSwiftRouteTransaction, interaction: TFYSwiftRouteInteraction?) async throws {
            presented.append(route)
            self.interaction = interaction
        }
        func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool { presented.last == route }
        func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool { false }
        func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] { presented }
        func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {}
        func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {}
    }

    func testAnyRoutePreservesTypeAndValue() {
        let route = TestRoute.detail(id: "42")
        let erased = TFYSwiftAnyRoute(route)
        XCTAssertEqual(erased.cast(to: TestRoute.self), route)
        XCTAssertEqual(erased, TFYSwiftAnyRoute(route))
        XCTAssertNil(erased.cast(to: OtherRoute.self))
    }

    @MainActor
    func testRegistryResolvesTypedRouteAndRejectsDuplicate() async throws {
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "test.detail") }
        let descriptor = try await registry.resolve(TFYSwiftAnyRoute(TestRoute.detail(id: "1")), context: TFYSwiftRouteContext())
        XCTAssertEqual(descriptor.identifier, "test.detail")
        XCTAssertThrowsError(try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "duplicate") })
    }

    @MainActor
    func testRouterRedirectsThenPresentsResolvedRoute() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "test") }
        let pipeline = TFYSwiftInterceptorPipeline()
        pipeline.add(RedirectInterceptor())
        let router = TFYSwiftRouter(registry: registry, interceptors: pipeline, events: TFYSwiftRouteEventCenter(), driver: driver)
        try await router.open(TestRoute.legacy(id: "9"), presentation: .push())
        XCTAssertEqual(driver.presented, [TFYSwiftAnyRoute(TestRoute.detail(id: "9"))])
        XCTAssertTrue(router.transactionStates.values.contains(.completed))
    }

    @MainActor
    func testSingleTopDeduplication() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "test") }
        let router = TFYSwiftRouter(registry: registry, interceptors: TFYSwiftInterceptorPipeline(), events: TFYSwiftRouteEventCenter(), driver: driver)
        let route = TestRoute.detail(id: "same")
        try await router.open(route, presentation: .push(), deduplication: .singleTop)
        try await router.open(route, presentation: .push(), deduplication: .singleTop)
        XCTAssertEqual(driver.presented.count, 1)
    }

    func testDeepLinkValidationAndParsing() async throws {
        let engine = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tfytest"))
        await engine.add(TestParser())
        let route = try await engine.route(for: TFYSwiftDeepLinkRequest(url: try XCTUnwrap(URL(string: "tfytest://detail/abc"))))
        XCTAssertEqual(route.cast(to: TestRoute.self), .detail(id: "abc"))
        do {
            _ = try await engine.route(for: TFYSwiftDeepLinkRequest(url: try XCTUnwrap(URL(string: "unsafe://detail/abc"))))
            XCTFail("Expected policy rejection")
        } catch let error as TFYSwiftRouteError {
            guard case .invalidDeepLink = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    @MainActor
    func testRestorationUsesExplicitWhitelist() throws {
        let registry = TFYSwiftRestorationRegistry()
        try registry.register(TestRoute.self, identifier: "test.route.v1")
        let original = TFYSwiftAnyRoute(TestRoute.detail(id: "restore"))
        let descriptor = try XCTUnwrap(registry.descriptor(for: original))
        XCTAssertEqual(try registry.route(from: descriptor), original)
    }

    @MainActor
    func testTestRouterRecordsIntentAndProvidesResult() async throws {
        let router = TFYSwiftTestRouter()
        router.provide(String.self) { "selected" }
        let result: String = try await router.open(TestRoute.detail(id: "3"), presentation: .sheet(), expecting: String.self)
        XCTAssertEqual(result, "selected")
        XCTAssertEqual(router.actions, [.open(route: TFYSwiftAnyRoute(TestRoute.detail(id: "3")), presentation: .sheet())])
    }

    @MainActor
    func testNativeSwiftUIDriverMaintainsNavigationPath() async throws {
        let destinations = TFYSwiftSwiftUIDestinationRegistry()
        try destinations.register(identifier: "swiftui.test", routeType: TestRoute.self) { _, _ in Text("Destination") }
        let driver = TFYSwiftSwiftUINavigationDriver(destinations: destinations)
        let route = TFYSwiftAnyRoute(TestRoute.detail(id: "swiftui"))
        let context = TFYSwiftRouteContext()
        let transaction = TFYSwiftRouteTransaction(
            route: route,
            context: context,
            presentation: .push(),
            deduplication: .none
        )

        try await driver.present(
            destination: TFYSwiftDestinationDescriptor(identifier: "swiftui.test"),
            route: route,
            transaction: transaction,
            interaction: nil
        )

        XCTAssertEqual(driver.path.map(\.route), [route])
        try await driver.backToRoot(in: .main)
        XCTAssertTrue(driver.path.isEmpty)
    }

    @MainActor
    func testPayloadSupportsNonHashableModelAndReportsTypeMismatch() throws {
        let payload = TFYSwiftRoutePayload(ProductInput(id: "p1", attributes: ["color": "blue"]))
        XCTAssertEqual(try payload.value(as: ProductInput.self).id, "p1")
        XCTAssertThrowsError(try payload.value(as: String.self)) { error in
            guard case TFYSwiftRouteError.inputTypeMismatch = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    func testBidirectionalSessionPassesInputCommandsEventsAndFinalResult() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "interactive") }
        let router = TFYSwiftRouter(
            registry: registry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
        let input = ProductInput(id: "p2", attributes: ["size": "L"])
        let session = router.openSession(
            TestRoute.detail(id: input.id),
            input: input,
            presentation: .push(),
            commands: ProductCommand.self,
            events: ProductEvent.self,
            expecting: ProductOutput.self
        )

        for _ in 0..<5 where driver.interaction == nil { await Task.yield() }
        let interaction = try XCTUnwrap(driver.interaction)
        XCTAssertEqual(try interaction.input?.value(as: ProductInput.self), input)

        var commands = try XCTUnwrap(interaction.commands).stream(of: ProductCommand.self).makeAsyncIterator()
        try session.send(.select(3))
        let receivedCommand = await commands.next()
        XCTAssertEqual(receivedCommand, .select(3))

        var events = session.events.makeAsyncIterator()
        try XCTUnwrap(interaction.events).send(ProductEvent.tapped("buy"))
        let receivedEvent = await events.next()
        XCTAssertEqual(receivedEvent, .tapped("buy"))

        interaction.result?.finish(with: ProductOutput(accepted: true))
        let output = try await session.value
        XCTAssertEqual(output, ProductOutput(accepted: true))
        let endEvent = await events.next()
        XCTAssertNil(endEvent)
    }

    @MainActor
    func testComponentServiceRegistryUsesProtocolKeyAndProtectsDuplicates() async throws {
        let services = TFYSwiftComponentServiceRegistry()
        let key = TFYSwiftComponentServiceKey<any CartServicing>()
        let service: any CartServicing = CartService()
        try services.register(service, for: key)
        XCTAssertTrue(services.contains(key))
        let resolved = try services.resolve(key)
        let count = await resolved.count()
        XCTAssertEqual(count, 7)
        XCTAssertThrowsError(try services.register(service, for: key))
        services.unregister(key)
        XCTAssertFalse(services.contains(key))
    }

    @MainActor
    func testScopedDriverKeepsIndependentNavigationContainers() async throws {
        let home = Driver()
        let cart = Driver()
        let scoped = TFYSwiftScopedNavigationDriver()
        let homeScope: TFYSwiftNavigationScopeID = "test.home"
        let cartScope: TFYSwiftNavigationScopeID = "test.cart"
        try scoped.register(home, for: homeScope, replacingExisting: false)
        try scoped.register(cart, for: cartScope, replacingExisting: false)

        let homeRoute = TFYSwiftAnyRoute(TestRoute.detail(id: "home"))
        let cartRoute = TFYSwiftAnyRoute(TestRoute.detail(id: "cart"))
        try await scoped.present(
            destination: TFYSwiftDestinationDescriptor(identifier: "home.detail"),
            route: homeRoute,
            transaction: TFYSwiftRouteTransaction(
                route: homeRoute,
                context: TFYSwiftRouteContext(scope: homeScope),
                presentation: .push(),
                deduplication: .none
            ),
            interaction: nil
        )
        try await scoped.present(
            destination: TFYSwiftDestinationDescriptor(identifier: "cart.detail"),
            route: cartRoute,
            transaction: TFYSwiftRouteTransaction(
                route: cartRoute,
                context: TFYSwiftRouteContext(scope: cartScope),
                presentation: .push(),
                deduplication: .none
            ),
            interaction: nil
        )

        XCTAssertEqual(scoped.routes(in: homeScope), [homeRoute])
        XCTAssertEqual(scoped.routes(in: cartScope), [cartRoute])
    }

    @MainActor
    func testFourTabDemoCompositionRegistersAndInstallsRootsByRoute() async throws {
        let coordinator = try TFYSwiftDemoAppCoordinator()
        XCTAssertEqual(coordinator.tabBarController.viewControllers?.count, 4)
        XCTAssertEqual(coordinator.assembly.routes.registeredRouteNames.count, 4)
        XCTAssertEqual(coordinator.assembly.destinations.registeredDestinationIDs.count, 16)
        XCTAssertTrue(coordinator.assembly.destinations.contains("home.laboratory"))
        XCTAssertEqual(
            coordinator.tabBarController.viewControllers?.compactMap { $0.tabBarItem.title },
            ["首页", "商品", "购物车", "我的"]
        )

        try await coordinator.start()
        XCTAssertEqual(
            coordinator.assembly.scopedDriver.routes(in: TFYSwiftDemoTab.home.scope),
            [TFYSwiftAnyRoute(TFYSwiftDemoHomeRoute.root)]
        )
        XCTAssertEqual(
            coordinator.assembly.scopedDriver.routes(in: TFYSwiftDemoTab.products.scope),
            [TFYSwiftAnyRoute(TFYSwiftDemoProductRoute.root)]
        )
        XCTAssertEqual(
            coordinator.assembly.scopedDriver.routes(in: TFYSwiftDemoTab.cart.scope),
            [TFYSwiftAnyRoute(TFYSwiftDemoCartRoute.root)]
        )
        XCTAssertEqual(
            coordinator.assembly.scopedDriver.routes(in: TFYSwiftDemoTab.profile.scope),
            [TFYSwiftAnyRoute(TFYSwiftDemoProfileRoute.root)]
        )
    }

    @MainActor
    func testCompletedSessionReleasesInteractionCycle() async throws {
        let driver = Driver()
        let router = TFYSwiftRouter(driver: driver)
        try router.registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "result") }

        var session: TFYSwiftRouteSession<ProductCommand, ProductEvent, ProductOutput>? = router.openSession(
            TestRoute.detail(id: "release"),
            input: ProductInput(id: "release", attributes: [:]),
            commands: ProductCommand.self,
            events: ProductEvent.self,
            expecting: ProductOutput.self
        )
        for _ in 0..<10 where driver.interaction == nil { await Task.yield() }
        weak let weakInteraction = driver.interaction
        driver.interaction?.result?.finish(with: ProductOutput(accepted: true))
        _ = try await session?.value
        driver.interaction = nil
        session = nil
        await Task.yield()
        XCTAssertNil(weakInteraction)
    }

    @MainActor
    func testSwiftUIFactoryFailurePropagatesToRouter() async throws {
        let destinations = TFYSwiftSwiftUIDestinationRegistry()
        try destinations.register(identifier: "throwing", routeType: TestRoute.self) { _, _ -> Text in
            throw TFYSwiftRouteError.destinationUnavailable("factory")
        }
        let driver = TFYSwiftSwiftUINavigationDriver(destinations: destinations)
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "throwing") }
        let router = TFYSwiftRouter(
            registry: registry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )

        await XCTAssertThrowsErrorAsync {
            try await router.open(TestRoute.detail(id: "factory"))
        }
        XCTAssertTrue(driver.path.isEmpty)
    }

    @MainActor
    func testAssemblyRegistrationRollsBackWhenDestinationFails() throws {
        let assembly = TFYSwiftRouterAssembly(navigationController: UINavigationController())
        try assembly.destinations.register(identifier: "duplicate", routeType: TestRoute.self) { _, _ in UIViewController() }

        XCTAssertThrowsError(try assembly.register(TestRoute.self, destinationID: "duplicate") { _, _ in UIViewController() })
        XCTAssertFalse(assembly.routes.contains(TestRoute.self))
    }

    @MainActor
    func testSuspensionLoopIsBounded() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "test") }
        let pipeline = TFYSwiftInterceptorPipeline()
        pipeline.add(RepeatingSuspensionInterceptor())
        let router = TFYSwiftRouter(registry: registry, interceptors: pipeline, events: TFYSwiftRouteEventCenter(), driver: driver)
        router.maximumSuspensionDepth = 2

        do {
            try await router.open(TestRoute.detail(id: "loop"))
            XCTFail("Expected suspension loop")
        } catch let error as TFYSwiftRouteError {
            XCTAssertEqual(error, .suspensionLoop)
        }
    }

    @MainActor
    func testResultTimeoutCancelsPendingInteraction() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "timeout") }
        let router = TFYSwiftRouter(registry: registry, interceptors: TFYSwiftInterceptorPipeline(), events: TFYSwiftRouteEventCenter(), driver: driver)

        do {
            let _: ProductOutput = try await router.open(
                TestRoute.detail(id: "timeout"),
                timeout: 0.02,
                expecting: ProductOutput.self
            )
            XCTFail("Expected timeout")
        } catch let error as TFYSwiftRouteError {
            XCTAssertEqual(error, .timeout)
        }
    }

    @MainActor
    func testRestorationCoordinatorSnapshotsAndRestoresNavigationStack() async throws {
        let destinations = TFYSwiftSwiftUIDestinationRegistry()
        try destinations.register(identifier: "restore", routeType: TestRoute.self) { _, _ in Text("Restore") }
        let driver = TFYSwiftSwiftUINavigationDriver(destinations: destinations)
        let routes = TFYSwiftRouteRegistry()
        try routes.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "restore") }
        let router = TFYSwiftRouter(registry: routes, interceptors: TFYSwiftInterceptorPipeline(), events: TFYSwiftRouteEventCenter(), driver: driver)
        let restoration = TFYSwiftRestorationRegistry()
        try restoration.register(TestRoute.self, identifier: "test.route.v1")
        let coordinator = TFYSwiftRestorationCoordinator(registry: restoration, router: router)

        try await router.open(TestRoute.detail(id: "root"), presentation: .root())
        try await router.open(TestRoute.detail(id: "child"), presentation: .push())
        let snapshot = try coordinator.makeSnapshot(scopes: [.main])
        try await router.backToRoot()
        try await coordinator.restore(snapshot)

        XCTAssertEqual(router.navigationRoutes().compactMap { $0.cast(to: TestRoute.self) }, [
            .detail(id: "root"), .detail(id: "child")
        ])
    }

    @MainActor
    func testSwiftUIReplacingSheetCancelsPreviousInteraction() async throws {
        let destinations = TFYSwiftSwiftUIDestinationRegistry()
        try destinations.register(identifier: "sheet", routeType: TestRoute.self) { _, _ in Text("Sheet") }
        let driver = TFYSwiftSwiftUINavigationDriver(destinations: destinations)
        var wasCancelled = false
        let firstResult = TFYSwiftRouteResult(
            transactionID: UUID(),
            finish: { _ in },
            cancel: { _ in wasCancelled = true }
        )
        let firstInteraction = TFYSwiftRouteInteraction(result: firstResult)

        for (id, interaction) in [("first", firstInteraction), ("second", nil)] {
            let route = TFYSwiftAnyRoute(TestRoute.detail(id: id))
            try await driver.present(
                destination: TFYSwiftDestinationDescriptor(identifier: "sheet"),
                route: route,
                transaction: TFYSwiftRouteTransaction(
                    route: route,
                    context: TFYSwiftRouteContext(),
                    presentation: .sheet(),
                    deduplication: .none
                ),
                interaction: interaction
            )
        }

        XCTAssertTrue(wasCancelled)
    }

    @MainActor
    func testTransactionStateHistoryIsBounded() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "test") }
        let router = TFYSwiftRouter(registry: registry, interceptors: TFYSwiftInterceptorPipeline(), events: TFYSwiftRouteEventCenter(), driver: driver)
        router.transactionStateCapacity = 2

        for id in 0..<3 { try await router.open(TestRoute.detail(id: "\(id)")) }
        XCTAssertEqual(router.transactionStates.count, 2)
    }

    @MainActor
    func testTypedRouteContractInfersInputAndOutput() async throws {
        let router = TFYSwiftTestRouter()
        router.provide(ProductOutput.self) { ProductOutput(accepted: true) }
        let input = ProductInput(id: "typed", attributes: [:])

        let output = try await router.openTyped(ContractRoute(id: input.id), input: input)

        XCTAssertEqual(output, ProductOutput(accepted: true))
        XCTAssertEqual(router.invocations.first?.inputTypeName, String(reflecting: ProductInput.self))
    }

    @MainActor
    func testImmediateSessionCancellationClosesCreatedTransaction() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(TestRoute.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "cancel") }
        let router = TFYSwiftRouter(registry: registry, interceptors: TFYSwiftInterceptorPipeline(), events: TFYSwiftRouteEventCenter(), driver: driver)

        let session = router.openSession(
            TestRoute.detail(id: "cancel"),
            input: ProductInput(id: "cancel", attributes: [:]),
            commands: ProductCommand.self,
            events: ProductEvent.self,
            expecting: ProductOutput.self
        )
        session.cancel()
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(router.transactionStates.values.contains(.cancelled))
    }
}

@MainActor
private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping @MainActor () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {}
}

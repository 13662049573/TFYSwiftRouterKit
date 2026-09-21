import XCTest
@testable import TFYSwiftRouterCore
@testable import TFYSwiftRouterDeepLink
@testable import TFYSwiftRouterRestoration
@testable import TFYSwiftRouterTesting

final class TFYSwiftRouterPackageTests: XCTestCase {
    private struct ChoiceRoute: TFYSwiftSessionRouteContract {
        typealias Input = String
        typealias Output = String
        typealias Command = String
        typealias Event = String
    }

    private struct BinaryRoute: TFYSwiftRoute { let bytes: [UInt8] }

    private enum UnregisteredRoute: String, Codable, TFYSwiftRoute {
        case detail
    }

    private struct DeepLinkParser: TFYSwiftDeepLinkParser {
        let identifier = "package-tests"

        func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
            TFYSwiftAnyRoute(Route.detail)
        }
    }

    /// 不依赖 UI 的边界回归：相同协议可注册多个命名实例，事务按复合键回滚。
    @MainActor
    func testServiceNamespacesRemainIndependent() throws {
        let services = TFYSwiftComponentServiceRegistry()
        let first = TFYSwiftComponentServiceKey<String>(namespace: "account.one")
        let second = TFYSwiftComponentServiceKey<String>(namespace: "account.two")
        try services.register("one", for: first)
        try services.register("two", for: second)
        XCTAssertThrowsError(try services.register("duplicate", for: first))
        XCTAssertEqual(try services.resolve(first), "one")
        XCTAssertEqual(try services.resolve(second), "two")
        XCTAssertThrowsError(try services.performRegistrationTransaction {
            try services.register("changed", for: first, replacingExisting: true)
            throw TFYSwiftRouteError.cancelled
        })
        XCTAssertEqual(try services.resolve(first), "one")
        services.unregister(first)
        XCTAssertFalse(services.contains(first))
        XCTAssertTrue(services.contains(second))
    }

    @MainActor
    func testDefaultScopeFlowsThroughProtocolAndTypedConveniences() async throws {
        let mock = TFYSwiftTestRouter(defaultScope: "workspace.custom")
        let routing: any TFYSwiftRouting = mock
        mock.provide(String.self) { "done" }
        try await routing.open(ChoiceRoute())
        try await routing.open(ChoiceRoute(), input: "input")
        _ = try await routing.open(ChoiceRoute(), expecting: String.self)
        _ = try await routing.openTyped(ChoiceRoute(), input: "input")
        let session = routing.openTypedSession(ChoiceRoute(), input: "input")
        _ = try await session.value
        try await routing.back()
        try await routing.backToRoot()
        try await routing.dismiss()
        try await routing.dismissAll()
        XCTAssertEqual(mock.invocations.count, 9)
        XCTAssertTrue(mock.invocations.allSatisfy { $0.scope == "workspace.custom" })
        try await routing.open(ChoiceRoute(), scope: .main)
        XCTAssertEqual(mock.invocations.last?.scope, .main)
    }

    @MainActor
    func testCustomCodecDoesNotRequireCodableOrJSON() throws {
        let registry = TFYSwiftRestorationRegistry()
        try registry.register(BinaryRoute.self, identifier: "caller.binary", encode: {
            Data($0.bytes)
        }, decode: {
            BinaryRoute(bytes: Array($0))
        })
        let route = BinaryRoute(bytes: [0, 255, 10])
        let descriptor = try XCTUnwrap(registry.descriptor(for: TFYSwiftAnyRoute(route)))
        XCTAssertEqual(descriptor.payload, Data([0, 255, 10]))
        XCTAssertEqual(try registry.route(from: descriptor).cast(to: BinaryRoute.self), route)
    }

    @MainActor
    func testInjectedJSONCodingStrategies() throws {
        struct Address: TFYSwiftRoute, Codable { let createdAt: Date }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let registry = TFYSwiftRestorationRegistry(encoder: encoder, decoder: decoder)
        try registry.register(Address.self, identifier: "caller.date")
        let route = Address(createdAt: Date(timeIntervalSince1970: 123))
        let descriptor = try XCTUnwrap(registry.descriptor(for: TFYSwiftAnyRoute(route)))
        XCTAssertTrue(String(decoding: descriptor.payload, as: UTF8.self).contains("123"))
        XCTAssertEqual(try registry.route(from: descriptor).cast(to: Address.self), route)
    }

    func testDeepLinkPolicyNormalizesValuesAssignedAfterInitialization() async throws {
        var policy = TFYSwiftDeepLinkPolicy(allowedSchemes: [])
        policy.allowedSchemes.insert("HTTPS")
        policy.allowedHosts.insert("ROUTER.EXAMPLE.COM")
        let engine = TFYSwiftDeepLinkEngine(policy: policy)
        await engine.add(DeepLinkParser())

        let route = try await engine.route(for: TFYSwiftDeepLinkRequest(
            url: try XCTUnwrap(URL(string: "https://router.example.com/detail"))
        ))

        XCTAssertEqual(route, TFYSwiftAnyRoute(Route.detail))
    }

    func testDeepLinkPolicyKeepsMaximumURLLengthPositiveAfterMutation() {
        var policy = TFYSwiftDeepLinkPolicy(allowedSchemes: ["https"])
        policy.maximumURLLength = 0
        XCTAssertEqual(policy.maximumURLLength, 1)
    }

    @MainActor
    func testInteractionChannelsApplyConfiguredOverflowPolicy() async throws {
        let newest = TFYSwiftRouteCommandChannel(
            Int.self,
            bufferingPolicy: .bufferingNewest(2)
        )
        try newest.send(1)
        try newest.send(2)
        try newest.send(3)
        newest.finish()
        var newestValues: [Int] = []
        for await value in try newest.stream(of: Int.self) { newestValues.append(value) }
        XCTAssertEqual(newestValues, [2, 3])

        let oldest = TFYSwiftRouteEventChannel(
            Int.self,
            bufferingPolicy: .bufferingOldest(2)
        )
        try oldest.send(1)
        try oldest.send(2)
        try oldest.send(3)
        oldest.finish()
        var oldestValues: [Int] = []
        for await value in try oldest.stream(of: Int.self) { oldestValues.append(value) }
        XCTAssertEqual(oldestValues, [1, 2])
    }

    @MainActor
    func testTypedDestinationContextValidatesInputAndFinishesOutput() throws {
        var receivedOutput: String?
        let result = TFYSwiftRouteResult(
            transactionID: UUID(),
            finish: { receivedOutput = $0 as? String },
            cancel: { _ in }
        )
        let context = TFYSwiftDestinationContext(
            routeContext: TFYSwiftRouteContext(),
            presentation: .sheet(),
            interaction: TFYSwiftRouteInteraction(
                input: TFYSwiftRoutePayload("input"),
                result: result
            )
        )

        let typed = try TFYSwiftTypedDestinationContext<ChoiceRoute>(context)
        XCTAssertEqual(typed.input, "input")
        try typed.finish("output")
        XCTAssertEqual(receivedOutput, "output")
    }

    /// 防止 App 资源、固定业务地址或 Demo 类型重新渗入可发布源码。
    func testRuntimeSourcesDoNotDependOnAppResources() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("TFYSwiftRouterKit/TFYSwiftRouter")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var count = 0
        for case let file as URL in files where file.pathExtension == "swift" {
            count += 1
            let source = try String(contentsOf: file, encoding: .utf8)
            let code = source.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for forbidden in ["TFYSwiftDemo", "Bundle.main", "UserDefaults", "Image(systemName:", "UIImage(named:", "tfyswift://", "router.tfy.com", "SKU-"] {
                XCTAssertFalse(code.contains(forbidden), "\(file.lastPathComponent) 依赖了 App 内容：\(forbidden)")
            }
        }
        XCTAssertGreaterThan(count, 0)
        XCTAssertEqual(TFYSwiftRouteError.timeout.code, "timeout")
    }

    /// 组合根只能装配模块与容器，具体页面必须留在 Destination 工厂中。
    func testDemoCoordinatorDoesNotConstructConcretePages() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let demo = root.appendingPathComponent("TFYSwiftRouterKit/ClassDemo")
        let coordinator = root.appendingPathComponent(
            "TFYSwiftRouterKit/ClassDemo/App/TFYDemoAppCoordinator.swift"
        )
        let source = try String(contentsOf: coordinator, encoding: .utf8)

        XCTAssertTrue(source.contains("registerComponents"))
        for module in ["Start", "Playground", "Stack", "Timeline"] {
            for suffix in ["ViewController", "Model", "Routes", "Router"] {
                let file = demo.appendingPathComponent("\(module)/TFYDemo\(module)\(suffix).swift")
                XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "缺少模块文件：\(file.path)")
            }
        }
        for forbidden in [
            "makeRootViewController",
            "registerDestinations",
            "TFYDemoStartViewController",
            "TFYDemoPlaygroundViewController",
            "TFYDemoStackViewController",
            "TFYDemoTimelineViewController"
        ] {
            XCTAssertFalse(source.contains(forbidden), "Coordinator 泄漏了具体页面：\(forbidden)")
        }
    }
    private enum Route: String, Codable, TFYSwiftRoute {
        case root
        case detail
    }

    @MainActor
    private final class Checkpoint: TFYSwiftNavigationCheckpoint {
        private var commitOperation: (() -> Void)?
        private var rollbackOperation: (() -> Void)?

        init(commit: @escaping () -> Void, rollback: @escaping () -> Void) {
            commitOperation = commit
            rollbackOperation = rollback
        }

        func commit() {
            commitOperation?()
            commitOperation = nil
            rollbackOperation = nil
        }

        func rollback() {
            rollbackOperation?()
            commitOperation = nil
            rollbackOperation = nil
        }
    }

    @MainActor
    private final class Driver: TFYSwiftNavigationDriver, TFYSwiftNavigationCheckpointing {
        var stack: [TFYSwiftAnyRoute] = []
        var failOnPresentationNumber: Int?
        var cancelOnPresentationNumber: Int?
        var stateIdentity = UUID()
        private var presentationCount = 0

        func present(
            destination: TFYSwiftDestinationDescriptor,
            route: TFYSwiftAnyRoute,
            transaction: TFYSwiftRouteTransaction,
            interaction: TFYSwiftRouteInteraction?
        ) async throws {
            presentationCount += 1
            if presentationCount == failOnPresentationNumber {
                throw TFYSwiftRouteError.presentationFailed("injected failure")
            }
            if presentationCount == cancelOnPresentationNumber {
                throw CancellationError()
            }
            if case .root = transaction.presentation { stack = [route] }
            else { stack.append(route) }
            stateIdentity = UUID()
        }

        func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool { stack.last == route }
        func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool { false }
        func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] { stack }
        func makeNavigationCheckpoint(
            in scope: TFYSwiftNavigationScopeID
        ) throws -> any TFYSwiftNavigationCheckpoint {
            let originalStack = stack
            let originalIdentity = stateIdentity
            return Checkpoint(commit: {}) { [weak self] in
                self?.stack = originalStack
                self?.stateIdentity = originalIdentity
            }
        }
        func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws { stack.removeLast(min(count, stack.count)) }
        func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws { if let first = stack.first { stack = [first] } }
        func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {}
        func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {}
    }

    @MainActor
    func testPackageProductsSupportRoutingAndRestoration() async throws {
        let driver = Driver()
        let registry = TFYSwiftRouteRegistry()
        try registry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
        let router = TFYSwiftRouter(
            registry: registry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try restorationRegistry.register(Route.self, identifier: "route.v1")
        let coordinator = TFYSwiftRestorationCoordinator(registry: restorationRegistry, router: router)

        try await router.open(Route.root, presentation: .root())
        try await router.open(Route.detail, presentation: .push())
        let snapshot = try coordinator.makeSnapshot(scopes: [.main])

        XCTAssertEqual(snapshot.scopes.first?.routes.count, 2)
        XCTAssertEqual(router.navigationRoutes(), [TFYSwiftAnyRoute(Route.root), TFYSwiftAnyRoute(Route.detail)])
    }

    @MainActor
    func testRestorationRejectsUnknownScopeBeforeOpeningAnyRoute() async throws {
        let mainDriver = Driver()
        let scopedDriver = TFYSwiftScopedNavigationDriver()
        try scopedDriver.register(mainDriver, for: .main, replacingExisting: false)
        let routeRegistry = TFYSwiftRouteRegistry()
        try routeRegistry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
        let router = TFYSwiftRouter(
            registry: routeRegistry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: scopedDriver
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try restorationRegistry.register(Route.self, identifier: "route.v1")
        let descriptor = try XCTUnwrap(restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.root)))
        let snapshot = TFYSwiftNavigationSnapshot(scopes: [
            TFYSwiftNavigationScopeSnapshot(scope: .main, routes: [descriptor]),
            TFYSwiftNavigationScopeSnapshot(scope: "missing", routes: [descriptor])
        ])
        let coordinator = TFYSwiftRestorationCoordinator(registry: restorationRegistry, router: router)

        do {
            try await coordinator.restore(snapshot)
            XCTFail("Expected unknown scope to fail restoration")
        } catch {}
        XCTAssertTrue(mainDriver.stack.isEmpty)
    }

    @MainActor
    func testRestorationRejectsUnregisteredRouteBeforeOpeningAnyRoute() async throws {
        let driver = Driver()
        let routeRegistry = TFYSwiftRouteRegistry()
        try routeRegistry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
        let router = TFYSwiftRouter(
            registry: routeRegistry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try restorationRegistry.register(Route.self, identifier: "route.v1")
        try restorationRegistry.register(UnregisteredRoute.self, identifier: "unregistered.v1")
        let root = try XCTUnwrap(restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.root)))
        let unregistered = try XCTUnwrap(
            restorationRegistry.descriptor(for: TFYSwiftAnyRoute(UnregisteredRoute.detail))
        )
        let snapshot = TFYSwiftNavigationSnapshot(scopes: [
            TFYSwiftNavigationScopeSnapshot(scope: .main, routes: [root, unregistered])
        ])
        let coordinator = TFYSwiftRestorationCoordinator(registry: restorationRegistry, router: router)

        do {
            try await coordinator.restore(snapshot)
            XCTFail("Expected unregistered route to fail restoration")
        } catch {}
        XCTAssertTrue(driver.stack.isEmpty)
    }

    @MainActor
    func testRestorationRollsBackOriginalStackWhenLaterPresentationFails() async throws {
        let driver = Driver()
        driver.stack = [TFYSwiftAnyRoute(Route.detail)]
        let originalIdentity = driver.stateIdentity
        driver.failOnPresentationNumber = 2
        let routeRegistry = TFYSwiftRouteRegistry()
        try routeRegistry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
        let router = TFYSwiftRouter(
            registry: routeRegistry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try restorationRegistry.register(Route.self, identifier: "route.v1")
        let root = try XCTUnwrap(restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.root)))
        let detail = try XCTUnwrap(restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.detail)))
        let snapshot = TFYSwiftNavigationSnapshot(scopes: [
            TFYSwiftNavigationScopeSnapshot(scope: .main, routes: [root, detail])
        ])
        let coordinator = TFYSwiftRestorationCoordinator(registry: restorationRegistry, router: router)

        do {
            try await coordinator.restore(snapshot)
            XCTFail("Expected restoration failure")
        } catch {}

        XCTAssertEqual(driver.stack, [TFYSwiftAnyRoute(Route.detail)])
        XCTAssertEqual(driver.stateIdentity, originalIdentity)
    }

    @MainActor
    func testRestorationRollsBackEmptyStackWhenTaskIsCancelled() async throws {
        let driver = Driver()
        driver.cancelOnPresentationNumber = 2
        let routeRegistry = TFYSwiftRouteRegistry()
        try routeRegistry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
        let router = TFYSwiftRouter(
            registry: routeRegistry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try restorationRegistry.register(Route.self, identifier: "route.v1")
        let root = try XCTUnwrap(restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.root)))
        let detail = try XCTUnwrap(restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.detail)))
        let snapshot = TFYSwiftNavigationSnapshot(scopes: [
            TFYSwiftNavigationScopeSnapshot(scope: .main, routes: [root, detail])
        ])
        let coordinator = TFYSwiftRestorationCoordinator(registry: restorationRegistry, router: router)

        do {
            try await coordinator.restore(snapshot)
            XCTFail("Expected restoration cancellation")
        } catch {}

        XCTAssertTrue(driver.stack.isEmpty)
    }

    @MainActor
    func testRestorationRollsBackEveryScopeWhenLaterScopeFails() async throws {
        let firstScope: TFYSwiftNavigationScopeID = "restore.first"
        let secondScope: TFYSwiftNavigationScopeID = "restore.second"
        let firstDriver = Driver()
        let secondDriver = Driver()
        firstDriver.stack = [TFYSwiftAnyRoute(Route.detail)]
        secondDriver.stack = [TFYSwiftAnyRoute(Route.detail)]
        let firstIdentity = firstDriver.stateIdentity
        let secondIdentity = secondDriver.stateIdentity
        secondDriver.failOnPresentationNumber = 1

        let scopedDriver = TFYSwiftScopedNavigationDriver()
        try scopedDriver.register(firstDriver, for: firstScope, replacingExisting: false)
        try scopedDriver.register(secondDriver, for: secondScope, replacingExisting: false)
        let routeRegistry = TFYSwiftRouteRegistry()
        try routeRegistry.register(Route.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "route")
        }
        let router = TFYSwiftRouter(
            registry: routeRegistry,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: scopedDriver
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try restorationRegistry.register(Route.self, identifier: "route.v1")
        let root = try XCTUnwrap(
            restorationRegistry.descriptor(for: TFYSwiftAnyRoute(Route.root))
        )
        let snapshot = TFYSwiftNavigationSnapshot(scopes: [
            .init(scope: firstScope, routes: [root]),
            .init(scope: secondScope, routes: [root])
        ])

        do {
            try await TFYSwiftRestorationCoordinator(
                registry: restorationRegistry,
                router: router
            ).restore(snapshot)
            XCTFail("Expected second scope to fail restoration")
        } catch {}

        XCTAssertEqual(firstDriver.stack, [TFYSwiftAnyRoute(Route.detail)])
        XCTAssertEqual(secondDriver.stack, [TFYSwiftAnyRoute(Route.detail)])
        XCTAssertEqual(firstDriver.stateIdentity, firstIdentity)
        XCTAssertEqual(secondDriver.stateIdentity, secondIdentity)
    }

    @MainActor
    func testRegistrationTransactionRollsBack() {
        let registry = TFYSwiftRouteRegistry()
        XCTAssertThrowsError(try registry.performRegistrationTransaction {
            try registry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
            throw TFYSwiftRouteError.invalidPayload("rollback")
        })
        XCTAssertFalse(registry.contains(Route.self))
    }
}

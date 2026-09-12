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
    private enum Route: String, Codable, TFYSwiftRoute {
        case root
        case detail
    }

    @MainActor
    private final class Driver: TFYSwiftNavigationDriver {
        var stack: [TFYSwiftAnyRoute] = []

        func present(
            destination: TFYSwiftDestinationDescriptor,
            route: TFYSwiftAnyRoute,
            transaction: TFYSwiftRouteTransaction,
            interaction: TFYSwiftRouteInteraction?
        ) async throws {
            if case .root = transaction.presentation { stack = [route] }
            else { stack.append(route) }
        }

        func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool { stack.last == route }
        func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool { false }
        func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] { stack }
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
    func testRegistrationTransactionRollsBack() {
        let registry = TFYSwiftRouteRegistry()
        XCTAssertThrowsError(try registry.performRegistrationTransaction {
            try registry.register(Route.self) { _, _ in TFYSwiftDestinationDescriptor(identifier: "route") }
            throw TFYSwiftRouteError.invalidPayload("rollback")
        })
        XCTAssertFalse(registry.contains(Route.self))
    }
}

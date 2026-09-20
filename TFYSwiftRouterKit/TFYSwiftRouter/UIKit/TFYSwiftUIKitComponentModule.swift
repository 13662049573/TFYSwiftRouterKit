// TFYSwiftUIKitComponentModule.swift
// UIKit 组件接入协议。批量注册前检查根 Scope，注册失败回滚 Route 与 Destination 两张表。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if canImport(UIKit)
import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// 一份完整的 UIKit 路由配置：声明 Route、目标页面工厂及可选根 Scope 关联。
@MainActor
public protocol TFYSwiftUIKitRouteConfiguring {
    var rootRegistration: TFYSwiftRootRouteRegistration? { get }
    func register(in assembly: TFYSwiftRouterAssembly) throws
}

/// 把单个 Route 与 UIKit 页面工厂绑定；页面类型可在自己的文件中公开该配置。
@MainActor
public struct TFYSwiftUIKitRouteConfiguration<Route: TFYSwiftRoute>: TFYSwiftUIKitRouteConfiguring {
    public let rootRegistration: TFYSwiftRootRouteRegistration?

    public let destinationID: String
    private let resolver: (@MainActor (Route, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)?
    private let factory: @MainActor (Route, TFYSwiftDestinationContext) throws -> UIViewController

    /// 配置普通页面 Route、稳定目标标识、可选解析逻辑和页面工厂。
    public init(
        destinationID: String = String(reflecting: Route.self),
        resolver: (@MainActor (Route, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)? = nil,
        factory: @escaping @MainActor (Route, TFYSwiftDestinationContext) throws -> UIViewController
    ) {
        rootRegistration = nil
        self.destinationID = destinationID
        self.resolver = resolver
        self.factory = factory
    }

    /// 配置根页面 Route，并把它与独立导航 Scope 关联。
    public init(
        rootScope: TFYSwiftNavigationScopeID,
        rootRoute: Route,
        destinationID: String = String(reflecting: Route.self),
        resolver: (@MainActor (Route, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)? = nil,
        factory: @escaping @MainActor (Route, TFYSwiftDestinationContext) throws -> UIViewController
    ) {
        rootRegistration = TFYSwiftRootRouteRegistration(scope: rootScope, route: rootRoute)
        self.destinationID = destinationID
        self.resolver = resolver
        self.factory = factory
    }

    public func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.register(
            Route.self,
            destinationID: destinationID,
            resolver: resolver,
            factory: factory
        )
    }
}

public extension TFYSwiftUIKitRouteConfiguration where Route: TFYSwiftRouteContract {
    /// 配置带 Input/Output 类型约束的页面工厂。
    init(
        destinationID: String = String(reflecting: Route.self),
        resolver: (@MainActor (Route, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)? = nil,
        typedFactory: @escaping @MainActor (Route, TFYSwiftTypedDestinationContext<Route>) throws -> UIViewController
    ) {
        self.init(destinationID: destinationID, resolver: resolver) { route, context in
            try typedFactory(route, TFYSwiftTypedDestinationContext(context))
        }
    }
}

/// Integration boundary exported by an independently compiled UIKit component implementation.
/// The component keeps all concrete view-controller construction inside `register(in:)`.
@MainActor
/// 组件实现模块对 App 暴露的唯一接入协议。
public protocol TFYSwiftUIKitComponentModule {
    var rootRegistration: TFYSwiftRootRouteRegistration { get }
    /// 按目标标识登记类型安全的页面工厂；重复标识默认抛错。
    func register(in assembly: TFYSwiftRouterAssembly) throws
}

public extension TFYSwiftRouterAssembly {
    /// 原子安装页面声明的路由配置，并返回需要由宿主启动的根 Route。
    @discardableResult
    func registerConfigurations(
        _ configurations: [any TFYSwiftUIKitRouteConfiguring]
    ) throws -> [TFYSwiftRootRouteRegistration] {
        let registrations = configurations.compactMap(\.rootRegistration)
        if let duplicateScope = Dictionary(grouping: registrations, by: \.scope)
            .first(where: { $0.value.count > 1 })?
            .key {
            throw TFYSwiftRouteError.duplicateRegistration("root scope: \(duplicateScope.rawValue)")
        }
        if let missingScope = registrations.first(where: { !scopedDriver.contains($0.scope) })?.scope {
            throw TFYSwiftRouteError.scopeUnavailable(missingScope.rawValue)
        }
        try routes.performRegistrationTransaction {
            try destinations.performRegistrationTransaction {
                for configuration in configurations {
                    try configuration.register(in: self)
                }
            }
        }
        return registrations
    }

    /// Registers independent feature implementations and returns their opaque root addresses.
    /// Duplicate scopes are rejected before any root screen is installed.
    @discardableResult
    /// 校验本批根 Scope 并批量登记组件；失败回滚 Route 与 Destination 注册，不涵盖任意外部副作用。
    func registerComponents(
        _ modules: [any TFYSwiftUIKitComponentModule]
    ) throws -> [TFYSwiftRootRouteRegistration] {
        let registrations = modules.map(\.rootRegistration)
        let duplicates = Dictionary(grouping: registrations, by: \.scope)
            .first { $0.value.count > 1 }?
            .key
        if let duplicates {
            throw TFYSwiftRouteError.duplicateRegistration("root scope: \(duplicates.rawValue)")
        }
        if let missingScope = registrations.first(where: { !scopedDriver.contains($0.scope) })?.scope {
            throw TFYSwiftRouteError.scopeUnavailable(missingScope.rawValue)
        }
        try routes.performRegistrationTransaction {
            try destinations.performRegistrationTransaction {
                for module in modules { try module.register(in: self) }
            }
        }
        return registrations
    }
}
#endif

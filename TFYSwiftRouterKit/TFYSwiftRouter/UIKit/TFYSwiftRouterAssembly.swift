// TFYSwiftRouterAssembly.swift
// UIKit 组合根。集中持有注册表、Scope 驱动、拦截器与 Router，避免业务页面自行组装基础设施。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if canImport(UIKit)
import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// Composition root that wires the UI-free router core to the UIKit/SwiftUI adapter.
@MainActor
/// 将 UIKit 注册表和驱动接到核心 Router 的应用组合根。
public final class TFYSwiftRouterAssembly {
    /// 按导航顺序保存的可恢复地址描述符。
    public let routes: TFYSwiftRouteRegistry
    /// 平台页面工厂注册表。
    public let destinations: TFYSwiftUIKitDestinationRegistry
    /// 接收导航变更的平台驱动或 Scope 分发驱动。
    public let driver: TFYSwiftUIKitNavigationDriver
    /// 按 Scope 路由到独立导航容器的分发驱动。
    public let scopedDriver: TFYSwiftScopedNavigationDriver
    /// 每个 Scope 对应的 UIKit 驱动，供宿主配置 custom/newWindow 等平台呈现。
    public private(set) var navigationDrivers: [TFYSwiftNavigationScopeID: TFYSwiftUIKitNavigationDriver]
    /// Tab 应用使用的 Scope 到选中项桥接；单导航栈组装时为 nil。
    public let tabBarDriver: TFYSwiftTabBarNavigationDriver?
    /// 共享的业务拦截流水线。
    public let interceptors: TFYSwiftInterceptorPipeline
    /// 事件中心、历史记录或会话事件流；具体语义由所属类型决定。
    public let events: TFYSwiftRouteEventCenter
    /// 完成组装的核心路由器，供业务层通过协议使用。
    public let router: TFYSwiftRouter

    /// 为初始导航容器组装完整 UIKit 路由环境，可显式指定初始 Scope。
    public init(
        navigationController: UINavigationController,
        initialScope: TFYSwiftNavigationScopeID = .main,
        sessionBuffering: TFYSwiftRouteSessionBuffering = .standard
    ) {
        routes = TFYSwiftRouteRegistry()
        destinations = TFYSwiftUIKitDestinationRegistry()
        driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: destinations
        )
        scopedDriver = TFYSwiftScopedNavigationDriver()
        try? scopedDriver.register(driver, for: initialScope, replacingExisting: false)
        navigationDrivers = [initialScope: driver]
        tabBarDriver = nil
        interceptors = TFYSwiftInterceptorPipeline()
        events = TFYSwiftRouteEventCenter()
        router = TFYSwiftRouter(
            registry: routes,
            interceptors: interceptors,
            events: events,
            driver: scopedDriver,
            defaultScope: initialScope,
            sessionBuffering: sessionBuffering
        )
    }

    /// 组装多 Tab 路由环境；目标 Scope 的导航会先选中对应 Tab。
    public init(
        tabBarController: UITabBarController,
        tabs: [TFYSwiftTabBarScope],
        initialScope: TFYSwiftNavigationScopeID,
        sessionBuffering: TFYSwiftRouteSessionBuffering = .standard
    ) throws {
        guard !tabs.isEmpty else {
            throw TFYSwiftRouteError.presentationFailed("At least one tab is required")
        }

        let routes = TFYSwiftRouteRegistry()
        let destinations = TFYSwiftUIKitDestinationRegistry()
        let scopedDriver = TFYSwiftScopedNavigationDriver()
        tabBarController.setViewControllers(tabs.map(\.navigationController), animated: false)

        var drivers: [TFYSwiftNavigationScopeID: TFYSwiftUIKitNavigationDriver] = [:]
        for tab in tabs {
            let navigationDriver = TFYSwiftUIKitNavigationDriver(
                navigationController: tab.navigationController,
                destinations: destinations
            )
            try scopedDriver.register(
                navigationDriver,
                for: tab.scope,
                replacingExisting: false
            )
            drivers[tab.scope] = navigationDriver
        }
        guard let initialDriver = drivers[initialScope] else {
            throw TFYSwiftRouteError.scopeUnavailable(initialScope.rawValue)
        }

        let tabBarDriver = TFYSwiftTabBarNavigationDriver(
            tabBarController: tabBarController,
            scopedDriver: scopedDriver
        )
        for (index, tab) in tabs.enumerated() {
            try tabBarDriver.register(tab.scope, at: index)
        }
        try tabBarDriver.select(initialScope)

        let interceptors = TFYSwiftInterceptorPipeline()
        let events = TFYSwiftRouteEventCenter()
        self.routes = routes
        self.destinations = destinations
        driver = initialDriver
        self.scopedDriver = scopedDriver
        navigationDrivers = drivers
        self.tabBarDriver = tabBarDriver
        self.interceptors = interceptors
        self.events = events
        router = TFYSwiftRouter(
            registry: routes,
            interceptors: interceptors,
            events: events,
            driver: tabBarDriver,
            defaultScope: initialScope,
            sessionBuffering: sessionBuffering
        )
    }

    /// Adds an independent tab or flow stack while sharing route and destination registrations.
    @discardableResult
    /// 登记独立容器或成对的 Route/页面工厂；页面登记失败时回滚本次地址登记。
    public func register(
        navigationController: UINavigationController,
        for scope: TFYSwiftNavigationScopeID,
        replacingExisting: Bool = false
    ) throws -> TFYSwiftUIKitNavigationDriver {
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: destinations
        )
        try scopedDriver.register(driver, for: scope, replacingExisting: replacingExisting)
        navigationDrivers[scope] = driver
        return driver
    }

    /// 登记独立容器或成对的 Route/页面工厂；页面登记失败时回滚本次地址登记。
    public func register<R: TFYSwiftRoute>(
        _ routeType: R.Type,
        destinationID: String = String(reflecting: R.self),
        resolver: (@MainActor (R, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)? = nil,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> UIViewController
    ) throws {
        try routes.performRegistrationTransaction {
            try destinations.performRegistrationTransaction {
                try routes.register(routeType) { route, context in
                    if let resolver { return try await resolver(route, context) }
                    return TFYSwiftDestinationDescriptor(identifier: destinationID)
                }
                try destinations.register(identifier: destinationID, routeType: routeType, factory: factory)
            }
        }
    }

    /// 成对登记契约 Route 与强类型 UIKit 页面工厂；任一步失败都会回滚。
    public func registerTyped<R: TFYSwiftRouteContract>(
        _ routeType: R.Type,
        destinationID: String = String(reflecting: R.self),
        resolver: (@MainActor (R, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)? = nil,
        factory: @escaping @MainActor (R, TFYSwiftTypedDestinationContext<R>) throws -> UIViewController
    ) throws {
        try routes.performRegistrationTransaction {
            try destinations.performRegistrationTransaction {
                try routes.register(routeType) { route, context in
                    if let resolver { return try await resolver(route, context) }
                    return TFYSwiftDestinationDescriptor(identifier: destinationID)
                }
                try destinations.registerTyped(
                    identifier: destinationID,
                    routeType: routeType,
                    factory: factory
                )
            }
        }
    }
}
#endif

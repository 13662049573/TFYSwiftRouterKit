// TFYSwiftScopedNavigationDriver.swift
// 按 Scope 分发导航操作。每个 Tab、流程或 Scene 可配置独立驱动，共享上层 Router。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// Dispatches navigation mutations to an independent driver for each tab/flow scope.
@MainActor
/// 多容器分发驱动；查询未知 Scope 返回空结果，导航修改未知 Scope 抛错。
public final class TFYSwiftScopedNavigationDriver: TFYSwiftNavigationDriver, TFYSwiftNavigationCheckpointing {
    private var drivers: [TFYSwiftNavigationScopeID: any TFYSwiftNavigationDriver] = [:]

    /// 创建空 Scope 分发器；必须先登记容器才能执行导航。
    public init() {}

    @available(*, deprecated, message: "Use register(_:for:replacingExisting:) and handle duplicate scopes explicitly.")
    /// 为 Scope 安装驱动；推荐使用带 replacingExisting 的可抛错重载。
    public func register(_ driver: any TFYSwiftNavigationDriver, for scope: TFYSwiftNavigationScopeID) {
        drivers[scope] = driver
    }

    /// 为 Scope 安装驱动；推荐使用带 replacingExisting 的可抛错重载。
    public func register(
        _ driver: any TFYSwiftNavigationDriver,
        for scope: TFYSwiftNavigationScopeID,
        replacingExisting: Bool
    ) throws {
        if drivers[scope] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateRegistration("navigation scope: \(scope.rawValue)")
        }
        drivers[scope] = driver
    }

    /// 移除指定注册映射；不会自动关闭已经展示的页面或撤销服务的业务副作用。
    public func unregister(scope: TFYSwiftNavigationScopeID) {
        drivers.removeValue(forKey: scope)
    }

    /// 检查指定类型或标识是否已经登记。
    public func contains(_ scope: TFYSwiftNavigationScopeID) -> Bool {
        drivers[scope] != nil
    }

    /// 已登记 Scope 的排序列表。
    public var registeredScopes: [TFYSwiftNavigationScopeID] {
        drivers.keys.sorted { $0.rawValue < $1.rawValue }
    }

    /// 由具体平台驱动创建并展示目标页面，工厂或呈现失败通过 throws 回传。
    public func present(destination: TFYSwiftDestinationDescriptor, route: TFYSwiftAnyRoute, transaction: TFYSwiftRouteTransaction, interaction: TFYSwiftRouteInteraction?) async throws {
        try await driver(for: transaction.context.scope).present(destination: destination, route: route, transaction: transaction, interaction: interaction)
    }

    /// 判断给定地址是否为当前 Scope 的可见顶层页面。
    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        drivers[scope]?.isTop(route, in: scope) ?? false
    }

    /// 尝试激活已有地址；命中时返回 true，并按驱动语义移除其上的页面。
    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        try await driver(for: scope).activate(route, in: scope)
    }

    /// 返回当前驱动追踪的地址，包含受支持的模态页面。
    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        drivers[scope]?.routes(in: scope) ?? []
    }

    /// 返回可用于恢复的 root/push 地址顺序；内置驱动排除模态和自定义呈现。
    public func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        drivers[scope]?.navigationRoutes(in: scope) ?? []
    }

    /// 由目标 Scope 的具体驱动创建实例级检查点。
    public func makeNavigationCheckpoint(
        in scope: TFYSwiftNavigationScopeID
    ) throws -> any TFYSwiftNavigationCheckpoint {
        let driver = try driver(for: scope)
        guard let checkpointing = driver as? any TFYSwiftNavigationCheckpointing else {
            throw TFYSwiftRouteError.restorationFailed(
                "Scope \(scope.rawValue) 的导航驱动不支持原子恢复"
            )
        }
        return try checkpointing.makeNavigationCheckpoint(in: scope)
    }

    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).back(count: count, in: scope)
    }

    /// 清理当前导航栈的根页之后的页面及其交互。
    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).backToRoot(in: scope)
    }

    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).dismiss(in: scope)
    }

    /// 关闭当前 Scope 的全部模态页面及其交互。
    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).dismissAll(in: scope)
    }

    private func driver(for scope: TFYSwiftNavigationScopeID) throws -> any TFYSwiftNavigationDriver {
        guard let driver = drivers[scope] else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        return driver
    }
}

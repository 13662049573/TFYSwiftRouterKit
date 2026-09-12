// TFYSwiftRootRouteRegistration.swift
// 组件根地址声明。组件公开 Scope 与类型擦除地址，App 无需认识根页面实现类型。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// A type-erased root route address for one independent navigation container.
/// Feature implementations publish this value; app shells never need the concrete root screen.
/// 单个组件的根地址及所属 Scope。
public struct TFYSwiftRootRouteRegistration: Sendable {
    /// 本次导航操作所属的容器作用域。
    public let scope: TFYSwiftNavigationScopeID
    /// 类型擦除后的地址；具体页面通过已登记的类型恢复。
    public let route: TFYSwiftAnyRoute

    /// 把具体根地址擦除为通用注册值，并关联独立容器 Scope。
    public init<R: TFYSwiftRoute>(scope: TFYSwiftNavigationScopeID, route: R) {
        self.scope = scope
        self.route = TFYSwiftAnyRoute(route)
    }
}

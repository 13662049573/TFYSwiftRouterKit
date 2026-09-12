// TFYSwiftUIKitComponentModule.swift
// UIKit 组件接入协议。批量注册前检查根 Scope，注册失败回滚 Route 与 Destination 两张表。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if canImport(UIKit)
import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

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

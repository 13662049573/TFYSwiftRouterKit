// TFYSwiftUIKitDestinationRegistry.swift
// UIKit 页面工厂注册表。支持 UIViewController 以及用 UIHostingController 包装的 SwiftUI View。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if canImport(UIKit)
import SwiftUI
import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
/// 按字符串目标标识管理 UIKit 页面工厂。
public final class TFYSwiftUIKitDestinationRegistry {
    public typealias Factory = @MainActor (TFYSwiftAnyRoute, TFYSwiftDestinationContext) throws -> UIViewController
    private var factories: [String: Factory] = [:]

    /// 创建空 UIKit 工厂表；标识与 Resolver 返回的 identifier 必须一致。
    public init() {}

    /// 按目标标识登记类型安全的页面工厂；重复标识默认抛错。
    public func register<R: TFYSwiftRoute>(
        identifier: String,
        routeType: R.Type,
        replacingExisting: Bool = false,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> UIViewController
    ) throws {
        if factories[identifier] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateRegistration(identifier)
        }
        factories[identifier] = { route, context in
            guard let typedRoute = route.cast(to: routeType) else {
                throw TFYSwiftRouteError.invalidPayload("页面工厂收到错误的 Route 类型")
            }
            return try factory(typedRoute, context)
        }
    }

    /// 将 SwiftUI View 工厂包装为 UIHostingController 后登记到 UIKit 目标表。
    public func registerSwiftUI<R: TFYSwiftRoute, Content: View>(
        identifier: String,
        routeType: R.Type,
        replacingExisting: Bool = false,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> Content
    ) throws {
        try register(
            identifier: identifier,
            routeType: routeType,
            replacingExisting: replacingExisting
        ) { route, context in
            UIHostingController(rootView: try factory(route, context))
        }
    }

    /// 调用匹配的页面工厂；目标未登记或输入解码失败会向上传播错误。
    public func makeViewController(
        identifier: String,
        route: TFYSwiftAnyRoute,
        context: TFYSwiftDestinationContext
    ) throws -> UIViewController {
        guard let factory = factories[identifier] else {
            throw TFYSwiftRouteError.destinationNotRegistered(identifier)
        }
        return try factory(route, context)
    }

    /// 已登记的页面工厂标识，排序后用于诊断。
    public var registeredDestinationIDs: [String] { factories.keys.sorted() }

    /// 移除指定注册映射；不会自动关闭已经展示的页面或撤销服务的业务副作用。
    public func unregister(identifier: String) {
        factories.removeValue(forKey: identifier)
    }

    /// 检查指定类型或标识是否已经登记。
    public func contains(_ identifier: String) -> Bool {
        factories[identifier] != nil
    }

    /// 保存注册表快照；同步闭包抛错时恢复映射。不会回滚外部对象内部的业务状态。
    public func performRegistrationTransaction<Result>(
        _ operation: @MainActor () throws -> Result
    ) rethrows -> Result {
        let checkpoint = factories
        do {
            return try operation()
        } catch {
            factories = checkpoint
            throw error
        }
    }
}
#endif

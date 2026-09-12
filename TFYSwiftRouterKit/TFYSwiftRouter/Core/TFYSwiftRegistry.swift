// TFYSwiftRegistry.swift
// 地址解析注册表。按 Route 类型注册异步 Resolver，再由目标描述符连接到平台页面工厂。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

@MainActor
/// 主线程隔离的 Route 类型到 Resolver 映射。
public final class TFYSwiftRouteRegistry {
    public typealias Resolver = @MainActor (TFYSwiftAnyRoute, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor

    private struct Entry {
        let routeName: String
        let resolver: Resolver
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    /// 创建空地址注册表，后续应在首次导航前完成登记。
    public init() {}

    /// 为 Route 类型登记异步 Resolver；重复类型默认抛错，显式替换后影响后续请求。
    public func register<R: TFYSwiftRoute>(
        _ routeType: R.Type,
        replacingExisting: Bool = false,
        resolver: @escaping @MainActor (R, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor
    ) throws {
        let key = ObjectIdentifier(routeType)
        if entries[key] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateRegistration(String(reflecting: routeType))
        }

        entries[key] = Entry(routeName: String(reflecting: routeType)) { route, context in
            guard let typedRoute = route.cast(to: R.self) else {
                throw TFYSwiftRouteError.invalidPayload("Route 类型擦除恢复失败")
            }
            return try await resolver(typedRoute, context)
        }
    }

    /// 移除指定注册映射；不会自动关闭已经展示的页面或撤销服务的业务副作用。
    public func unregister<R: TFYSwiftRoute>(_ routeType: R.Type) {
        entries.removeValue(forKey: ObjectIdentifier(routeType))
    }

    /// 查找已登记的实现；未登记或运行期类型不匹配时抛出对应错误。
    public func resolve(
        _ route: TFYSwiftAnyRoute,
        context: TFYSwiftRouteContext
    ) async throws -> TFYSwiftDestinationDescriptor {
        guard let entry = entries[route.typeID] else {
            throw TFYSwiftRouteError.routeNotRegistered(route.typeName)
        }
        return try await entry.resolver(route, context)
    }

    /// 检查指定类型或标识是否已经登记。
    public func contains<R: TFYSwiftRoute>(_ routeType: R.Type) -> Bool {
        entries[ObjectIdentifier(routeType)] != nil
    }

    /// 已登记的 Route 类型名称，排序后用于诊断。
    public var registeredRouteNames: [String] {
        entries.values.map(\.routeName).sorted()
    }

    /// Rolls back all registrations performed by `operation` when it throws.
    /// 保存注册表快照；同步闭包抛错时恢复映射。不会回滚外部对象内部的业务状态。
    public func performRegistrationTransaction<Result>(
        _ operation: @MainActor () throws -> Result
    ) rethrows -> Result {
        let checkpoint = entries
        do {
            return try operation()
        } catch {
            entries = checkpoint
            throw error
        }
    }
}

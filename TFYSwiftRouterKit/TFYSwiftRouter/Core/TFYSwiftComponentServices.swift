// TFYSwiftComponentServices.swift
// 跨组件服务容器。使用协议类型作为查找键，由应用组合根持有容器和具体服务实例。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// Marker adopted by protocols exposed from a component's Interface module.
/// 组件服务协议的标记；可变实现建议使用 actor 来满足 Sendable。
public protocol TFYSwiftComponentService: Sendable {}

/// A stable, typed lookup key. Use a protocol existential as `Service` so callers never see
/// the component's concrete implementation type.
/// 按服务协议类型和可选命名空间查找的键；名称由 App 提供，不包含固定业务分组。
public struct TFYSwiftComponentServiceKey<Service: Sendable>: Sendable {
    fileprivate let typeID: ObjectIdentifier
    /// 可选的实例命名空间；相同服务协议可以按账户、场景或用途分别注册。
    public let namespace: String?
    /// 原始类型名称，用于诊断和类型不匹配提示。
    public let typeName: String

    /// 由协议类型和命名空间生成键；省略命名空间时保留原有按类型查找行为。
    public init(_ type: Service.Type = Service.self, namespace: String? = nil) {
        typeID = ObjectIdentifier(type)
        typeName = String(reflecting: type)
        self.namespace = namespace
    }

    fileprivate var storageKey: TFYSwiftComponentServiceStorageKey {
        .init(typeID: typeID, namespace: namespace)
    }

    fileprivate var diagnosticName: String {
        namespace.map { "\(typeName) [\($0)]" } ?? typeName
    }
}

/// 注册表内部使用结构化键，不拼接业务字符串作为身份，避免分隔符碰撞。
fileprivate struct TFYSwiftComponentServiceStorageKey: Hashable {
    let typeID: ObjectIdentifier
    let namespace: String?
}

/// Instance-scoped service container for cross-component method calls.
/// It intentionally has no `shared` singleton; the app composition root owns it.
@MainActor
/// 实例级服务注册表，无全局 shared 单例。
public final class TFYSwiftComponentServiceRegistry {
    private var services: [TFYSwiftComponentServiceStorageKey: any Sendable] = [:]

    /// 创建独立的空服务容器，由 App 或流程拥有。
    public init() {}

    /// 按协议键登记服务；重复键默认抛错，显式 replacingExisting 可替换。
    public func register<Service: Sendable>(
        _ service: Service,
        for key: TFYSwiftComponentServiceKey<Service>,
        replacingExisting: Bool = false
    ) throws {
        if services[key.storageKey] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateService(key.diagnosticName)
        }
        services[key.storageKey] = service
    }

    /// 查找已登记的实现；未登记或运行期类型不匹配时抛出对应错误。
    public func resolve<Service: Sendable>(
        _ key: TFYSwiftComponentServiceKey<Service>
    ) throws -> Service {
        guard let service = services[key.storageKey] else {
            throw TFYSwiftRouteError.serviceNotRegistered(key.diagnosticName)
        }
        guard let typedService = service as? Service else {
            throw TFYSwiftRouteError.invalidPayload("组件服务类型擦除恢复失败：\(key.typeName)")
        }
        return typedService
    }

    /// 移除指定注册映射；不会自动关闭已经展示的页面或撤销服务的业务副作用。
    public func unregister<Service: Sendable>(_ key: TFYSwiftComponentServiceKey<Service>) {
        services.removeValue(forKey: key.storageKey)
    }

    /// 检查指定类型或标识是否已经登记。
    public func contains<Service: Sendable>(_ key: TFYSwiftComponentServiceKey<Service>) -> Bool {
        services[key.storageKey] != nil
    }

    /// 保存注册表快照；同步闭包抛错时恢复映射。不会回滚外部对象内部的业务状态。
    public func performRegistrationTransaction<Result>(
        _ operation: @MainActor () throws -> Result
    ) rethrows -> Result {
        let checkpoint = services
        do {
            return try operation()
        } catch {
            services = checkpoint
            throw error
        }
    }
}

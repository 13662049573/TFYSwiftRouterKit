import Foundation

/// Marker adopted by protocols exposed from a component's Interface module.
public protocol TFYSwiftComponentService: Sendable {}

/// A stable, typed lookup key. Use a protocol existential as `Service` so callers never see
/// the component's concrete implementation type.
public struct TFYSwiftComponentServiceKey<Service: Sendable>: Sendable {
    fileprivate let typeID: ObjectIdentifier
    public let typeName: String

    public init(_ type: Service.Type = Service.self) {
        typeID = ObjectIdentifier(type)
        typeName = String(reflecting: type)
    }
}

/// Instance-scoped service container for cross-component method calls.
/// It intentionally has no `shared` singleton; the app composition root owns it.
@MainActor
public final class TFYSwiftComponentServiceRegistry {
    private var services: [ObjectIdentifier: any Sendable] = [:]

    public init() {}

    public func register<Service: Sendable>(
        _ service: Service,
        for key: TFYSwiftComponentServiceKey<Service>,
        replacingExisting: Bool = false
    ) throws {
        if services[key.typeID] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateService(key.typeName)
        }
        services[key.typeID] = service
    }

    public func resolve<Service: Sendable>(
        _ key: TFYSwiftComponentServiceKey<Service>
    ) throws -> Service {
        guard let service = services[key.typeID] else {
            throw TFYSwiftRouteError.serviceNotRegistered(key.typeName)
        }
        guard let typedService = service as? Service else {
            throw TFYSwiftRouteError.invalidPayload("组件服务类型擦除恢复失败：\(key.typeName)")
        }
        return typedService
    }

    public func unregister<Service: Sendable>(_ key: TFYSwiftComponentServiceKey<Service>) {
        services.removeValue(forKey: key.typeID)
    }

    public func contains<Service: Sendable>(_ key: TFYSwiftComponentServiceKey<Service>) -> Bool {
        services[key.typeID] != nil
    }
}

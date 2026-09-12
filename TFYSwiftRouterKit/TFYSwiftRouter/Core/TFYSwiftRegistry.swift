import Foundation

@MainActor
public final class TFYSwiftRouteRegistry {
    public typealias Resolver = @MainActor (TFYSwiftAnyRoute, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor

    private struct Entry {
        let routeName: String
        let resolver: Resolver
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    public init() {}

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

    public func unregister<R: TFYSwiftRoute>(_ routeType: R.Type) {
        entries.removeValue(forKey: ObjectIdentifier(routeType))
    }

    public func resolve(
        _ route: TFYSwiftAnyRoute,
        context: TFYSwiftRouteContext
    ) async throws -> TFYSwiftDestinationDescriptor {
        guard let entry = entries[route.typeID] else {
            throw TFYSwiftRouteError.routeNotRegistered(route.typeName)
        }
        return try await entry.resolver(route, context)
    }

    public func contains<R: TFYSwiftRoute>(_ routeType: R.Type) -> Bool {
        entries[ObjectIdentifier(routeType)] != nil
    }

    public var registeredRouteNames: [String] {
        entries.values.map(\.routeName).sorted()
    }
}

import Foundation
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

public struct TFYSwiftRestorableRouteDescriptor: Codable, Hashable, Sendable {
    public let identifier: String
    public let payload: Data

    public init(identifier: String, payload: Data) {
        self.identifier = identifier
        self.payload = payload
    }
}

public struct TFYSwiftNavigationScopeSnapshot: Codable, Hashable, Sendable {
    public let scope: TFYSwiftNavigationScopeID
    public let routes: [TFYSwiftRestorableRouteDescriptor]

    public init(scope: TFYSwiftNavigationScopeID, routes: [TFYSwiftRestorableRouteDescriptor]) {
        self.scope = scope
        self.routes = routes
    }
}

public struct TFYSwiftNavigationSnapshot: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let createdAt: Date
    public let scopes: [TFYSwiftNavigationScopeSnapshot]

    public init(schemaVersion: Int = 1, createdAt: Date = Date(), scopes: [TFYSwiftNavigationScopeSnapshot]) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.scopes = scopes
    }
}

@MainActor
public final class TFYSwiftRestorationRegistry {
    private struct EncoderEntry {
        let identifier: String
        let encode: (TFYSwiftAnyRoute) throws -> Data
    }

    private var encoders: [ObjectIdentifier: EncoderEntry] = [:]
    private var decoders: [String: (Data) throws -> TFYSwiftAnyRoute] = [:]

    public init() {}

    /// Only explicitly registered Codable routes are eligible for persistence.
    public func register<R: TFYSwiftRoute & Codable>(
        _ routeType: R.Type,
        identifier: String
    ) throws {
        guard decoders[identifier] == nil else {
            throw TFYSwiftRouteError.duplicateRegistration(identifier)
        }
        encoders[ObjectIdentifier(routeType)] = EncoderEntry(identifier: identifier) { anyRoute in
            guard let route = anyRoute.cast(to: routeType) else {
                throw TFYSwiftRouteError.restorationFailed("Route 类型不匹配")
            }
            return try JSONEncoder().encode(route)
        }
        decoders[identifier] = { data in
            TFYSwiftAnyRoute(try JSONDecoder().decode(routeType, from: data))
        }
    }

    public func descriptor(for route: TFYSwiftAnyRoute) throws -> TFYSwiftRestorableRouteDescriptor? {
        guard let entry = encoders[route.typeID] else { return nil }
        return TFYSwiftRestorableRouteDescriptor(
            identifier: entry.identifier,
            payload: try entry.encode(route)
        )
    }

    public func route(from descriptor: TFYSwiftRestorableRouteDescriptor) throws -> TFYSwiftAnyRoute {
        guard let decode = decoders[descriptor.identifier] else {
            throw TFYSwiftRouteError.restorationFailed("未知的恢复标识：\(descriptor.identifier)")
        }
        return try decode(descriptor.payload)
    }
}

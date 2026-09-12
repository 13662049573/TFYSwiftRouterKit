import Foundation

/// A strongly typed navigation intent. Routes contain identifiers and small values, never views.
public protocol TFYSwiftRoute: Hashable, Sendable {}

/// Safe type erasure used only at the router runtime boundary.
public struct TFYSwiftAnyRoute: Hashable, @unchecked Sendable, CustomStringConvertible {
    public let typeID: ObjectIdentifier
    public let typeName: String
    private let storage: AnyHashable

    public init<R: TFYSwiftRoute>(_ route: R) {
        typeID = ObjectIdentifier(R.self)
        typeName = String(reflecting: R.self)
        storage = AnyHashable(route)
    }

    public func cast<R: TFYSwiftRoute>(to type: R.Type = R.self) -> R? {
        storage.base as? R
    }

    public var description: String { String(describing: storage.base) }
}

public struct TFYSwiftNavigationScopeID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }

    public static let main: Self = "main"
}

public enum TFYSwiftRouteSource: String, Codable, Sendable {
    case userInteraction
    case deepLink
    case universalLink
    case pushNotification
    case restoration
    case programmatic
}

public struct TFYSwiftRouteMetadata: Hashable, Codable, Sendable {
    public var values: [String: String]
    public var traceID: String?

    public init(values: [String: String] = [:], traceID: String? = nil) {
        self.values = values
        self.traceID = traceID
    }

    public static let empty = TFYSwiftRouteMetadata()
}

public struct TFYSwiftRouteContext: Hashable, Sendable {
    public let id: UUID
    public let source: TFYSwiftRouteSource
    public let scope: TFYSwiftNavigationScopeID
    public let metadata: TFYSwiftRouteMetadata
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
        metadata: TFYSwiftRouteMetadata = .empty,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.scope = scope
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

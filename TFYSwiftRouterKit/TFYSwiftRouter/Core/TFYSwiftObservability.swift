import Foundation

public enum TFYSwiftRouteEventName: String, Codable, Sendable {
    case created
    case interceptStarted
    case suspended
    case resumed
    case redirected
    case resolved
    case presentStarted
    case presented
    case completed
    case cancelled
    case failed
}

public struct TFYSwiftRouteEvent: Identifiable, Sendable {
    public let id: UUID
    public let transactionID: UUID
    public let name: TFYSwiftRouteEventName
    public let routeName: String
    public let scope: TFYSwiftNavigationScopeID
    public let timestamp: Date
    public let elapsedMilliseconds: Double
    public let message: String?

    public init(
        id: UUID = UUID(),
        transactionID: UUID,
        name: TFYSwiftRouteEventName,
        routeName: String,
        scope: TFYSwiftNavigationScopeID,
        timestamp: Date = Date(),
        elapsedMilliseconds: Double,
        message: String? = nil
    ) {
        self.id = id
        self.transactionID = transactionID
        self.name = name
        self.routeName = routeName
        self.scope = scope
        self.timestamp = timestamp
        self.elapsedMilliseconds = elapsedMilliseconds
        self.message = message
    }
}

@MainActor
public protocol TFYSwiftRouteObserver: AnyObject {
    func routerDidEmit(_ event: TFYSwiftRouteEvent)
}

@MainActor
public final class TFYSwiftRouteEventCenter {
    private final class WeakObserver {
        weak var value: (any TFYSwiftRouteObserver)?
        init(_ value: any TFYSwiftRouteObserver) { self.value = value }
    }

    private var observers: [WeakObserver] = []

    public init() {}

    public func add(_ observer: any TFYSwiftRouteObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
        observers.append(WeakObserver(observer))
    }

    public func remove(_ observer: any TFYSwiftRouteObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
    }

    public func emit(_ event: TFYSwiftRouteEvent) {
        observers.removeAll { $0.value == nil }
        observers.forEach { $0.value?.routerDidEmit(event) }
    }
}

@MainActor
public final class TFYSwiftRouteHistory: TFYSwiftRouteObserver {
    public private(set) var events: [TFYSwiftRouteEvent] = []
    public var capacity: Int
    public var onChange: (() -> Void)?

    public init(capacity: Int = 200) { self.capacity = max(1, capacity) }

    public func routerDidEmit(_ event: TFYSwiftRouteEvent) {
        events.append(event)
        if events.count > capacity { events.removeFirst(events.count - capacity) }
        onChange?()
    }

    public func removeAll() {
        events.removeAll()
        onChange?()
    }
}

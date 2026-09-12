import Foundation

public enum TFYSwiftRouteTransactionState: Sendable, Equatable {
    case created
    case intercepting
    case suspended(reason: String)
    case resolving
    case presenting
    case presented
    case completed
    case cancelled
    case failed(message: String)
}

public struct TFYSwiftRouteTransaction: Sendable, Hashable {
    public let id: UUID
    public var route: TFYSwiftAnyRoute
    public let context: TFYSwiftRouteContext
    public let presentation: TFYSwiftRoutePresentation
    public let deduplication: TFYSwiftRouteDeduplicationPolicy

    public init(
        id: UUID = UUID(),
        route: TFYSwiftAnyRoute,
        context: TFYSwiftRouteContext,
        presentation: TFYSwiftRoutePresentation,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) {
        self.id = id
        self.route = route
        self.context = context
        self.presentation = presentation
        self.deduplication = deduplication
    }
}

public struct TFYSwiftDestinationDescriptor: Hashable, Sendable {
    public let identifier: String
    public var userInfo: [String: String]

    public init(identifier: String, userInfo: [String: String] = [:]) {
        self.identifier = identifier
        self.userInfo = userInfo
    }
}

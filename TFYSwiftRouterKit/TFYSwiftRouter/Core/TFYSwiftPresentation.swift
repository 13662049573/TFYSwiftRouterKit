import Foundation

public struct TFYSwiftSheetConfiguration: Hashable, Sendable {
    public enum Detent: String, Hashable, Sendable {
        case medium
        case large
    }

    public var detents: [Detent]
    public var prefersGrabberVisible: Bool
    public var allowsInteractiveDismiss: Bool

    public init(
        detents: [Detent] = [.medium, .large],
        prefersGrabberVisible: Bool = true,
        allowsInteractiveDismiss: Bool = true
    ) {
        self.detents = detents
        self.prefersGrabberVisible = prefersGrabberVisible
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
    }

    public static let `default` = TFYSwiftSheetConfiguration()
}

public enum TFYSwiftRoutePresentation: Hashable, Sendable {
    case automatic
    case push(animated: Bool = true)
    case sheet(TFYSwiftSheetConfiguration = .default)
    case fullScreen(animated: Bool = true)
    case replace(animated: Bool = true)
    case root(animated: Bool = false)
    case newWindow
    case custom(String)
}

public enum TFYSwiftRouteDeduplicationPolicy: String, Hashable, Sendable {
    case none
    case ignoreIfTop
    case singleTop
    case singleTask
}

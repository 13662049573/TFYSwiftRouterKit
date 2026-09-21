import Foundation

enum TFYDemoPlaygroundRoute: Hashable, Codable, Sendable, TFYSwiftRoute {
    case root
    case detail(title: String, message: String)
    case legacy
}

struct TFYDemoPlaygroundSessionInput: Sendable, Equatable { let name: String }
enum TFYDemoPlaygroundSessionCommand: Sendable, Equatable { case updateStatus(String) }
enum TFYDemoPlaygroundSessionEvent: Sendable, Equatable { case ping }
struct TFYDemoPlaygroundSessionOutput: Sendable, Equatable { let summary: String }

struct TFYDemoPlaygroundSessionRoute: Hashable, Sendable, TFYSwiftSessionRouteContract {
    typealias Input = TFYDemoPlaygroundSessionInput
    typealias Command = TFYDemoPlaygroundSessionCommand
    typealias Event = TFYDemoPlaygroundSessionEvent
    typealias Output = TFYDemoPlaygroundSessionOutput
}

struct TFYDemoPlaygroundRegistrationProbeRoute: Hashable, Sendable, TFYSwiftRoute {}

@MainActor
protocol TFYDemoWindowCloseHandling: AnyObject {
    var onClose: (() -> Void)? { get set }
}

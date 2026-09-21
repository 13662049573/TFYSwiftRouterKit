import Foundation

enum TFYDemoStartRoute: String, Codable, TFYSwiftRoute {
    case root
}

struct TFYDemoStartPickerInput: Sendable, Equatable {
    let title: String
    let options: [String]
}

struct TFYDemoStartPickerRoute: Hashable, Sendable, TFYSwiftRouteContract {
    typealias Input = TFYDemoStartPickerInput
    typealias Output = String
}

struct TFYDemoStartSessionInput: Sendable, Equatable { let name: String }
enum TFYDemoStartSessionCommand: Sendable, Equatable { case updateStatus(String) }
enum TFYDemoStartSessionEvent: Sendable, Equatable { case tapped(String) }
struct TFYDemoStartSessionOutput: Sendable, Equatable { let summary: String }

struct TFYDemoStartSessionRoute: Hashable, Sendable, TFYSwiftSessionRouteContract {
    typealias Input = TFYDemoStartSessionInput
    typealias Command = TFYDemoStartSessionCommand
    typealias Event = TFYDemoStartSessionEvent
    typealias Output = TFYDemoStartSessionOutput
}

struct TFYDemoStartSwiftUIRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}

struct TFYDemoStartDeepLinkParser: TFYSwiftDeepLinkParser {
    let identifier = "demo.detail"

    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
        guard request.url.host == "open", request.url.path == "/detail" else { return nil }
        let title = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "title" })?.value ?? "Deep Link"
        return TFYSwiftAnyRoute(
            TFYDemoPlaygroundRoute.detail(
                title: title,
                message: "URL 已通过白名单与 Parser，并由 Scope 自动切换到演练 Tab。"
            )
        )
    }
}

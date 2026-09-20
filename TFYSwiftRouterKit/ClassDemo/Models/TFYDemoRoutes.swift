import Foundation

enum TFYDemoTab: String, CaseIterable, Codable, Sendable {
    case start
    case playground
    case stack
    case timeline

    var scope: TFYSwiftNavigationScopeID { .init("demo.\(rawValue)") }

    var title: String {
        switch self {
        case .start: "开始"
        case .playground: "演练"
        case .stack: "导航栈"
        case .timeline: "事件"
        }
    }

    var symbol: String {
        switch self {
        case .start: "play.circle.fill"
        case .playground: "slider.horizontal.3"
        case .stack: "square.stack.3d.up.fill"
        case .timeline: "waveform.path.ecg"
        }
    }
}

struct TFYDemoStartRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}
struct TFYDemoPlaygroundRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}
struct TFYDemoStackRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}
struct TFYDemoTimelineRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}
struct TFYDemoSwiftUIRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}
struct TFYDemoLegacyRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}

struct TFYDemoDetailRoute: Hashable, Codable, Sendable, TFYSwiftRoute {
    let title: String
    let message: String
}

struct TFYDemoPickerInput: Sendable, Equatable {
    let title: String
    let options: [String]
}

struct TFYDemoPickerRoute: Hashable, Sendable, TFYSwiftRouteContract {
    typealias Input = TFYDemoPickerInput
    typealias Output = String
}

struct TFYDemoSessionInput: Sendable, Equatable { let name: String }
enum TFYDemoSessionCommand: Sendable, Equatable { case updateStatus(String) }
enum TFYDemoSessionEvent: Sendable, Equatable { case tapped(String) }
struct TFYDemoSessionOutput: Sendable, Equatable { let summary: String }

struct TFYDemoSessionRoute: Hashable, Sendable, TFYSwiftSessionRouteContract {
    typealias Input = TFYDemoSessionInput
    typealias Command = TFYDemoSessionCommand
    typealias Event = TFYDemoSessionEvent
    typealias Output = TFYDemoSessionOutput
}

struct TFYDemoRegistrationProbeRoute: Hashable, Sendable, TFYSwiftRoute {}

struct TFYDemoDeepLinkParser: TFYSwiftDeepLinkParser {
    let identifier = "demo.detail"

    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
        guard request.url.host == "open", request.url.path == "/detail" else { return nil }
        let title = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "title" })?.value ?? "Deep Link"
        return TFYSwiftAnyRoute(
            TFYDemoDetailRoute(
                title: title,
                message: "这个页面由 URL 解析、白名单校验和目标 Scope 自动切换共同完成。"
            )
        )
    }
}

@MainActor
final class TFYDemoRedirectInterceptor: TFYSwiftRouteInterceptor {
    let identifier = "demo.legacy.redirect"

    func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
        guard transaction.route.cast(to: TFYDemoLegacyRoute.self) != nil else { return .proceed }
        return .redirect(
            TFYSwiftAnyRoute(
                TFYDemoDetailRoute(
                    title: "拦截器已重定向",
                    message: "legacy 地址没有进入页面工厂，而是在解析前被替换为新的强类型 Route。"
                )
            )
        )
    }
}

enum TFYDemoAction {
    case push, sheet, fullScreen, replace, root, custom, newWindow, crossTab
    case singleTop, singleTask, interceptor, deepLink, picker, session, timeout, cancel
    case swiftUI, registration, service, restoration, back, backToRoot, dismiss, dismissAll
    case showTimeline, clearTimeline
}

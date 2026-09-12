import Foundation

/// 实验室可恢复的地址；只编码页面标识，不保存运行中的交互对象。
enum TFYSwiftDemoLabRoute: String, TFYSwiftRoute, Codable {
    case root, pageA, pageB, inspector, swiftUI, hostedSwiftUI
}

/// 每种契约单独声明一个 Route，避免同一枚举的不同 case 使用不同输出类型。
struct TFYSwiftDemoPickerContract: TFYSwiftRouteContract {
    typealias Input = [String]
    typealias Output = String
}

/// 复用商品页面，但由 Route 自身约束四种通信类型。
struct TFYSwiftDemoSessionContract: TFYSwiftSessionRouteContract {
    typealias Input = TFYSwiftDemoProduct
    typealias Output = TFYSwiftDemoProductOutput
    typealias Command = TFYSwiftDemoProductCommand
    typealias Event = TFYSwiftDemoProductEvent
    let productID: String
}

/// 注册和错误探针使用独立地址，避免修改四个业务组件的注册表。
struct TFYSwiftDemoProbeRoute: TFYSwiftRoute { let id: Int }

/// 两个 Parser 故意处理同一个链接，以可视化优先级与移除后的回退行为。
struct TFYSwiftDemoPriorityParser: TFYSwiftDeepLinkParser {
    let identifier: String
    let target: TFYSwiftDemoLabRoute
    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
        guard request.url.host == "lab" else { return nil }
        return TFYSwiftAnyRoute(target)
    }
}

/// 只作用于隔离的探针 Router，演示拒绝、重定向和重复挂起的保护。
@MainActor
final class TFYSwiftDemoProbeInterceptor: TFYSwiftRouteInterceptor {
    enum Mode { case reject, redirect, suspendForever }
    let identifier = "lab.probe"
    let mode: Mode
    init(_ mode: Mode) { self.mode = mode }
    func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
        switch mode {
        case .reject: return .reject(.invalidPayload("演示：业务校验拒绝此地址"))
        case .redirect:
            if transaction.route.cast(to: TFYSwiftDemoLabRoute.self) == .pageA {
                return .redirect(TFYSwiftAnyRoute(TFYSwiftDemoLabRoute.pageB))
            }
            return .proceed
        case .suspendForever:
            return .suspend(TFYSwiftRouteSuspension(reason: "演示重复挂起") { true })
        }
    }
}

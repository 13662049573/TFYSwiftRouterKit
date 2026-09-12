import Foundation

public enum TFYSwiftRouteError: Error, Sendable, Equatable, LocalizedError {
    case routeNotRegistered(String)
    case duplicateRegistration(String)
    case destinationNotRegistered(String)
    case destinationUnavailable(String)
    case invalidDeepLink(String)
    case invalidPayload(String)
    case rejected(String)
    case suspensionCancelled(String)
    case redirectLoop
    case resultTypeMismatch(expected: String, actual: String)
    case inputMissing(String)
    case inputTypeMismatch(expected: String, actual: String)
    case commandChannelMissing(String)
    case commandTypeMismatch(expected: String, actual: String)
    case eventChannelMissing(String)
    case eventTypeMismatch(expected: String, actual: String)
    case interactionFinished
    case duplicateService(String)
    case serviceNotRegistered(String)
    case presentationFailed(String)
    case scopeUnavailable(String)
    case sceneUnavailable
    case restorationFailed(String)
    case cancelled
    case timeout

    public var errorDescription: String? {
        switch self {
        case .routeNotRegistered(let value): "Route 未注册：\(value)"
        case .duplicateRegistration(let value): "Route 重复注册：\(value)"
        case .destinationNotRegistered(let value): "页面工厂未注册：\(value)"
        case .destinationUnavailable(let value): "页面不可用：\(value)"
        case .invalidDeepLink(let value): "无效的 Deep Link：\(value)"
        case .invalidPayload(let value): "无效参数：\(value)"
        case .rejected(let value): "路由被拦截：\(value)"
        case .suspensionCancelled(let value): "挂起的路由已取消：\(value)"
        case .redirectLoop: "路由重定向次数过多"
        case .resultTypeMismatch(let expected, let actual): "返回值类型不匹配，期望 \(expected)，实际 \(actual)"
        case .inputMissing(let value): "页面缺少输入模型：\(value)"
        case .inputTypeMismatch(let expected, let actual): "输入模型类型不匹配，期望 \(expected)，实际 \(actual)"
        case .commandChannelMissing(let value): "页面未建立命令通道：\(value)"
        case .commandTypeMismatch(let expected, let actual): "命令类型不匹配，期望 \(expected)，实际 \(actual)"
        case .eventChannelMissing(let value): "页面未建立事件通道：\(value)"
        case .eventTypeMismatch(let expected, let actual): "事件类型不匹配，期望 \(expected)，实际 \(actual)"
        case .interactionFinished: "路由会话已经结束"
        case .duplicateService(let value): "组件服务重复注册：\(value)"
        case .serviceNotRegistered(let value): "组件服务未注册：\(value)"
        case .presentationFailed(let value): "页面展示失败：\(value)"
        case .scopeUnavailable(let value): "导航作用域不可用：\(value)"
        case .sceneUnavailable: "当前 Scene 不支持创建新窗口"
        case .restorationFailed(let value): "导航恢复失败：\(value)"
        case .cancelled: "路由已取消"
        case .timeout: "路由已超时"
        }
    }
}

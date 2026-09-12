// TFYSwiftError.swift
// 路由错误分类。调用方可按枚举 case 处理失败，并通过 LocalizedError 获取中文原因。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// 可比较、可跨并发边界传递的统一错误类型。
public enum TFYSwiftRouteError: Error, Sendable, Equatable, LocalizedError {
    /// 未登记该 Route 类型的 Resolver。
    case routeNotRegistered(String)
    /// Route 类型、目标标识、Scope 或恢复标识发生重复登记。
    case duplicateRegistration(String)
    /// Resolver 指定的页面工厂不存在。
    case destinationNotRegistered(String)
    /// 目标无法用于当前请求，例如复用页面不能绑定新的结果等待。
    case destinationUnavailable(String)
    /// URL 校验失败或没有可处理该地址的 Parser。
    case invalidDeepLink(String)
    /// 业务参数或类型擦除后的数据不满足约定。
    case invalidPayload(String)
    /// 业务拦截器拒绝本次路由。
    case rejected(String)
    /// 用户或业务条件拒绝恢复挂起的请求。
    case suspensionCancelled(String)
    /// 挂起恢复次数超过 Router 配置的上限。
    case suspensionLoop
    /// 重定向次数超过 Router 配置的上限。
    case redirectLoop
    /// 目标返回值类型与调用方期望不一致。
    case resultTypeMismatch(expected: String, actual: String)
    /// 页面要求输入，但本次请求没有传入。
    case inputMissing(String)
    /// 实际输入模型与页面要求的类型不一致。
    case inputTypeMismatch(expected: String, actual: String)
    /// 页面要求命令流，但调用方未创建双向会话。
    case commandChannelMissing(String)
    /// 发送或读取的命令类型与通道约定不一致。
    case commandTypeMismatch(expected: String, actual: String)
    /// 页面要求事件流，但调用方未创建双向会话。
    case eventChannelMissing(String)
    /// 发送或读取的事件类型与通道约定不一致。
    case eventTypeMismatch(expected: String, actual: String)
    /// 会话已结束，不能继续发送命令或事件。
    case interactionFinished
    /// 同一协议类型键已经登记服务。
    case duplicateService(String)
    /// 服务键尚未登记实现。
    case serviceNotRegistered(String)
    /// 平台导航或自定义呈现无法执行。
    case presentationFailed(String)
    /// Scope 未登记，或其导航容器已失效。
    case scopeUnavailable(String)
    /// 没有安装适用的新窗口处理器或当前环境不支持。
    case sceneUnavailable
    /// 快照编解码、迁移或路由恢复失败。
    case restorationFailed(String)
    /// 调用方主动放弃或目标生命周期结束。
    case cancelled
    /// 结果等待超过指定秒数。
    case timeout

    /// 面向调用方的中文错误说明。
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
        case .suspensionLoop: "路由挂起恢复次数过多"
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

public extension TFYSwiftRouteError {
    /// 稳定的机器可读错误码；App 可据此查找自己的多语言资源，不依赖中文诊断文本。
    var code: String {
        switch self {
        case .routeNotRegistered: "routeNotRegistered"
        case .duplicateRegistration: "duplicateRegistration"
        case .destinationNotRegistered: "destinationNotRegistered"
        case .destinationUnavailable: "destinationUnavailable"
        case .invalidDeepLink: "invalidDeepLink"
        case .invalidPayload: "invalidPayload"
        case .rejected: "rejected"
        case .suspensionCancelled: "suspensionCancelled"
        case .suspensionLoop: "suspensionLoop"
        case .redirectLoop: "redirectLoop"
        case .resultTypeMismatch: "resultTypeMismatch"
        case .inputMissing: "inputMissing"
        case .inputTypeMismatch: "inputTypeMismatch"
        case .commandChannelMissing: "commandChannelMissing"
        case .commandTypeMismatch: "commandTypeMismatch"
        case .eventChannelMissing: "eventChannelMissing"
        case .eventTypeMismatch: "eventTypeMismatch"
        case .interactionFinished: "interactionFinished"
        case .duplicateService: "duplicateService"
        case .serviceNotRegistered: "serviceNotRegistered"
        case .presentationFailed: "presentationFailed"
        case .scopeUnavailable: "scopeUnavailable"
        case .sceneUnavailable: "sceneUnavailable"
        case .restorationFailed: "restorationFailed"
        case .cancelled: "cancelled"
        case .timeout: "timeout"
        }
    }
}

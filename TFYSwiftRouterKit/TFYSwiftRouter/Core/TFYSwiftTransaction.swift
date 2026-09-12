// TFYSwiftTransaction.swift
// 路由事务、状态和目标描述符。一个事务 ID 串联拦截、解析、展示和最终结果。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// 事务当前阶段；completed、cancelled、failed 为最终状态。
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

/// 一次导航的运行描述；重定向只替换 route，保留事务身份和请求上下文。
public struct TFYSwiftRouteTransaction: Sendable, Hashable {
    /// 当前值的唯一身份；用于关联记录或区分重复地址的页面实例。
    public let id: UUID
    /// 类型擦除后的地址；具体页面通过已登记的类型恢复。
    public var route: TFYSwiftAnyRoute
    /// 本次事务创建时确定的请求上下文。
    public let context: TFYSwiftRouteContext
    /// 本次请求采用的呈现策略。
    public let presentation: TFYSwiftRoutePresentation
    /// 本次请求采用的地址去重策略。
    public let deduplication: TFYSwiftRouteDeduplicationPolicy

    /// 创建事务；重定向复用此身份，保留上下文和呈现策略。
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

/// 平台无关的目标标识；identifier 必须与 Destination 注册表中的键一致。
public struct TFYSwiftDestinationDescriptor: Hashable, Sendable {
    /// 稳定的注册标识；在对应注册表内必须唯一。
    public let identifier: String
    /// 目标描述符的轻量字符串附加信息，不用于传递完整模型。
    public var userInfo: [String: String]

    /// 创建目标工厂标识与轻量附加信息，不创建页面。
    public init(identifier: String, userInfo: [String: String] = [:]) {
        self.identifier = identifier
        self.userInfo = userInfo
    }
}

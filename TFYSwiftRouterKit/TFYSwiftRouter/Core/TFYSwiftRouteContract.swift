// TFYSwiftRouteContract.swift
// 可选的编译期通信契约。把输入、输出、命令和事件的关联类型声明在地址类型上。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// Optional compile-time contract for routes whose input and final output are stable.
/// Existing `TFYSwiftRoute` APIs remain available for heterogeneous enum routes.
/// 为具有固定 Input 和 Output 的地址提供编译期类型约束。
public protocol TFYSwiftRouteContract: TFYSwiftRoute {
    /// 调用方传入的临时初始模型。
    associatedtype Input: Sendable
    /// 目标页面返回的一次最终结果。
    associatedtype Output: Sendable
}

/// Compile-time contract for a bidirectional route session.
/// 在输入输出契约上增加上行命令与下行事件类型约束。
public protocol TFYSwiftSessionRouteContract: TFYSwiftRouteContract {
    /// 调用方可以发送给目标页面的命令。
    associatedtype Command: Sendable
    /// 目标页面可以连续返回给调用方的事件。
    associatedtype Event: Sendable
}

/// 页面工厂使用的强类型上下文，统一约束 Input 与最终 Output。
@MainActor
public struct TFYSwiftTypedDestinationContext<Route: TFYSwiftRouteContract> {
    /// 原始上下文；需要访问底层交互对象时可使用。
    public let context: TFYSwiftDestinationContext
    /// 已按 Route 契约校验的输入。
    public let input: Route.Input

    public var routeContext: TFYSwiftRouteContext { context.routeContext }
    public var presentation: TFYSwiftRoutePresentation { context.presentation }

    public init(_ context: TFYSwiftDestinationContext) throws {
        self.context = context
        input = try context.input(as: Route.Input.self)
    }

    /// 返回契约声明的最终输出；当前请求未等待结果时抛错。
    public func finish(_ output: Route.Output) throws {
        guard let result = context.result else {
            throw TFYSwiftRouteError.destinationUnavailable("当前路由请求没有结果接收方")
        }
        result.finish(with: output)
    }

    /// 取消结果等待并结束本次交互流。
    public func cancel(_ error: Error = TFYSwiftRouteError.cancelled) {
        context.interaction?.cancel(error)
    }
}

public extension TFYSwiftTypedDestinationContext where Route: TFYSwiftSessionRouteContract {
    /// 读取契约声明的命令流。
    func commands() throws -> AsyncStream<Route.Command> {
        try context.commands(of: Route.Command.self)
    }

    /// 发送契约声明的事件。
    func send(_ event: Route.Event) throws {
        try context.send(event)
    }
}

public extension TFYSwiftRouting {
    /// Opens a route without repeating or manually matching its declared input/output types.
    /// 从 Route 契约推导输入/输出类型，调用者无需重复填写 expecting。
    func openTyped<R: TFYSwiftRouteContract>(
        _ route: R,
        input: R.Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws -> R.Output {
        try await open(
            route,
            input: input,
            presentation: presentation,
            source: source,
            scope: scope ?? defaultScope,
            metadata: metadata,
            deduplication: deduplication,
            expecting: R.Output.self
        )
    }

    /// Opens a typed session without repeating Command/Event/Output metatypes at the call site.
    /// 从 Route 契约推导 Input、Command、Event、Output，创建双向会话。
    func openTypedSession<R: TFYSwiftSessionRouteContract>(
        _ route: R,
        input: R.Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) -> TFYSwiftRouteSession<R.Command, R.Event, R.Output> {
        openSession(
            route,
            input: input,
            presentation: presentation,
            source: source,
            scope: scope ?? defaultScope,
            metadata: metadata,
            deduplication: deduplication,
            commands: R.Command.self,
            events: R.Event.self,
            expecting: R.Output.self
        )
    }
}

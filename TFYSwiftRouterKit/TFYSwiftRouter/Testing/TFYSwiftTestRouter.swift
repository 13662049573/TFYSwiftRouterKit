// TFYSwiftTestRouter.swift
// 无界面的测试替身。记录导航意图和上下文，按地址或结果类型注入同步/异步结果。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
/// 记录协议调用的测试替身，不创建 UIKit/SwiftUI 页面。
public final class TFYSwiftTestRouter: TFYSwiftRouting {
    /// 测试中的缺省 Scope，可与生产流程配置一致。
    public let defaultScope: TFYSwiftNavigationScopeID
    /// 与生产 Router 一致的新会话缓冲策略。
    public let sessionBuffering: TFYSwiftRouteSessionBuffering
    /// 记录一次调用的导航动作、Scope、来源、Metadata 与输入类型名；不保存实际输入值。
    public struct Invocation: Equatable {
        /// 本次协议调用的导航动作。
        public let action: Action
        /// 请求来源，供拦截器和业务判断使用。
        public let source: TFYSwiftRouteSource?
        /// 本次导航操作所属的容器作用域。
        public let scope: TFYSwiftNavigationScopeID
        /// 本次请求携带的业务追踪信息。
        public let metadata: TFYSwiftRouteMetadata
        /// 本次请求采用的地址去重策略。
        public let deduplication: TFYSwiftRouteDeduplicationPolicy?
        /// 输入的运行期类型名；测试替身不在此保存实际模型。
        public let inputTypeName: String?
    }

    /// 可直接比较的导航动作，适合验证业务导航意图。
    public enum Action: Equatable {
        case open(route: TFYSwiftAnyRoute, presentation: TFYSwiftRoutePresentation)
        case back(Int)
        case backToRoot
        case dismiss
        case dismissAll
    }

    /// 按调用顺序记录的简化导航动作。
    public private(set) var actions: [Action] = []
    /// 按调用顺序记录的完整诊断上下文。
    public private(set) var invocations: [Invocation] = []
    private var resultProviders: [ObjectIdentifier: @MainActor () async throws -> Any] = [:]
    private var routeResultProviders: [ResultProviderKey: @MainActor () async throws -> Any] = [:]
    private var interactions: [TFYSwiftAnyRoute: TFYSwiftRouteInteraction] = [:]

    private struct ResultProviderKey: Hashable {
        let route: TFYSwiftAnyRoute
        let resultType: ObjectIdentifier
    }

    public init(
        defaultScope: TFYSwiftNavigationScopeID = .main,
        sessionBuffering: TFYSwiftRouteSessionBuffering = .standard
    ) {
        self.defaultScope = defaultScope
        self.sessionBuffering = sessionBuffering
    }

    /// 配置结果 Provider；指定地址的 Provider 优先于仅按结果类型登记的默认 Provider。
    public func provide<Result: Sendable>(_ type: Result.Type, result: @escaping () throws -> Result) {
        resultProviders[ObjectIdentifier(type)] = { try result() }
    }

    /// 配置结果 Provider；指定地址的 Provider 优先于仅按结果类型登记的默认 Provider。
    public func provide<Result: Sendable>(
        _ type: Result.Type,
        asyncResult: @escaping @MainActor () async throws -> Result
    ) {
        resultProviders[ObjectIdentifier(type)] = asyncResult
    }

    /// 配置结果 Provider；指定地址的 Provider 优先于仅按结果类型登记的默认 Provider。
    public func provide<R: TFYSwiftRoute, Result: Sendable>(
        for route: R,
        result: @escaping @MainActor () async throws -> Result
    ) {
        routeResultProviders[ResultProviderKey(
            route: TFYSwiftAnyRoute(route),
            resultType: ObjectIdentifier(Result.self)
        )] = result
    }

    /// 取得测试会话当前的通信对象，以模拟目标页面事件和命令消费。
    public func interaction<R: TFYSwiftRoute>(for route: R) -> TFYSwiftRouteInteraction? {
        interactions[TFYSwiftAnyRoute(route)]
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws {
        recordOpen(route, inputTypeName: nil, presentation: presentation, source: source, scope: scope, metadata: metadata, deduplication: deduplication)
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        expecting: Result.Type
    ) async throws -> Result {
        recordOpen(route, inputTypeName: nil, presentation: presentation, source: source, scope: scope, metadata: metadata, deduplication: deduplication)
        guard let provider = provider(for: TFYSwiftAnyRoute(route), resultType: Result.self) else {
            throw TFYSwiftRouteError.destinationUnavailable("测试未配置 \(Result.self) 返回值")
        }
        let value = try await provider()
        guard let typedValue = value as? Result else {
            throw TFYSwiftRouteError.resultTypeMismatch(
                expected: String(reflecting: Result.self),
                actual: String(reflecting: type(of: value))
            )
        }
        return typedValue
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws {
        recordOpen(route, inputTypeName: String(reflecting: Input.self), presentation: presentation, source: source, scope: scope, metadata: metadata, deduplication: deduplication)
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        expecting: Result.Type
    ) async throws -> Result {
        recordOpen(route, inputTypeName: String(reflecting: Input.self), presentation: presentation, source: source, scope: scope, metadata: metadata, deduplication: deduplication)
        guard let provider = provider(for: TFYSwiftAnyRoute(route), resultType: Result.self) else {
            throw TFYSwiftRouteError.destinationUnavailable("测试未配置 \(Result.self) 返回值")
        }
        let value = try await provider()
        guard let typedValue = value as? Result else {
            throw TFYSwiftRouteError.resultTypeMismatch(
                expected: String(reflecting: Result.self),
                actual: String(reflecting: type(of: value))
            )
        }
        return typedValue
    }

    /// 创建命令流、事件流和异步结果任务；返回句柄后即可发送命令。
    public func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        commands: Command.Type,
        events: Event.Type,
        expecting: Output.Type
    ) -> TFYSwiftRouteSession<Command, Event, Output> {
        recordOpen(route, inputTypeName: String(reflecting: Input.self), presentation: presentation, source: source, scope: scope, metadata: metadata, deduplication: deduplication)
        let commandChannel = TFYSwiftRouteCommandChannel(
            commands,
            bufferingPolicy: sessionBuffering.commands
        )
        let eventChannel = TFYSwiftRouteEventChannel(
            events,
            bufferingPolicy: sessionBuffering.events
        )
        let interaction = TFYSwiftRouteInteraction(
            input: TFYSwiftRoutePayload(input),
            commands: commandChannel,
            events: eventChannel
        )
        let anyRoute = TFYSwiftAnyRoute(route)
        interactions[anyRoute] = interaction
        let stream: AsyncStream<Event>
        do { stream = try eventChannel.stream(of: events) }
        catch { preconditionFailure("TFYSwiftTestRouter internal event channel error: \(error)") }
        let task = Task { @MainActor [weak self] in
            guard let self else { throw TFYSwiftRouteError.cancelled }
            defer {
                interaction.finishChannels()
                self.interactions.removeValue(forKey: anyRoute)
            }
            guard let provider = self.provider(for: anyRoute, resultType: Output.self) else {
                throw TFYSwiftRouteError.destinationUnavailable("测试未配置 \(Output.self) 返回值")
            }
            let value = try await provider()
            guard let output = value as? Output else {
                throw TFYSwiftRouteError.resultTypeMismatch(
                    expected: String(reflecting: Output.self),
                    actual: String(reflecting: type(of: value))
                )
            }
            return output
        }
        return TFYSwiftRouteSession(
            events: stream,
            commands: commandChannel,
            interaction: interaction,
            resultTask: task
        )
    }

    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    public func back(count: Int, scope: TFYSwiftNavigationScopeID) async throws {
        recordNavigation(.back(count), scope: scope)
    }
    /// 清理当前导航栈的根页之后的页面及其交互。
    public func backToRoot(scope: TFYSwiftNavigationScopeID) async throws {
        recordNavigation(.backToRoot, scope: scope)
    }
    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    public func dismiss(scope: TFYSwiftNavigationScopeID) async throws {
        recordNavigation(.dismiss, scope: scope)
    }
    /// 关闭当前 Scope 的全部模态页面及其交互。
    public func dismissAll(scope: TFYSwiftNavigationScopeID) async throws {
        recordNavigation(.dismissAll, scope: scope)
    }

    private func provider<Result: Sendable>(
        for route: TFYSwiftAnyRoute,
        resultType: Result.Type
    ) -> (@MainActor () async throws -> Any)? {
        routeResultProviders[ResultProviderKey(
            route: route,
            resultType: ObjectIdentifier(resultType)
        )] ?? resultProviders[ObjectIdentifier(resultType)]
    }

    private func recordOpen<R: TFYSwiftRoute>(
        _ route: R,
        inputTypeName: String?,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) {
        let action = Action.open(route: TFYSwiftAnyRoute(route), presentation: presentation)
        actions.append(action)
        invocations.append(Invocation(
            action: action,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication,
            inputTypeName: inputTypeName
        ))
    }

    private func recordNavigation(_ action: Action, scope: TFYSwiftNavigationScopeID) {
        actions.append(action)
        invocations.append(Invocation(
            action: action,
            source: nil,
            scope: scope,
            metadata: .empty,
            deduplication: nil,
            inputTypeName: nil
        ))
    }
}

// TFYSwiftRouter.swift
// 统一导航入口。组织拦截、去重、地址解析、平台展示、交互结果和事件记录；由 MainActor 串行访问状态。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

@MainActor
/// 业务侧依赖的路由协议；生产注入 Router，单元测试注入 TestRouter。
public protocol TFYSwiftRouting: AnyObject {
    /// 未显式传入 Scope 的便利调用使用此值；由 App 组合根配置。
    var defaultScope: TFYSwiftNavigationScopeID { get }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        expecting: Result.Type
    ) async throws -> Result

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        expecting: Result.Type
    ) async throws -> Result

    /// 创建命令流、事件流和异步结果任务；返回句柄后即可发送命令。
    func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
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
    ) -> TFYSwiftRouteSession<Command, Event, Output>

    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    func back(count: Int, scope: TFYSwiftNavigationScopeID) async throws
    /// 清理当前导航栈的根页之后的页面及其交互。
    func backToRoot(scope: TFYSwiftNavigationScopeID) async throws
    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    func dismiss(scope: TFYSwiftNavigationScopeID) async throws
    /// 关闭当前 Scope 的全部模态页面及其交互。
    func dismissAll(scope: TFYSwiftNavigationScopeID) async throws
}

public extension TFYSwiftRouting {
    /// 保持已有协议实现兼容；具体 Router/测试替身可配置任意默认 Scope。
    var defaultScope: TFYSwiftNavigationScopeID { .main }

    /// 打开普通地址；省略 scope 时使用当前实例的 defaultScope。
    func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws {
        try await open(route, presentation: presentation, source: source,
                       scope: scope ?? defaultScope, metadata: metadata, deduplication: deduplication)
    }

    /// 等待最终结果；默认容器来自实例，不要求 App 注册名为 main 的 Scope。
    func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        expecting: Result.Type
    ) async throws -> Result {
        try await open(route, presentation: presentation, source: source,
                       scope: scope ?? defaultScope, metadata: metadata, deduplication: deduplication, expecting: expecting)
    }

    /// 携带临时模型打开地址；完整参数继续转发给协议实现。
    func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws {
        try await open(route, input: input, presentation: presentation, source: source,
                       scope: scope ?? defaultScope, metadata: metadata, deduplication: deduplication)
    }

    /// 携带模型并等待输出；省略 Scope 时使用实例配置。
    func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        expecting: Result.Type
    ) async throws -> Result {
        try await open(route, input: input, presentation: presentation, source: source,
                       scope: scope ?? defaultScope, metadata: metadata, deduplication: deduplication, expecting: expecting)
    }

    /// 创建双向会话，使用同一套可配置 Scope 默认规则。
    func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        commands: Command.Type,
        events: Event.Type,
        expecting: Output.Type
    ) -> TFYSwiftRouteSession<Command, Event, Output> {
        openSession(route, input: input, presentation: presentation, source: source,
                    scope: scope ?? defaultScope, metadata: metadata, deduplication: deduplication,
                    commands: commands, events: events, expecting: expecting)
    }

    /// 回退至少一层；未指定 Scope 时操作实例默认容器。
    func back(count: Int = 1, scope: TFYSwiftNavigationScopeID? = nil) async throws {
        try await back(count: count, scope: scope ?? defaultScope)
    }

    /// 返回默认或显式指定的容器根页。
    func backToRoot(scope: TFYSwiftNavigationScopeID? = nil) async throws {
        try await backToRoot(scope: scope ?? defaultScope)
    }

    /// 关闭默认或显式指定容器的顶层模态页面。
    func dismiss(scope: TFYSwiftNavigationScopeID? = nil) async throws {
        try await dismiss(scope: scope ?? defaultScope)
    }

    /// 关闭默认或显式指定容器的全部子模态页面。
    func dismissAll(scope: TFYSwiftNavigationScopeID? = nil) async throws {
        try await dismissAll(scope: scope ?? defaultScope)
    }
}

@MainActor
/// 路由调度器；初始化时注入驱动，也可注入独立注册表、事件中心和拦截流水线。
public final class TFYSwiftRouter: TFYSwiftRouting {
    /// App 配置的默认导航容器；不要求采用固定业务名称。
    public let defaultScope: TFYSwiftNavigationScopeID

    /// 地址解析或恢复编码注册表，由当前流程持有。
    public let registry: TFYSwiftRouteRegistry
    /// 共享的业务拦截流水线。
    public let interceptors: TFYSwiftInterceptorPipeline
    /// 事件中心、历史记录或会话事件流；具体语义由所属类型决定。
    public let events: TFYSwiftRouteEventCenter
    /// 接收导航变更的平台驱动或 Scope 分发驱动。
    public let driver: any TFYSwiftNavigationDriver
    /// 新会话使用的命令与事件缓冲策略。
    public let sessionBuffering: TFYSwiftRouteSessionBuffering
    /// 单个事务允许的最大重定向次数，防止地址间循环跳转。
    public var maximumRedirectDepth = 8
    /// 单个事务允许的最大挂起恢复次数，防止条件一直未满足。
    public var maximumSuspensionDepth = 8
    /// 诊断状态记录的容量上限，至少为 1；清理记录不会取消事务。
    public var transactionStateCapacity = 500 {
        didSet {
            transactionStateCapacity = max(1, transactionStateCapacity)
            pruneTransactionStatesIfNeeded()
        }
    }

    /// 按事务 ID 查询的最近状态，不应当作为导航栈的数据源。
    public private(set) var transactionStates: [UUID: TFYSwiftRouteTransactionState] = [:]
    private var pendingResults: [UUID: TFYSwiftRouteResult] = [:]
    private var executionTasks: [UUID: Task<Void, Never>] = [:]
    private var transactionOrder: [UUID] = []
    private var activeTransactions: [UUID: TFYSwiftRouteTransaction] = [:]

    /// 注入驱动与可选的完整基础设施；便利初始化器自动创建注册表、事件中心与拦截流水线。
    public init(
        registry: TFYSwiftRouteRegistry,
        interceptors: TFYSwiftInterceptorPipeline,
        events: TFYSwiftRouteEventCenter,
        driver: any TFYSwiftNavigationDriver,
        defaultScope: TFYSwiftNavigationScopeID = .main,
        sessionBuffering: TFYSwiftRouteSessionBuffering = .standard
    ) {
        self.defaultScope = defaultScope
        self.registry = registry
        self.interceptors = interceptors
        self.events = events
        self.driver = driver
        self.sessionBuffering = sessionBuffering
    }

    /// 注入驱动与可选的完整基础设施；便利初始化器自动创建注册表、事件中心与拦截流水线。
    public convenience init(
        driver: any TFYSwiftNavigationDriver,
        defaultScope: TFYSwiftNavigationScopeID = .main,
        sessionBuffering: TFYSwiftRouteSessionBuffering = .standard
    ) {
        self.init(
            registry: TFYSwiftRouteRegistry(),
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver,
            defaultScope: defaultScope,
            sessionBuffering: sessionBuffering
        )
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws {
        let transaction = makeTransaction(
            route: TFYSwiftAnyRoute(route),
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication
        )

        do {
            let completedTransaction = try await execute(transaction, interaction: nil)
            transition(completedTransaction, to: .completed, event: .completed)
        } catch {
            fail(activeTransactions[transaction.id] ?? transaction, with: error)
            throw error
        }
    }

    /// Opens a route that has already been validated and type-erased by an external-input adapter.
    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open(
        _ route: TFYSwiftAnyRoute,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .programmatic,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws {
        let transaction = makeTransaction(
            route: route,
            presentation: presentation,
            source: source,
            scope: scope ?? defaultScope,
            metadata: metadata,
            deduplication: deduplication
        )
        do {
            let completedTransaction = try await execute(transaction, interaction: nil)
            transition(completedTransaction, to: .completed, event: .completed)
        } catch {
            fail(activeTransactions[transaction.id] ?? transaction, with: error)
            throw error
        }
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        expecting: Result.Type
    ) async throws -> Result {
        let transaction = makeTransaction(
            route: TFYSwiftAnyRoute(route),
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication
        )

        do {
            return try await awaitResult(transaction: transaction, interaction: TFYSwiftRouteInteraction())
        } catch {
            failIfActive(transaction, with: error)
            throw error
        }
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws {
        let transaction = makeTransaction(
            route: TFYSwiftAnyRoute(route),
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication
        )
        let interaction = TFYSwiftRouteInteraction(input: TFYSwiftRoutePayload(input))
        do {
            let completedTransaction = try await execute(transaction, interaction: interaction)
            transition(completedTransaction, to: .completed, event: .completed)
        } catch {
            fail(activeTransactions[transaction.id] ?? transaction, with: error)
            throw error
        }
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    public func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        expecting: Result.Type
    ) async throws -> Result {
        let transaction = makeTransaction(
            route: TFYSwiftAnyRoute(route),
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication
        )
        let interaction = TFYSwiftRouteInteraction(input: TFYSwiftRoutePayload(input))
        do {
            return try await awaitResult(transaction: transaction, interaction: interaction)
        } catch {
            failIfActive(transaction, with: error)
            throw error
        }
    }

    /// 创建命令流、事件流和异步结果任务；返回句柄后即可发送命令。
    public func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        commands: Command.Type,
        events: Event.Type,
        expecting: Output.Type
    ) -> TFYSwiftRouteSession<Command, Event, Output> {
        let transaction = makeTransaction(
            route: TFYSwiftAnyRoute(route),
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication
        )
        let commandChannel = TFYSwiftRouteCommandChannel(
            commands,
            bufferingPolicy: sessionBuffering.commands
        )
        let eventChannel = TFYSwiftRouteEventChannel(
            events,
            bufferingPolicy: sessionBuffering.events
        )
        let eventStream: AsyncStream<Event>
        do {
            eventStream = try eventChannel.stream(of: events)
        } catch {
            preconditionFailure("TFYSwiftRouter internal event channel error: \(error)")
        }
        let interaction = TFYSwiftRouteInteraction(
            input: TFYSwiftRoutePayload(input),
            commands: commandChannel,
            events: eventChannel
        )
        let task = Task { @MainActor [weak self] in
            guard let self else { throw TFYSwiftRouteError.cancelled }
            do {
                return try await self.awaitResult(transaction: transaction, interaction: interaction) as Output
            } catch {
                self.failIfActive(transaction, with: error)
                throw error
            }
        }
        return TFYSwiftRouteSession(
            events: eventStream,
            commands: commandChannel,
            interaction: interaction,
            resultTask: task
        )
    }

    private func awaitResult<Result: Sendable>(
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction
    ) async throws -> Result {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let result = TFYSwiftRouteResult(
                    transactionID: transaction.id,
                    completionEnabled: false,
                    finish: { [weak self, weak interaction] value in
                        let effectiveTransaction = self?.activeTransactions[transaction.id] ?? transaction
                        self?.pendingResults.removeValue(forKey: transaction.id)
                        interaction?.finishChannels()
                        interaction?.detachResult()
                        guard let typedValue = value as? Result else {
                            let mismatch = TFYSwiftRouteError.resultTypeMismatch(
                                expected: String(reflecting: Result.self),
                                actual: String(reflecting: type(of: value))
                            )
                            self?.fail(effectiveTransaction, with: mismatch)
                            continuation.resume(throwing: mismatch)
                            return
                        }
                        self?.transition(effectiveTransaction, to: .completed, event: .completed)
                        continuation.resume(returning: typedValue)
                    },
                    cancel: { [weak self, weak interaction] error in
                        let effectiveTransaction = self?.activeTransactions[transaction.id] ?? transaction
                        self?.pendingResults.removeValue(forKey: transaction.id)
                        self?.executionTasks.removeValue(forKey: transaction.id)?.cancel()
                        interaction?.finishChannels()
                        interaction?.detachResult()
                        self?.fail(effectiveTransaction, with: error)
                        continuation.resume(throwing: error)
                    }
                )
                interaction.attach(result: result)
                pendingResults[transaction.id] = result

                let executionTask = Task { @MainActor [weak self] in
                    guard let self else {
                        result.cancel()
                        return
                    }
                    defer { self.executionTasks.removeValue(forKey: transaction.id) }
                    do {
                        _ = try await self.execute(transaction, interaction: interaction)
                        result.enableCompletion()
                    } catch {
                        result.cancel(error)
                    }
                }
                executionTasks[transaction.id] = executionTask
            }
        } onCancel: { [router = self, transactionID = transaction.id] in
            Task { @MainActor in
                router.pendingResults[transactionID]?.cancel(TFYSwiftRouteError.cancelled)
            }
        }
    }

    /// 按事务 ID 取消等待中的结果；结果已完成或不存在时无操作。
    public func cancelResult(transactionID: UUID) {
        pendingResults[transactionID]?.cancel(TFYSwiftRouteError.cancelled)
    }

    /// 只移除该事务的诊断状态，不会取消正在运行的导航。
    public func removeTransactionState(id: UUID) {
        transactionStates.removeValue(forKey: id)
        transactionOrder.removeAll { $0 == id }
    }

    /// 清空诊断状态索引，不会取消正在运行的导航或结果等待。
    public func removeAllTransactionStates() {
        transactionStates.removeAll()
        transactionOrder.removeAll()
    }

    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    public func back(count: Int = 1, scope: TFYSwiftNavigationScopeID) async throws {
        try await driver.back(count: max(1, count), in: scope)
    }

    /// 清理当前导航栈的根页之后的页面及其交互。
    public func backToRoot(scope: TFYSwiftNavigationScopeID) async throws {
        try await driver.backToRoot(in: scope)
    }

    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    public func dismiss(scope: TFYSwiftNavigationScopeID) async throws {
        try await driver.dismiss(in: scope)
    }

    /// 关闭当前 Scope 的全部模态页面及其交互。
    public func dismissAll(scope: TFYSwiftNavigationScopeID) async throws {
        try await driver.dismissAll(in: scope)
    }

    /// 返回当前驱动追踪的地址，包含受支持的模态页面。
    public func routes(scope: TFYSwiftNavigationScopeID? = nil) -> [TFYSwiftAnyRoute] {
        driver.routes(in: scope ?? defaultScope)
    }

    /// 返回可用于恢复的 root/push 地址顺序；内置驱动排除模态和自定义呈现。
    public func navigationRoutes(scope: TFYSwiftNavigationScopeID? = nil) -> [TFYSwiftAnyRoute] {
        driver.navigationRoutes(in: scope ?? defaultScope)
    }

    private func makeTransaction(
        route: TFYSwiftAnyRoute,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) -> TFYSwiftRouteTransaction {
        let context = TFYSwiftRouteContext(source: source, scope: scope, metadata: metadata)
        let transaction = TFYSwiftRouteTransaction(
            route: route,
            context: context,
            presentation: presentation,
            deduplication: deduplication
        )
        activeTransactions[transaction.id] = transaction
        transition(transaction, to: .created, event: .created)
        return transaction
    }

    private func execute(
        _ originalTransaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws -> TFYSwiftRouteTransaction {
        var transaction = originalTransaction
        var redirects = 0
        var suspensions = 0

        while true {
            try Task.checkCancellation()
            transition(transaction, to: .intercepting, event: .interceptStarted)
            let interception = await interceptors.run(transaction)
            try Task.checkCancellation()
            switch interception {
            case .proceed:
                break
            case .redirect(let route):
                redirects += 1
                guard redirects <= maximumRedirectDepth else { throw TFYSwiftRouteError.redirectLoop }
                emit(transaction, .redirected, message: "→ \(route.typeName)")
                transaction.route = route
                activeTransactions[transaction.id] = transaction
                continue
            case .suspend(let suspension):
                suspensions += 1
                guard suspensions <= maximumSuspensionDepth else { throw TFYSwiftRouteError.suspensionLoop }
                transition(transaction, to: .suspended(reason: suspension.reason), event: .suspended, message: suspension.reason)
                guard try await suspension.resume() else {
                    throw TFYSwiftRouteError.suspensionCancelled(suspension.reason)
                }
                try Task.checkCancellation()
                emit(transaction, .resumed)
                continue
            case .reject(let error):
                throw error
            }
            break
        }

        try Task.checkCancellation()
        switch transaction.deduplication {
        case .ignoreIfTop where driver.isTop(transaction.route, in: transaction.context.scope):
            if interaction != nil { throw TFYSwiftRouteError.destinationUnavailable("去重策略复用已有页面时无法绑定新的交互") }
            emit(transaction, .deduplicated, message: "ignoreIfTop")
            return transaction
        case .singleTop where driver.isTop(transaction.route, in: transaction.context.scope):
            if interaction != nil { throw TFYSwiftRouteError.destinationUnavailable("去重策略复用已有页面时无法绑定新的交互") }
            emit(transaction, .deduplicated, message: "singleTop")
            return transaction
        case .singleTask:
            if interaction != nil {
                if driver.routes(in: transaction.context.scope).contains(transaction.route) {
                    throw TFYSwiftRouteError.destinationUnavailable("复用已有页面时无法绑定新的交互")
                }
                break
            }
            if try await driver.activate(transaction.route, in: transaction.context.scope) {
                emit(transaction, .deduplicated, message: "singleTask")
                return transaction
            }
        case .none, .ignoreIfTop, .singleTop:
            break
        }

        transition(transaction, to: .resolving, event: nil)
        let destination = try await registry.resolve(transaction.route, context: transaction.context)
        try Task.checkCancellation()
        emit(transaction, .resolved, message: destination.identifier)
        transition(transaction, to: .presenting, event: .presentStarted)
        try Task.checkCancellation()
        try await driver.present(
            destination: destination,
            route: transaction.route,
            transaction: transaction,
            interaction: interaction
        )
        try Task.checkCancellation()
        transition(transaction, to: .presented, event: .presented)
        return transaction
    }

    private func transition(
        _ transaction: TFYSwiftRouteTransaction,
        to state: TFYSwiftRouteTransactionState,
        event: TFYSwiftRouteEventName?,
        message: String? = nil
    ) {
        guard activeTransactions[transaction.id] != nil else { return }
        if transactionStates[transaction.id] == nil {
            transactionOrder.append(transaction.id)
        }
        transactionStates[transaction.id] = state
        if let event { emit(transaction, event, message: message) }
        if state.isTerminal {
            activeTransactions.removeValue(forKey: transaction.id)
        }
        pruneTransactionStatesIfNeeded()
    }

    private func fail(_ transaction: TFYSwiftRouteTransaction, with error: Error) {
        if error is CancellationError || (error as? TFYSwiftRouteError) == .cancelled {
            transition(transaction, to: .cancelled, event: .cancelled)
        } else {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            transition(transaction, to: .failed(message: message), event: .failed, message: message)
        }
    }

    private func failIfActive(_ transaction: TFYSwiftRouteTransaction, with error: Error) {
        guard let effectiveTransaction = activeTransactions[transaction.id] else { return }
        fail(effectiveTransaction, with: error)
    }

    private func emit(
        _ transaction: TFYSwiftRouteTransaction,
        _ name: TFYSwiftRouteEventName,
        message: String? = nil
    ) {
        events.emit(TFYSwiftRouteEvent(
            transactionID: transaction.id,
            name: name,
            routeName: transaction.route.typeName,
            scope: transaction.context.scope,
            elapsedMilliseconds: Date().timeIntervalSince(transaction.context.timestamp) * 1_000,
            message: message
        ))
    }

    private func pruneTransactionStatesIfNeeded() {
        let overflow = transactionOrder.count - transactionStateCapacity
        guard overflow > 0 else { return }
        let removed = transactionOrder.prefix(overflow)
        removed.forEach { transactionStates.removeValue(forKey: $0) }
        transactionOrder.removeFirst(overflow)
    }
}

public extension TFYSwiftRouter {
    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        timeout: TimeInterval,
        expecting: Result.Type
    ) async throws -> Result {
        try await TFYSwiftTimeout.race(timeout: timeout) {
            try await self.open(
                route,
                presentation: presentation,
                source: source,
                scope: scope ?? self.defaultScope,
                metadata: metadata,
                deduplication: deduplication,
                expecting: expecting
            )
        }
    }

    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID? = nil,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none,
        timeout: TimeInterval,
        expecting: Result.Type
    ) async throws -> Result {
        try await TFYSwiftTimeout.race(timeout: timeout) {
            try await self.open(
                route,
                input: input,
                presentation: presentation,
                source: source,
                scope: scope ?? self.defaultScope,
                metadata: metadata,
                deduplication: deduplication,
                expecting: expecting
            )
        }
    }
}

private extension TFYSwiftRouteTransactionState {
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed: true
        default: false
        }
    }
}

// TFYSwiftInteraction.swift
// 单次导航的临时通信。Input 随事务传递；Command 发往页面；Event 和最终 Output 返回调用方。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// A transient, strongly typed input that travels with one navigation transaction.
/// It deliberately does not participate in Route hashing, deep links, or restoration.
/// 一次性输入的类型擦除容器；不参与地址 Hash、URL 编码或快照恢复。
public struct TFYSwiftRoutePayload: @unchecked Sendable {
    /// 原始类型名称，用于诊断和类型不匹配提示。
    public let typeName: String
    private let storage: Any

    /// 保存任意 Sendable 输入；内部只读持有，不要求模型可编码或可 Hash。
    public init<Value: Sendable>(_ value: Value) {
        typeName = String(reflecting: Value.self)
        storage = value
    }

    /// 按声明类型读取输入或等待最终结果；类型不匹配和流程失败会抛错。
    public func value<Value: Sendable>(as type: Value.Type = Value.self) throws -> Value {
        guard let value = storage as? Value else {
            throw TFYSwiftRouteError.inputTypeMismatch(
                expected: String(reflecting: Value.self),
                actual: typeName
            )
        }
        return value
    }
}

/// Caller-to-destination command pipe. Commands can trigger refresh, selection, playback, etc.
@MainActor
/// 调用方向目标页面发送命令的流；同一流应由一个消费者读取。
public final class TFYSwiftRouteCommandChannel {
    /// 本通道约定的命令类型名。
    public let commandTypeName: String
    private let commandTypeID: ObjectIdentifier
    private let sendOperation: (Any) -> Void
    private let streamOperation: () -> Any
    private let finishOperation: () -> Void
    private var isFinished = false

    /// 为指定命令类型创建缓冲流；消费者开始之前发送的命令会缓冲等待。
    public init<Command: Sendable>(_ type: Command.Type = Command.self) {
        commandTypeName = String(reflecting: Command.self)
        commandTypeID = ObjectIdentifier(Command.self)
        var continuation: AsyncStream<Command>.Continuation?
        let stream = AsyncStream<Command> { continuation = $0 }
        sendOperation = { value in
            guard let command = value as? Command else { return }
            continuation?.yield(command)
        }
        streamOperation = { stream }
        finishOperation = { continuation?.finish() }
    }

    /// 发送类型匹配的命令或事件；通道缺失、类型错误或已结束时抛错。
    public func send<Command: Sendable>(_ command: Command) throws {
        guard !isFinished else { throw TFYSwiftRouteError.interactionFinished }
        guard ObjectIdentifier(Command.self) == commandTypeID else {
            throw TFYSwiftRouteError.commandTypeMismatch(
                expected: commandTypeName,
                actual: String(reflecting: Command.self)
            )
        }
        sendOperation(command)
    }

    /// 获取类型匹配的 AsyncStream；同一通道应只选择一个消费位置。
    public func stream<Command: Sendable>(of type: Command.Type = Command.self) throws -> AsyncStream<Command> {
        guard ObjectIdentifier(Command.self) == commandTypeID,
              let stream = streamOperation() as? AsyncStream<Command> else {
            throw TFYSwiftRouteError.commandTypeMismatch(
                expected: commandTypeName,
                actual: String(reflecting: Command.self)
            )
        }
        return stream
    }

    /// 结束当前结果或流；重复调用会被忽略。
    public func finish() {
        guard !isFinished else { return }
        isFinished = true
        finishOperation()
    }
}

/// Destination-to-caller event pipe. It supports any number of click or state-change callbacks.
@MainActor
/// 目标页面向调用方发送连续事件的流；不是多订阅者广播。
public final class TFYSwiftRouteEventChannel {
    /// 本通道约定的事件类型名。
    public let eventTypeName: String
    private let eventTypeID: ObjectIdentifier
    private let sendOperation: (Any) -> Void
    private let streamOperation: () -> Any
    private let finishOperation: () -> Void
    private var isFinished = false

    /// 为指定事件类型创建缓冲流；流程结束时必须 finish 以唤醒消费者。
    public init<Event: Sendable>(_ type: Event.Type = Event.self) {
        eventTypeName = String(reflecting: Event.self)
        eventTypeID = ObjectIdentifier(Event.self)
        var continuation: AsyncStream<Event>.Continuation?
        let stream = AsyncStream<Event> { continuation = $0 }
        sendOperation = { value in
            guard let event = value as? Event else { return }
            continuation?.yield(event)
        }
        streamOperation = { stream }
        finishOperation = { continuation?.finish() }
    }

    /// 发送类型匹配的命令或事件；通道缺失、类型错误或已结束时抛错。
    public func send<Event: Sendable>(_ event: Event) throws {
        guard !isFinished else { throw TFYSwiftRouteError.interactionFinished }
        guard ObjectIdentifier(Event.self) == eventTypeID else {
            throw TFYSwiftRouteError.eventTypeMismatch(
                expected: eventTypeName,
                actual: String(reflecting: Event.self)
            )
        }
        sendOperation(event)
    }

    /// 获取类型匹配的 AsyncStream；同一通道应只选择一个消费位置。
    public func stream<Event: Sendable>(of type: Event.Type = Event.self) throws -> AsyncStream<Event> {
        guard ObjectIdentifier(Event.self) == eventTypeID,
              let stream = streamOperation() as? AsyncStream<Event> else {
            throw TFYSwiftRouteError.eventTypeMismatch(
                expected: eventTypeName,
                actual: String(reflecting: Event.self)
            )
        }
        return stream
    }

    /// 结束当前结果或流；重复调用会被忽略。
    public func finish() {
        guard !isFinished else { return }
        isFinished = true
        finishOperation()
    }
}

/// All transient communication for a single destination. The UI adapters receive this object,
/// while feature Routes remain small, Hashable values.
@MainActor
/// 单个目标页面的通信对象，组合输入、结果以及可选的命令/事件通道。
public final class TFYSwiftRouteInteraction {
    /// 本次导航的可选临时输入，不会自动持久化。
    public let input: TFYSwiftRoutePayload?
    /// 可选的一次性结果句柄；普通无返回值请求为 nil。
    public private(set) var result: TFYSwiftRouteResult?
    /// 可选的调用方向目标页发送的命令通道。
    public let commands: TFYSwiftRouteCommandChannel?
    /// 事件中心、历史记录或会话事件流；具体语义由所属类型决定。
    public let events: TFYSwiftRouteEventChannel?

    /// 组合单次导航需要的输入、结果和通道；不使用的能力可为 nil。
    public init(
        input: TFYSwiftRoutePayload? = nil,
        result: TFYSwiftRouteResult? = nil,
        commands: TFYSwiftRouteCommandChannel? = nil,
        events: TFYSwiftRouteEventChannel? = nil
    ) {
        self.input = input
        self.result = result
        self.commands = commands
        self.events = events
    }

    deinit {
        let result = result
        Task { @MainActor in result?.cancel() }
    }

    func attach(result: TFYSwiftRouteResult) {
        self.result = result
    }

    func detachResult() {
        result = nil
    }

    /// 同时结束命令和事件流，唤醒正在等待的消费者。
    public func finishChannels() {
        commands?.finish()
        events?.finish()
    }

    /// 取消结果等待并按当前对象职责关闭交互资源；不等同于自动关闭 UI。
    public func cancel(_ error: Error = TFYSwiftRouteError.cancelled) {
        result?.cancel(error)
        finishChannels()
    }
}

/// UI-independent destination context shared by UIKit and SwiftUI adapters.
@MainActor
/// 页面工厂收到的统一上下文；通过它读取 Input、订阅命令和发送事件/结果。
public struct TFYSwiftDestinationContext {
    /// 平台无关的请求上下文，含来源、Scope 和 Metadata。
    public let routeContext: TFYSwiftRouteContext
    /// 本次请求采用的呈现策略。
    public let presentation: TFYSwiftRoutePresentation
    /// 目标页面持有的临时通信资源。
    public let interaction: TFYSwiftRouteInteraction?

    /// 可选的一次性结果句柄；普通无返回值请求为 nil。
    public var result: TFYSwiftRouteResult? { interaction?.result }
    /// 页面的临时输入载荷，使用 input(as:) 恢复类型。
    public var inputPayload: TFYSwiftRoutePayload? { interaction?.input }

    /// 构建传给页面工厂的上下文；UIKit 和 SwiftUI 共享相同通信接口。
    public init(
        routeContext: TFYSwiftRouteContext,
        presentation: TFYSwiftRoutePresentation,
        interaction: TFYSwiftRouteInteraction? = nil
    ) {
        self.routeContext = routeContext
        self.presentation = presentation
        self.interaction = interaction
    }

    /// 读取本次请求的强类型输入；缺失或类型不匹配时抛错。
    public func input<Value: Sendable>(as type: Value.Type = Value.self) throws -> Value {
        guard let inputPayload else { throw TFYSwiftRouteError.inputMissing(String(reflecting: Value.self)) }
        return try inputPayload.value(as: type)
    }

    /// 取得发送给当前目标页面的命令流，供 for await 持续处理。
    public func commands<Command: Sendable>(of type: Command.Type = Command.self) throws -> AsyncStream<Command> {
        guard let commands = interaction?.commands else {
            throw TFYSwiftRouteError.commandChannelMissing(String(reflecting: Command.self))
        }
        return try commands.stream(of: type)
    }

    /// 发送类型匹配的命令或事件；通道缺失、类型错误或已结束时抛错。
    public func send<Event: Sendable>(_ event: Event) throws {
        guard let events = interaction?.events else {
            throw TFYSwiftRouteError.eventChannelMissing(String(reflecting: Event.self))
        }
        try events.send(event)
    }
}

/// A bidirectional route session: commands go to the page, events and one final result come back.
@MainActor
/// 双向会话句柄；由调用方持有，并负责在流程结束或放弃时取消。
public final class TFYSwiftRouteSession<Command: Sendable, Event: Sendable, Output: Sendable> {
    /// 事件中心、历史记录或会话事件流；具体语义由所属类型决定。
    public let events: AsyncStream<Event>
    private let commands: TFYSwiftRouteCommandChannel
    private let interaction: TFYSwiftRouteInteraction
    private let resultTask: Task<Output, Error>

    /// 组装会话句柄；通常由 Router/TestRouter 创建，调用方负责持有和取消。
    public init(
        events: AsyncStream<Event>,
        commands: TFYSwiftRouteCommandChannel,
        interaction: TFYSwiftRouteInteraction,
        resultTask: Task<Output, Error>
    ) {
        self.events = events
        self.commands = commands
        self.interaction = interaction
        self.resultTask = resultTask
    }

    /// 发送类型匹配的命令或事件；通道缺失、类型错误或已结束时抛错。
    public func send(_ command: Command) throws {
        try commands.send(command)
    }

    /// Callback-style convenience over `events`. Use either this method or iterate `events`.
    @discardableResult
    /// 以回调方式消费事件；返回的 Task 可取消，不要同时再遍历 events。
    public func observeEvents(
        _ handler: @escaping @MainActor @Sendable (Event) -> Void
    ) -> Task<Void, Never> {
        let events = events
        return Task { @MainActor in
            for await event in events { handler(event) }
        }
    }

    /// 异步等待唯一最终输出；成功、取消或失败由结果任务决定。
    public var value: Output {
        get async throws { try await resultTask.value }
    }

    /// 按声明类型读取输入或等待最终结果；类型不匹配和流程失败会抛错。
    public func value(timeout: TimeInterval) async throws -> Output {
        try await TFYSwiftTimeout.race(
            timeout: timeout,
            operation: { try await self.resultTask.value },
            onTimeout: {
                self.resultTask.cancel()
                self.interaction.cancel(TFYSwiftRouteError.timeout)
            }
        )
    }

    /// 取消结果等待并按当前对象职责关闭交互资源；不等同于自动关闭 UI。
    public func cancel() {
        resultTask.cancel()
        interaction.cancel()
    }
}

enum TFYSwiftTimeout {
    private enum Outcome<Value: Sendable>: Sendable {
        case value(Value)
        case timedOut
    }

    @MainActor
    static func race<Value: Sendable>(
        timeout: TimeInterval,
        operation: @escaping @MainActor @Sendable () async throws -> Value,
        onTimeout: @escaping @MainActor @Sendable () -> Void = {}
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Outcome<Value>.self) { group in
            group.addTask { .value(try await operation()) }
            group.addTask {
                let maximumSeconds = Double(UInt64.max / 1_000_000_000)
                let finiteTimeout = timeout.isNaN ? 0 : timeout
                let seconds = min(max(0, finiteTimeout), maximumSeconds)
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                return .timedOut
            }
            guard let first = try await group.next() else {
                throw TFYSwiftRouteError.cancelled
            }
            switch first {
            case .value(let value):
                group.cancelAll()
                return value
            case .timedOut:
                onTimeout()
                group.cancelAll()
                throw TFYSwiftRouteError.timeout
            }
        }
    }
}

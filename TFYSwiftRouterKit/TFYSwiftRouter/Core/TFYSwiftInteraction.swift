import Foundation

/// A transient, strongly typed input that travels with one navigation transaction.
/// It deliberately does not participate in Route hashing, deep links, or restoration.
public struct TFYSwiftRoutePayload: @unchecked Sendable {
    public let typeName: String
    private let storage: Any

    public init<Value: Sendable>(_ value: Value) {
        typeName = String(reflecting: Value.self)
        storage = value
    }

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
public final class TFYSwiftRouteCommandChannel {
    public let commandTypeName: String
    private let commandTypeID: ObjectIdentifier
    private let sendOperation: (Any) -> Void
    private let streamOperation: () -> Any
    private let finishOperation: () -> Void
    private var isFinished = false

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

    public func finish() {
        guard !isFinished else { return }
        isFinished = true
        finishOperation()
    }
}

/// Destination-to-caller event pipe. It supports any number of click or state-change callbacks.
@MainActor
public final class TFYSwiftRouteEventChannel {
    public let eventTypeName: String
    private let eventTypeID: ObjectIdentifier
    private let sendOperation: (Any) -> Void
    private let streamOperation: () -> Any
    private let finishOperation: () -> Void
    private var isFinished = false

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

    public func finish() {
        guard !isFinished else { return }
        isFinished = true
        finishOperation()
    }
}

/// All transient communication for a single destination. The UI adapters receive this object,
/// while feature Routes remain small, Hashable values.
@MainActor
public final class TFYSwiftRouteInteraction {
    public let input: TFYSwiftRoutePayload?
    public private(set) var result: TFYSwiftRouteResult?
    public let commands: TFYSwiftRouteCommandChannel?
    public let events: TFYSwiftRouteEventChannel?

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

    func attach(result: TFYSwiftRouteResult) {
        self.result = result
    }

    public func finishChannels() {
        commands?.finish()
        events?.finish()
    }

    public func cancel(_ error: Error = TFYSwiftRouteError.cancelled) {
        result?.cancel(error)
        finishChannels()
    }
}

/// UI-independent destination context shared by UIKit and SwiftUI adapters.
@MainActor
public struct TFYSwiftDestinationContext {
    public let routeContext: TFYSwiftRouteContext
    public let presentation: TFYSwiftRoutePresentation
    public let interaction: TFYSwiftRouteInteraction?

    public var result: TFYSwiftRouteResult? { interaction?.result }
    public var inputPayload: TFYSwiftRoutePayload? { interaction?.input }

    public init(
        routeContext: TFYSwiftRouteContext,
        presentation: TFYSwiftRoutePresentation,
        interaction: TFYSwiftRouteInteraction? = nil
    ) {
        self.routeContext = routeContext
        self.presentation = presentation
        self.interaction = interaction
    }

    public func input<Value: Sendable>(as type: Value.Type = Value.self) throws -> Value {
        guard let inputPayload else { throw TFYSwiftRouteError.inputMissing(String(reflecting: Value.self)) }
        return try inputPayload.value(as: type)
    }

    public func commands<Command: Sendable>(of type: Command.Type = Command.self) throws -> AsyncStream<Command> {
        guard let commands = interaction?.commands else {
            throw TFYSwiftRouteError.commandChannelMissing(String(reflecting: Command.self))
        }
        return try commands.stream(of: type)
    }

    public func send<Event: Sendable>(_ event: Event) throws {
        guard let events = interaction?.events else {
            throw TFYSwiftRouteError.eventChannelMissing(String(reflecting: Event.self))
        }
        try events.send(event)
    }
}

/// A bidirectional route session: commands go to the page, events and one final result come back.
@MainActor
public final class TFYSwiftRouteSession<Command: Sendable, Event: Sendable, Output: Sendable> {
    public let events: AsyncStream<Event>
    private let commands: TFYSwiftRouteCommandChannel
    private let interaction: TFYSwiftRouteInteraction
    private let resultTask: Task<Output, Error>

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

    public func send(_ command: Command) throws {
        try commands.send(command)
    }

    /// Callback-style convenience over `events`. Use either this method or iterate `events`.
    @discardableResult
    public func observeEvents(
        _ handler: @escaping @MainActor @Sendable (Event) -> Void
    ) -> Task<Void, Never> {
        let events = events
        return Task { @MainActor in
            for await event in events { handler(event) }
        }
    }

    public var value: Output {
        get async throws { try await resultTask.value }
    }

    public func cancel() {
        resultTask.cancel()
        interaction.cancel()
    }
}

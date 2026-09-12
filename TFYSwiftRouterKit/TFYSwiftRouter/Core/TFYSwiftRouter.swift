import Foundation

@MainActor
public protocol TFYSwiftRouting: AnyObject {
    func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws

    func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        expecting: Result.Type
    ) async throws -> Result

    func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws

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

    func back(count: Int, scope: TFYSwiftNavigationScopeID) async throws
    func backToRoot(scope: TFYSwiftNavigationScopeID) async throws
    func dismiss(scope: TFYSwiftNavigationScopeID) async throws
    func dismissAll(scope: TFYSwiftNavigationScopeID) async throws
}

public extension TFYSwiftRouting {
    func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic
    ) async throws {
        try await open(
            route,
            presentation: presentation,
            source: .userInteraction,
            scope: .main,
            metadata: .empty,
            deduplication: .none
        )
    }

    func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        expecting: Result.Type
    ) async throws -> Result {
        try await open(
            route,
            presentation: presentation,
            source: .userInteraction,
            scope: .main,
            metadata: .empty,
            deduplication: .none,
            expecting: expecting
        )
    }

    func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic
    ) async throws {
        try await open(
            route,
            input: input,
            presentation: presentation,
            source: .userInteraction,
            scope: .main,
            metadata: .empty,
            deduplication: .none
        )
    }

    func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        expecting: Result.Type
    ) async throws -> Result {
        try await open(
            route,
            input: input,
            presentation: presentation,
            source: .userInteraction,
            scope: .main,
            metadata: .empty,
            deduplication: .none,
            expecting: expecting
        )
    }

    func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        commands: Command.Type,
        events: Event.Type,
        expecting: Output.Type
    ) -> TFYSwiftRouteSession<Command, Event, Output> {
        openSession(
            route,
            input: input,
            presentation: presentation,
            source: .userInteraction,
            scope: .main,
            metadata: .empty,
            deduplication: .none,
            commands: commands,
            events: events,
            expecting: expecting
        )
    }

    func back(scope: TFYSwiftNavigationScopeID = .main) async throws {
        try await back(count: 1, scope: scope)
    }
}

@MainActor
public final class TFYSwiftRouter: TFYSwiftRouting {
    public let registry: TFYSwiftRouteRegistry
    public let interceptors: TFYSwiftInterceptorPipeline
    public let events: TFYSwiftRouteEventCenter
    public let driver: any TFYSwiftNavigationDriver
    public var maximumRedirectDepth = 8

    public private(set) var transactionStates: [UUID: TFYSwiftRouteTransactionState] = [:]
    private var pendingResults: [UUID: TFYSwiftRouteResult] = [:]

    public init(
        registry: TFYSwiftRouteRegistry,
        interceptors: TFYSwiftInterceptorPipeline,
        events: TFYSwiftRouteEventCenter,
        driver: any TFYSwiftNavigationDriver
    ) {
        self.registry = registry
        self.interceptors = interceptors
        self.events = events
        self.driver = driver
    }

    public convenience init(driver: any TFYSwiftNavigationDriver) {
        self.init(
            registry: TFYSwiftRouteRegistry(),
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
    }

    public func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
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
            try await execute(transaction, interaction: nil)
            transition(transaction, to: .completed, event: .completed)
        } catch {
            fail(transaction, with: error)
            throw error
        }
    }

    /// Opens a route that has already been validated and type-erased by an external-input adapter.
    public func open(
        _ route: TFYSwiftAnyRoute,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .programmatic,
        scope: TFYSwiftNavigationScopeID = .main,
        metadata: TFYSwiftRouteMetadata = .empty,
        deduplication: TFYSwiftRouteDeduplicationPolicy = .none
    ) async throws {
        let transaction = makeTransaction(
            route: route,
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication
        )
        do {
            try await execute(transaction, interaction: nil)
            transition(transaction, to: .completed, event: .completed)
        } catch {
            fail(transaction, with: error)
            throw error
        }
    }

    public func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
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

        return try await awaitResult(transaction: transaction, interaction: TFYSwiftRouteInteraction())
    }

    public func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
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
            try await execute(transaction, interaction: interaction)
            transition(transaction, to: .completed, event: .completed)
        } catch {
            fail(transaction, with: error)
            throw error
        }
    }

    public func open<R: TFYSwiftRoute, Input: Sendable, Result: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
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
        return try await awaitResult(transaction: transaction, interaction: interaction)
    }

    public func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation = .automatic,
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
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
        let commandChannel = TFYSwiftRouteCommandChannel(commands)
        let eventChannel = TFYSwiftRouteEventChannel(events)
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
            return try await self.awaitResult(transaction: transaction, interaction: interaction) as Output
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
                    finish: { [weak self] value in
                        self?.pendingResults.removeValue(forKey: transaction.id)
                        interaction.finishChannels()
                        guard let typedValue = value as? Result else {
                            let mismatch = TFYSwiftRouteError.resultTypeMismatch(
                                expected: String(reflecting: Result.self),
                                actual: String(reflecting: type(of: value))
                            )
                            self?.fail(transaction, with: mismatch)
                            continuation.resume(throwing: mismatch)
                            return
                        }
                        self?.transition(transaction, to: .completed, event: .completed)
                        continuation.resume(returning: typedValue)
                    },
                    cancel: { [weak self] error in
                        self?.pendingResults.removeValue(forKey: transaction.id)
                        interaction.finishChannels()
                        self?.fail(transaction, with: error)
                        continuation.resume(throwing: error)
                    }
                )
                interaction.attach(result: result)
                pendingResults[transaction.id] = result

                Task { @MainActor [weak self] in
                    guard let self else {
                        result.cancel()
                        return
                    }
                    do {
                        try await self.execute(transaction, interaction: interaction)
                    } catch {
                        result.cancel(error)
                    }
                }
            }
        } onCancel: { [router = self, transactionID = transaction.id] in
            Task { @MainActor in
                router.pendingResults[transactionID]?.cancel(TFYSwiftRouteError.cancelled)
            }
        }
    }

    public func cancelResult(transactionID: UUID) {
        pendingResults[transactionID]?.cancel(TFYSwiftRouteError.cancelled)
    }

    public func back(count: Int = 1, scope: TFYSwiftNavigationScopeID = .main) async throws {
        try await driver.back(count: max(1, count), in: scope)
    }

    public func backToRoot(scope: TFYSwiftNavigationScopeID = .main) async throws {
        try await driver.backToRoot(in: scope)
    }

    public func dismiss(scope: TFYSwiftNavigationScopeID = .main) async throws {
        try await driver.dismiss(in: scope)
    }

    public func dismissAll(scope: TFYSwiftNavigationScopeID = .main) async throws {
        try await driver.dismissAll(in: scope)
    }

    public func routes(scope: TFYSwiftNavigationScopeID = .main) -> [TFYSwiftAnyRoute] {
        driver.routes(in: scope)
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
        transition(transaction, to: .created, event: .created)
        return transaction
    }

    private func execute(
        _ originalTransaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        var transaction = originalTransaction
        var redirects = 0

        while true {
            try Task.checkCancellation()
            transition(transaction, to: .intercepting, event: .interceptStarted)
            switch await interceptors.run(transaction) {
            case .proceed:
                break
            case .redirect(let route):
                redirects += 1
                guard redirects <= maximumRedirectDepth else { throw TFYSwiftRouteError.redirectLoop }
                emit(transaction, .redirected, message: "→ \(route.typeName)")
                transaction.route = route
                continue
            case .suspend(let suspension):
                transition(transaction, to: .suspended(reason: suspension.reason), event: .suspended, message: suspension.reason)
                guard try await suspension.resume() else {
                    throw TFYSwiftRouteError.suspensionCancelled(suspension.reason)
                }
                emit(transaction, .resumed)
                continue
            case .reject(let error):
                throw error
            }
            break
        }

        switch transaction.deduplication {
        case .ignoreIfTop where driver.isTop(transaction.route, in: transaction.context.scope):
            if interaction?.result != nil { throw TFYSwiftRouteError.destinationUnavailable("去重策略未创建新页面，无法等待返回值") }
            return
        case .singleTop where driver.isTop(transaction.route, in: transaction.context.scope):
            if interaction?.result != nil { throw TFYSwiftRouteError.destinationUnavailable("去重策略未创建新页面，无法等待返回值") }
            return
        case .singleTask:
            if try await driver.activate(transaction.route, in: transaction.context.scope) {
                if interaction?.result != nil { throw TFYSwiftRouteError.destinationUnavailable("复用已有页面时无法绑定新的返回值") }
                return
            }
        case .none, .ignoreIfTop, .singleTop:
            break
        }

        transition(transaction, to: .resolving, event: nil)
        let destination = try await registry.resolve(transaction.route, context: transaction.context)
        emit(transaction, .resolved, message: destination.identifier)
        transition(transaction, to: .presenting, event: .presentStarted)
        try await driver.present(
            destination: destination,
            route: transaction.route,
            transaction: transaction,
            interaction: interaction
        )
        transition(transaction, to: .presented, event: .presented)
    }

    private func transition(
        _ transaction: TFYSwiftRouteTransaction,
        to state: TFYSwiftRouteTransactionState,
        event: TFYSwiftRouteEventName?,
        message: String? = nil
    ) {
        transactionStates[transaction.id] = state
        if let event { emit(transaction, event, message: message) }
    }

    private func fail(_ transaction: TFYSwiftRouteTransaction, with error: Error) {
        if error is CancellationError || (error as? TFYSwiftRouteError) == .cancelled {
            transition(transaction, to: .cancelled, event: .cancelled)
        } else {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            transition(transaction, to: .failed(message: message), event: .failed, message: message)
        }
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
}

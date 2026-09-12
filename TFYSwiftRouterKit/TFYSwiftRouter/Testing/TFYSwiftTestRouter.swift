import Foundation
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
public final class TFYSwiftTestRouter: TFYSwiftRouting {
    public enum Action: Equatable {
        case open(route: TFYSwiftAnyRoute, presentation: TFYSwiftRoutePresentation)
        case back(Int)
        case backToRoot
        case dismiss
        case dismissAll
    }

    public private(set) var actions: [Action] = []
    private var resultProviders: [ObjectIdentifier: () throws -> Any] = [:]

    public init() {}

    public func provide<Result: Sendable>(_ type: Result.Type, result: @escaping () throws -> Result) {
        resultProviders[ObjectIdentifier(type)] = result
    }

    public func open<R: TFYSwiftRoute>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws {
        actions.append(.open(route: TFYSwiftAnyRoute(route), presentation: presentation))
    }

    public func open<R: TFYSwiftRoute, Result: Sendable>(
        _ route: R,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        expecting: Result.Type
    ) async throws -> Result {
        actions.append(.open(route: TFYSwiftAnyRoute(route), presentation: presentation))
        guard let provider = resultProviders[ObjectIdentifier(Result.self)] else {
            throw TFYSwiftRouteError.destinationUnavailable("测试未配置 \(Result.self) 返回值")
        }
        let value = try provider()
        guard let typedValue = value as? Result else {
            throw TFYSwiftRouteError.resultTypeMismatch(
                expected: String(reflecting: Result.self),
                actual: String(reflecting: type(of: value))
            )
        }
        return typedValue
    }

    public func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        presentation: TFYSwiftRoutePresentation,
        source: TFYSwiftRouteSource,
        scope: TFYSwiftNavigationScopeID,
        metadata: TFYSwiftRouteMetadata,
        deduplication: TFYSwiftRouteDeduplicationPolicy
    ) async throws {
        actions.append(.open(route: TFYSwiftAnyRoute(route), presentation: presentation))
    }

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
        try await open(
            route,
            presentation: presentation,
            source: source,
            scope: scope,
            metadata: metadata,
            deduplication: deduplication,
            expecting: expecting
        )
    }

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
        actions.append(.open(route: TFYSwiftAnyRoute(route), presentation: presentation))
        let commandChannel = TFYSwiftRouteCommandChannel(commands)
        let eventChannel = TFYSwiftRouteEventChannel(events)
        let interaction = TFYSwiftRouteInteraction(
            input: TFYSwiftRoutePayload(input),
            commands: commandChannel,
            events: eventChannel
        )
        let stream: AsyncStream<Event>
        do { stream = try eventChannel.stream(of: events) }
        catch { preconditionFailure("TFYSwiftTestRouter internal event channel error: \(error)") }
        let task = Task { @MainActor [weak self] in
            guard let self else { throw TFYSwiftRouteError.cancelled }
            guard let provider = self.resultProviders[ObjectIdentifier(Output.self)] else {
                throw TFYSwiftRouteError.destinationUnavailable("测试未配置 \(Output.self) 返回值")
            }
            let value = try provider()
            guard let output = value as? Output else {
                throw TFYSwiftRouteError.resultTypeMismatch(
                    expected: String(reflecting: Output.self),
                    actual: String(reflecting: type(of: value))
                )
            }
            interaction.finishChannels()
            return output
        }
        return TFYSwiftRouteSession(
            events: stream,
            commands: commandChannel,
            interaction: interaction,
            resultTask: task
        )
    }

    public func back(count: Int, scope: TFYSwiftNavigationScopeID) async throws { actions.append(.back(count)) }
    public func backToRoot(scope: TFYSwiftNavigationScopeID) async throws { actions.append(.backToRoot) }
    public func dismiss(scope: TFYSwiftNavigationScopeID) async throws { actions.append(.dismiss) }
    public func dismissAll(scope: TFYSwiftNavigationScopeID) async throws { actions.append(.dismissAll) }
}

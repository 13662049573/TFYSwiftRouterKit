import Foundation

@MainActor
public final class TFYSwiftRouteResult {
    public let transactionID: UUID
    private var isFinished = false
    private let finishOperation: (Any) -> Void
    private let cancelOperation: (Error) -> Void

    init(
        transactionID: UUID,
        finish: @escaping (Any) -> Void,
        cancel: @escaping (Error) -> Void
    ) {
        self.transactionID = transactionID
        finishOperation = finish
        cancelOperation = cancel
    }

    public func finish<Value: Sendable>(with value: Value) {
        guard !isFinished else { return }
        isFinished = true
        finishOperation(value)
    }

    public func cancel(_ error: Error = TFYSwiftRouteError.cancelled) {
        guard !isFinished else { return }
        isFinished = true
        cancelOperation(error)
    }
}

@MainActor
public protocol TFYSwiftNavigationDriver: AnyObject {
    func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws

    func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool
    func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool
    func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute]
    func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws
    func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws
    func dismiss(in scope: TFYSwiftNavigationScopeID) async throws
    func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws
}

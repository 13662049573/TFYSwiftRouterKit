import Foundation

/// Dispatches navigation mutations to an independent driver for each tab/flow scope.
@MainActor
public final class TFYSwiftScopedNavigationDriver: TFYSwiftNavigationDriver {
    private var drivers: [TFYSwiftNavigationScopeID: any TFYSwiftNavigationDriver] = [:]

    public init() {}

    public func register(_ driver: any TFYSwiftNavigationDriver, for scope: TFYSwiftNavigationScopeID) {
        drivers[scope] = driver
    }

    public func unregister(scope: TFYSwiftNavigationScopeID) {
        drivers.removeValue(forKey: scope)
    }

    public func present(destination: TFYSwiftDestinationDescriptor, route: TFYSwiftAnyRoute, transaction: TFYSwiftRouteTransaction, interaction: TFYSwiftRouteInteraction?) async throws {
        try await driver(for: transaction.context.scope).present(destination: destination, route: route, transaction: transaction, interaction: interaction)
    }

    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        drivers[scope]?.isTop(route, in: scope) ?? false
    }

    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        try await driver(for: scope).activate(route, in: scope)
    }

    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        drivers[scope]?.routes(in: scope) ?? []
    }

    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).back(count: count, in: scope)
    }

    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).backToRoot(in: scope)
    }

    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).dismiss(in: scope)
    }

    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        try await driver(for: scope).dismissAll(in: scope)
    }

    private func driver(for scope: TFYSwiftNavigationScopeID) throws -> any TFYSwiftNavigationDriver {
        guard let driver = drivers[scope] else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        return driver
    }
}

// TFYSwiftTabBarNavigationDriver.swift
// Binds navigation scopes to UITabBarController indices and delegates navigation to scoped drivers.

#if canImport(UIKit)
import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// A tab definition used by `TFYSwiftRouterAssembly` when building a tab-based router.
public struct TFYSwiftTabBarScope {
    public let scope: TFYSwiftNavigationScopeID
    public let navigationController: UINavigationController

    public init(
        scope: TFYSwiftNavigationScopeID,
        navigationController: UINavigationController
    ) {
        self.scope = scope
        self.navigationController = navigationController
    }
}

@MainActor
/// Selects the tab bound to a navigation scope before forwarding navigation mutations.
public final class TFYSwiftTabBarNavigationDriver: TFYSwiftNavigationDriver, TFYSwiftNavigationCheckpointing {
    private weak var tabBarController: UITabBarController?
    private let scopedDriver: TFYSwiftScopedNavigationDriver
    private var indicesByScope: [TFYSwiftNavigationScopeID: Int] = [:]
    private var scopesByIndex: [Int: TFYSwiftNavigationScopeID] = [:]

    public init(
        tabBarController: UITabBarController,
        scopedDriver: TFYSwiftScopedNavigationDriver
    ) {
        self.tabBarController = tabBarController
        self.scopedDriver = scopedDriver
    }

    /// The scope currently selected by the tab bar, or nil when the selected index is not registered.
    public var selectedScope: TFYSwiftNavigationScopeID? {
        guard let tabBarController else { return nil }
        return scopesByIndex[tabBarController.selectedIndex]
    }

    /// Registered scopes in visual tab order.
    public var registeredScopes: [TFYSwiftNavigationScopeID] {
        scopesByIndex.keys.sorted().compactMap { scopesByIndex[$0] }
    }

    /// Binds a scope to an existing tab index.
    public func register(
        _ scope: TFYSwiftNavigationScopeID,
        at index: Int,
        replacingExisting: Bool = false
    ) throws {
        guard let tabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(index) else {
            throw TFYSwiftRouteError.presentationFailed("Tab index is unavailable: \(index)")
        }
        if !replacingExisting,
           indicesByScope[scope] != nil || scopesByIndex[index] != nil {
            throw TFYSwiftRouteError.duplicateRegistration("tab scope/index: \(scope.rawValue)/\(index)")
        }
        if let oldIndex = indicesByScope[scope] { scopesByIndex.removeValue(forKey: oldIndex) }
        if let oldScope = scopesByIndex[index] { indicesByScope.removeValue(forKey: oldScope) }
        indicesByScope[scope] = index
        scopesByIndex[index] = scope
    }

    /// Selects the tab registered for a scope without opening a destination.
    public func select(_ scope: TFYSwiftNavigationScopeID) throws {
        guard let tabBarController else {
            throw TFYSwiftRouteError.presentationFailed("UITabBarController has been released")
        }
        guard let index = indicesByScope[scope],
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(index) else {
            throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue)
        }
        tabBarController.selectedIndex = index
    }

    public func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        try select(transaction.context.scope)
        try await scopedDriver.present(
            destination: destination,
            route: route,
            transaction: transaction,
            interaction: interaction
        )
    }

    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        scopedDriver.isTop(route, in: scope)
    }

    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        try select(scope)
        return try await scopedDriver.activate(route, in: scope)
    }

    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        scopedDriver.routes(in: scope)
    }

    public func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        scopedDriver.navigationRoutes(in: scope)
    }

    public func makeNavigationCheckpoint(
        in scope: TFYSwiftNavigationScopeID
    ) throws -> any TFYSwiftNavigationCheckpoint {
        try scopedDriver.makeNavigationCheckpoint(in: scope)
    }

    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        try select(scope)
        try await scopedDriver.back(count: count, in: scope)
    }

    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        try select(scope)
        try await scopedDriver.backToRoot(in: scope)
    }

    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        try select(scope)
        try await scopedDriver.dismiss(in: scope)
    }

    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        try select(scope)
        try await scopedDriver.dismissAll(in: scope)
    }
}
#endif

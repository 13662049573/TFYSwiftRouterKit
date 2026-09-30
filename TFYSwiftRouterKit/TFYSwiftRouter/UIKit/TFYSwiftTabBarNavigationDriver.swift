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
    private struct CheckpointState {
        let id: UUID
        let restorationID: UUID
        let checkpoint: any TFYSwiftNavigationCheckpoint
        let selectedIndex: Int
        var ownedSelectionGeneration: UInt64?
        var ownedSelectedIndex: Int?
    }
    private final class Checkpoint: TFYSwiftNavigationCheckpoint {
        private weak var driver: TFYSwiftTabBarNavigationDriver?
        private let scope: TFYSwiftNavigationScopeID
        private let id: UUID
        private var isResolved = false

        init(driver: TFYSwiftTabBarNavigationDriver, scope: TFYSwiftNavigationScopeID, id: UUID) {
            self.driver = driver
            self.scope = scope
            self.id = id
        }

        func commit() {
            guard !isResolved else { return }
            isResolved = true
            driver?.resolveCheckpoint(in: scope, id: id, commit: true)
        }

        func rollback() {
            guard !isResolved else { return }
            isResolved = true
            driver?.resolveCheckpoint(in: scope, id: id, commit: false)
        }
    }
    private var checkpoints: [TFYSwiftNavigationScopeID: CheckpointState] = [:]
    private var selectionGeneration: UInt64 = 0

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
        try requireUnreservedNavigation(in: scope)
        if let previousScope = scopesByIndex[index] {
            try requireUnreservedNavigation(in: previousScope)
        }
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
        try requireSelectionOwnership(in: scope)
        guard let tabBarController else {
            throw TFYSwiftRouteError.presentationFailed("UITabBarController has been released")
        }
        guard let index = indicesByScope[scope],
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(index) else {
            throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue)
        }
        tabBarController.selectedIndex = index
        selectionGeneration &+= 1
        if let owner = TFYSwiftNavigationOperationContext.restorationID {
            for reservedScope in Array(checkpoints.keys) where checkpoints[reservedScope]?.restorationID == owner {
                checkpoints[reservedScope]?.ownedSelectionGeneration = selectionGeneration
                checkpoints[reservedScope]?.ownedSelectedIndex = index
            }
        }
    }

    public func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        if checkpoints[transaction.context.scope] != nil {
            try requireSelectionOwnership(in: transaction.context.scope)
            guard transaction.context.source == .restoration else {
                throw TFYSwiftRouteError.restorationFailed("Tab Scope 正在恢复，暂不接受其他导航操作")
            }
            switch transaction.presentation {
            case .push, .root: break
            default:
                throw TFYSwiftRouteError.restorationFailed("恢复检查点只支持 root/push 导航")
            }
        }
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
        try requireUnreservedNavigation(in: scope)
        try select(scope)
        return try await scopedDriver.activate(route, in: scope)
    }

    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        scopedDriver.routes(in: scope)
    }

    public func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        scopedDriver.navigationRoutes(in: scope)
    }

    /// 必须在 Router.withNavigationRestoration 的拥有者上下文内创建、提交或回滚。
    public func makeNavigationCheckpoint(
        in scope: TFYSwiftNavigationScopeID
    ) throws -> any TFYSwiftNavigationCheckpoint {
        guard let restorationID = TFYSwiftNavigationOperationContext.restorationID else {
            throw TFYSwiftRouteError.restorationFailed("请在 Router.withNavigationRestoration 内创建导航检查点")
        }
        try requireUnreservedNavigation(in: scope)
        guard let tabBarController, let index = indicesByScope[scope],
              tabBarController.viewControllers?.indices.contains(index) == true else {
            throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue)
        }
        let selectedIndex = tabBarController.selectedIndex
        let checkpoint = try scopedDriver.makeNavigationCheckpoint(in: scope)
        let id = UUID()
        checkpoints[scope] = CheckpointState(
            id: id,
            restorationID: restorationID,
            checkpoint: checkpoint,
            selectedIndex: selectedIndex
        )
        return Checkpoint(driver: self, scope: scope, id: id)
    }

    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        try requireUnreservedNavigation(in: scope)
        try select(scope)
        try await scopedDriver.back(count: count, in: scope)
    }

    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        try requireUnreservedNavigation(in: scope)
        try select(scope)
        try await scopedDriver.backToRoot(in: scope)
    }

    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        try requireUnreservedNavigation(in: scope)
        try select(scope)
        try await scopedDriver.dismiss(in: scope)
    }

    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        try requireUnreservedNavigation(in: scope)
        try select(scope)
        try await scopedDriver.dismissAll(in: scope)
    }

    private func requireSelectionOwnership(in scope: TFYSwiftNavigationScopeID) throws {
        guard let checkpoint = checkpoints[scope] else { return }
        guard checkpoint.restorationID == TFYSwiftNavigationOperationContext.restorationID else {
            throw TFYSwiftRouteError.restorationFailed("Tab Scope 正在恢复，暂不接受其他导航操作")
        }
    }

    private func requireUnreservedNavigation(in scope: TFYSwiftNavigationScopeID) throws {
        guard checkpoints[scope] == nil else {
            throw TFYSwiftRouteError.restorationFailed("Tab Scope 正在恢复，暂不接受其他导航操作")
        }
    }

    private func resolveCheckpoint(in scope: TFYSwiftNavigationScopeID, id: UUID, commit: Bool) {
        guard let state = checkpoints[scope], state.id == id else { return }
        if commit {
            state.checkpoint.commit()
        } else {
            state.checkpoint.rollback()
            // Do not overwrite a newer tab selection made outside this restoration.
            if let tabBarController,
               state.ownedSelectionGeneration == selectionGeneration,
               state.ownedSelectedIndex == tabBarController.selectedIndex,
               tabBarController.viewControllers?.indices.contains(state.selectedIndex) == true {
                tabBarController.selectedIndex = state.selectedIndex
                for reservedScope in Array(checkpoints.keys)
                    where checkpoints[reservedScope]?.restorationID == state.restorationID {
                    checkpoints[reservedScope]?.ownedSelectedIndex = state.selectedIndex
                }
            }
        }
        checkpoints.removeValue(forKey: scope)
    }
}
#endif

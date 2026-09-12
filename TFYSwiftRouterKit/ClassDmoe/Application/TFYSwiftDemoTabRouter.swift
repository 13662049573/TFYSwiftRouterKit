import UIKit

/// Cross-feature navigation contract. Feature roots depend on this protocol, not UITabBarController
/// or another feature's view controller.
@MainActor
protocol TFYSwiftDemoNavigating: AnyObject {
    func select(_ tab: TFYSwiftDemoTab, popToRoot: Bool) async throws

    func open<R: TFYSwiftRoute>(
        _ route: R,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation
    ) async throws

    func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation
    ) async throws

    func open<R: TFYSwiftRoute, Input: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation,
        expecting: Output.Type
    ) async throws -> Output

    func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation,
        commands: Command.Type,
        events: Event.Type,
        expecting: Output.Type
    ) -> TFYSwiftRouteSession<Command, Event, Output>
}

@MainActor
final class TFYSwiftDemoTabRouter: TFYSwiftDemoNavigating {
    private weak var tabBarController: UITabBarController?
    private let router: TFYSwiftRouter

    init(tabBarController: UITabBarController, router: TFYSwiftRouter) {
        self.tabBarController = tabBarController
        self.router = router
    }

    /// Installs feature roots through the same resolver/destination pipeline as every other page.
    /// No feature view controller type crosses into the app shell.
    func installRoots(_ registrations: [TFYSwiftRootRouteRegistration]) async throws {
        let rootsByScope = Dictionary(grouping: registrations, by: \.scope)
        for tab in TFYSwiftDemoTab.allCases {
            guard let registrations = rootsByScope[tab.scope], registrations.count == 1,
                  let registration = registrations.first else {
                throw TFYSwiftRouteError.invalidPayload("Tab \(tab) 必须且只能注册一个根路由")
            }
            try await router.open(
                registration.route,
                presentation: .root(animated: false),
                source: .programmatic,
                scope: registration.scope
            )
        }
        tabBarController?.selectedIndex = TFYSwiftDemoTab.home.rawValue
    }

    func select(_ tab: TFYSwiftDemoTab, popToRoot: Bool = false) async throws {
        tabBarController?.selectedIndex = tab.rawValue
        if popToRoot { try await router.backToRoot(scope: tab.scope) }
    }

    func open<R: TFYSwiftRoute>(
        _ route: R,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation = .push()
    ) async throws {
        tabBarController?.selectedIndex = tab.rawValue
        try await router.open(route, presentation: presentation, scope: tab.scope)
    }

    func open<R: TFYSwiftRoute, Input: Sendable>(
        _ route: R,
        input: Input,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation = .push()
    ) async throws {
        tabBarController?.selectedIndex = tab.rawValue
        try await router.open(route, input: input, presentation: presentation, scope: tab.scope)
    }

    func open<R: TFYSwiftRoute, Input: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation = .push(),
        expecting: Output.Type
    ) async throws -> Output {
        tabBarController?.selectedIndex = tab.rawValue
        return try await router.open(
            route,
            input: input,
            presentation: presentation,
            scope: tab.scope,
            expecting: expecting
        )
    }

    func openSession<R: TFYSwiftRoute, Input: Sendable, Command: Sendable, Event: Sendable, Output: Sendable>(
        _ route: R,
        input: Input,
        in tab: TFYSwiftDemoTab,
        presentation: TFYSwiftRoutePresentation = .push(),
        commands: Command.Type,
        events: Event.Type,
        expecting: Output.Type
    ) -> TFYSwiftRouteSession<Command, Event, Output> {
        tabBarController?.selectedIndex = tab.rawValue
        return router.openSession(
            route,
            input: input,
            presentation: presentation,
            scope: tab.scope,
            commands: commands,
            events: events,
            expecting: expecting
        )
    }

    func open(
        _ route: TFYSwiftAnyRoute,
        in tab: TFYSwiftDemoTab,
        source: TFYSwiftRouteSource
    ) async throws {
        tabBarController?.selectedIndex = tab.rawValue
        try await router.open(route, source: source, scope: tab.scope, deduplication: .singleTop)
    }
}

import UIKit

/// The demo app shell. It owns platform containers and wires component registrars, but never
/// imports, initializes or stores a feature's concrete view controller.
@MainActor
final class TFYSwiftDemoAppCoordinator {
    let tabBarController = UITabBarController()
    let assembly: TFYSwiftRouterAssembly

    private let navigationControllers: [TFYSwiftDemoTab: UINavigationController]
    private let navigator: TFYSwiftDemoTabRouter
    private let services = TFYSwiftComponentServiceRegistry()
    private let history = TFYSwiftRouteHistory()
    private let authentication = TFYSwiftDemoAuthenticationInterceptor()
    private let deepLinks = TFYSwiftDeepLinkEngine(
        policy: .app(scheme: "tfyswift", universalLinkHosts: ["router.tfy.com"])
    )
    private let deepLinkSetup: Task<Void, Never>
    private var rootRegistrations: [TFYSwiftRootRouteRegistration] = []
    private var startupTask: Task<Void, Error>?

    init() throws {
        var stacks: [TFYSwiftDemoTab: UINavigationController] = [:]
        for tab in TFYSwiftDemoTab.allCases {
            let navigation = UINavigationController()
            navigation.navigationBar.prefersLargeTitles = true
            navigation.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.symbol),
                tag: tab.rawValue
            )
            stacks[tab] = navigation
        }
        navigationControllers = stacks
        tabBarController.viewControllers = TFYSwiftDemoTab.allCases.compactMap { stacks[$0] }

        guard let homeNavigation = stacks[.home] else {
            throw TFYSwiftRouteError.scopeUnavailable(TFYSwiftDemoTab.home.scope.rawValue)
        }
        assembly = TFYSwiftRouterAssembly(
            navigationController: homeNavigation,
            initialScope: TFYSwiftDemoTab.home.scope
        )
        for tab in TFYSwiftDemoTab.allCases where tab != .home {
            guard let navigation = stacks[tab] else { continue }
            assembly.register(navigationController: navigation, for: tab.scope)
        }

        navigator = TFYSwiftDemoTabRouter(tabBarController: tabBarController, router: assembly.router)
        deepLinkSetup = Task { [deepLinks] in await deepLinks.add(TFYSwiftDemoDeepLinkParser()) }

        let cartService: any TFYSwiftDemoCartServicing = TFYSwiftDemoCartService()
        try services.register(cartService, for: TFYSwiftDemoComponentKeys.cart)

        let productFlow = TFYSwiftDemoProductFlow(navigator: navigator)
        let modules = TFYSwiftDemoFeatureModules.makeModules(
            navigator: navigator,
            productFlow: productFlow,
            services: services,
            history: history,
            deepLinkHandler: { [weak self] url in
                guard let self else { throw TFYSwiftRouteError.cancelled }
                try await self.handleExternalURL(url)
            }
        )
        rootRegistrations = try assembly.registerComponents(modules)

        assembly.events.add(history)
        assembly.interceptors.add(authentication, priority: 100)
        authentication.presenterProvider = { [weak self] in self?.visibleViewController }
    }

    /// App shell startup knows only type-erased root route addresses. Component factories create
    /// their own root view controllers after the router resolves these addresses.
    func start() async throws {
        if let startupTask {
            try await startupTask.value
            return
        }
        let navigator = navigator
        let registrations = rootRegistrations
        let task = Task { @MainActor in
            try await navigator.installRoots(registrations)
        }
        startupTask = task
        try await task.value
    }

    func handleExternalURL(_ url: URL) async throws {
        try await start()
        await deepLinkSetup.value
        let source: TFYSwiftRouteSource = url.scheme == "https" ? .universalLink : .deepLink
        let route = try await deepLinks.route(for: TFYSwiftDeepLinkRequest(url: url, source: source))
        try await navigator.open(route, in: tab(for: route), source: source)
    }

    private func tab(for route: TFYSwiftAnyRoute) -> TFYSwiftDemoTab {
        if route.cast(to: TFYSwiftDemoProductRoute.self) != nil { return .products }
        if route.cast(to: TFYSwiftDemoCartRoute.self) != nil { return .cart }
        if route.cast(to: TFYSwiftDemoProfileRoute.self) != nil { return .profile }
        return .home
    }

    private var visibleViewController: UIViewController? {
        guard let selected = tabBarController.selectedViewController else { return tabBarController }
        return topViewController(from: selected)
    }

    private func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController { return topViewController(from: presented) }
        if let navigation = root as? UINavigationController, let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        return root
    }
}

import UIKit

enum TFYDemoTab: String, CaseIterable, Sendable {
    case start
    case playground
    case stack
    case timeline

    var scope: TFYSwiftNavigationScopeID { .init("demo.\(rawValue)") }

    var title: String {
        switch self {
        case .start: "开始"
        case .playground: "演练"
        case .stack: "导航栈"
        case .timeline: "事件"
        }
    }

    var symbol: String {
        switch self {
        case .start: "play.circle.fill"
        case .playground: "slider.horizontal.3"
        case .stack: "square.stack.3d.up.fill"
        case .timeline: "waveform.path.ecg"
        }
    }
}

@MainActor
final class TFYDemoAppCoordinator {
    let tabBarController: UITabBarController
    let assembly: TFYSwiftRouterAssembly

    private let rootRegistrations: [TFYSwiftRootRouteRegistration]
    private let startRouter: TFYDemoStartRouter
    private let playgroundRouter: TFYDemoPlaygroundRouter
    private let stackRouter: TFYDemoStackRouter
    private let timelineRouter: TFYDemoTimelineRouter
    private var started = false

    init() throws {
        let tabBarController = UITabBarController()
        let tabs = TFYDemoTab.allCases.map { tab in
            let navigationController = UINavigationController()
            navigationController.navigationBar.isTranslucent = false
            navigationController.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.symbol),
                selectedImage: UIImage(systemName: tab.symbol)
            )
            navigationController.tabBarItem.accessibilityIdentifier = "demo.tab.\(tab.rawValue)"
            return TFYSwiftTabBarScope(scope: tab.scope, navigationController: navigationController)
        }
        let assembly = try TFYSwiftRouterAssembly(
            tabBarController: tabBarController,
            tabs: tabs,
            initialScope: TFYDemoTab.start.scope
        )
        let history = TFYSwiftRouteHistory(capacity: 300)
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try TFYDemoStartRouter.registerRestorableRoutes(in: restorationRegistry)
        try TFYDemoPlaygroundRouter.registerRestorableRoutes(in: restorationRegistry)
        try TFYDemoStackRouter.registerRestorableRoutes(in: restorationRegistry)
        try TFYDemoTimelineRouter.registerRestorableRoutes(in: restorationRegistry)
        let restoration = TFYSwiftRestorationCoordinator(
            registry: restorationRegistry,
            router: assembly.router
        )
        let showMessage: @MainActor (String, String) -> Void = { [weak tabBarController] title, message in
            guard let tabBarController else { return }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            Self.topViewController(from: tabBarController).present(alert, animated: true)
        }

        let startRouter = TFYDemoStartRouter(assembly: assembly, showMessage: showMessage)
        let playgroundRouter = TFYDemoPlaygroundRouter(
            assembly: assembly,
            restoration: restoration,
            showMessage: showMessage
        )
        let stackRouter = TFYDemoStackRouter(assembly: assembly, showMessage: showMessage)
        let timelineRouter = TFYDemoTimelineRouter(history: history)

        self.tabBarController = tabBarController
        self.assembly = assembly
        self.startRouter = startRouter
        self.playgroundRouter = playgroundRouter
        self.stackRouter = stackRouter
        self.timelineRouter = timelineRouter
        rootRegistrations = try assembly.registerComponents([
            startRouter,
            playgroundRouter,
            stackRouter,
            timelineRouter
        ])

        configureAppearance()
        assembly.events.add(history)
        playgroundRouter.installInterceptors()
        playgroundRouter.installPlatformPresentations()
    }

    func start() async throws {
        guard !started else { return }
        started = true
        await startRouter.start()
        for registration in rootRegistrations {
            try await assembly.router.open(
                registration.route,
                presentation: .root(animated: false),
                source: .programmatic,
                scope: registration.scope
            )
        }
        try assembly.tabBarDriver?.select(TFYDemoTab.start.scope)
    }

    func handleExternalURL(_ url: URL) async throws {
        try await startRouter.handleExternalURL(url)
    }

    private func configureAppearance() {
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = .systemBackground
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = .systemBackground
        tabBarController.tabBar.standardAppearance = tabAppearance
        tabBarController.tabBar.scrollEdgeAppearance = tabAppearance
        tabBarController.tabBar.tintColor = .systemIndigo
        tabBarController.tabBar.isTranslucent = false
    }

    private static func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController { return topViewController(from: presented) }
        if let navigation = root as? UINavigationController, let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return root
    }
}

import UIKit

@MainActor
final class TFYDemoAppCoordinator {
    let tabBarController: UITabBarController
    let assembly: TFYSwiftRouterAssembly

    private let history = TFYSwiftRouteHistory(capacity: 300)
    private let deepLinks = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tfyrouter"))
    private let redirectInterceptor = TFYDemoRedirectInterceptor()
    private let restoration: TFYSwiftRestorationCoordinator
    private var rootRegistrations: [TFYSwiftRootRouteRegistration] = []
    private var windows: [UIWindow] = []
    private var started = false

    init() throws {
        let tabBarController = UITabBarController()
        let tabs = TFYDemoTab.allCases.map { tab -> TFYSwiftTabBarScope in
            let navigationController = UINavigationController()
            navigationController.navigationBar.isTranslucent = false
            navigationController.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.symbol),
                selectedImage: UIImage(systemName: tab.symbol)
            )
            navigationController.tabBarItem.accessibilityIdentifier = "demo.tab.\(tab.rawValue)"
            return .init(scope: tab.scope, navigationController: navigationController)
        }
        let assembly = try TFYSwiftRouterAssembly(
            tabBarController: tabBarController,
            tabs: tabs,
            initialScope: TFYDemoTab.start.scope
        )
        let restorationRegistry = TFYSwiftRestorationRegistry()
        try Self.registerRestorableRoutes(in: restorationRegistry)

        self.tabBarController = tabBarController
        self.assembly = assembly
        restoration = TFYSwiftRestorationCoordinator(registry: restorationRegistry, router: assembly.router)

        configureAppearance()
        assembly.events.add(history)
        assembly.interceptors.add(redirectInterceptor)
        rootRegistrations = try assembly.registerConfigurations(
            TFYDemoRouteCatalog.configurations(
                history: history,
                routes: { [weak router = assembly.router] scope in
                    router?.navigationRoutes(scope: scope) ?? []
                },
                onAction: { [weak self] action in self?.handle(action) },
                onSelectTab: { [weak self] tab in self?.select(tab) },
                onRestoreRoot: { [weak self] scope in self?.restoreRootRequested(scope) }
            )
        )
        configurePlatformPresentations()
    }

    func start() async throws {
        guard !started else { return }
        started = true
        await deepLinks.add(TFYDemoDeepLinkParser(), priority: 100)
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
        try await assembly.router.open(
            TFYSwiftDeepLinkRequest(url: url),
            using: deepLinks,
            presentation: .push(),
            scope: TFYDemoTab.playground.scope
        )
    }

    private static func registerRestorableRoutes(in registry: TFYSwiftRestorationRegistry) throws {
        try registry.register(TFYDemoStartRoute.self, identifier: "demo.start.v1")
        try registry.register(TFYDemoPlaygroundRoute.self, identifier: "demo.playground.v1")
        try registry.register(TFYDemoStackRoute.self, identifier: "demo.stack.v1")
        try registry.register(TFYDemoTimelineRoute.self, identifier: "demo.timeline.v1")
        try registry.register(TFYDemoDetailRoute.self, identifier: "demo.detail.v1")
        try registry.register(TFYDemoSwiftUIRoute.self, identifier: "demo.swiftui.v1")
        try registry.register(TFYDemoLegacyRoute.self, identifier: "demo.legacy.v1")
    }

    private func configurePlatformPresentations() {
        for driver in assembly.navigationDrivers.values {
            driver.registerCustomPresentation(identifier: "demo.flip") { source, destination, _ in
                destination.modalPresentationStyle = .formSheet
                destination.modalTransitionStyle = .flipHorizontal
                source.present(destination, animated: true)
            }
            driver.registerNewWindowPresentation { [weak self] source, destination, _ in
                guard let self, let scene = source.view.window?.windowScene else {
                    throw TFYSwiftRouteError.sceneUnavailable
                }
                let window = UIWindow(windowScene: scene)
                window.windowLevel = .alert + 1
                let close = { [weak self, weak window] in
                    guard let self, let window else { return }
                    window.isHidden = true
                    windows.removeAll { $0 === window }
                    tabBarController.view.window?.makeKey()
                }
                destination.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    systemItem: .close,
                    primaryAction: UIAction { _ in close() }
                )
                (destination as? TFYDemoCloseHandling)?.onClose = close
                window.rootViewController = UINavigationController(rootViewController: destination)
                windows.append(window)
                window.makeKeyAndVisible()
            }
        }
    }

    private func handle(_ action: TFYDemoAction) {
        run { [weak self] in
            guard let self else { return }
            try await perform(action)
        }
    }

    private func perform(_ action: TFYDemoAction) async throws {
        let scope = assembly.tabBarDriver?.selectedScope ?? TFYDemoTab.start.scope
        switch action {
        case .push:
            try await openDetail("Push 路由", "页面已进入当前 Scope 的导航栈。", .push(), scope)
        case .sheet:
            try await openDetail("Sheet 路由", "向下滑动关闭时，Router 会同步结束等待中的交互。", .sheet(), scope)
        case .fullScreen:
            try await openDetail("Full Screen", "全屏展示仍保留 Route 事件与结果生命周期。", .fullScreen(), scope)
        case .replace:
            try await openDetail("Replace 栈顶", "当前栈顶已被新 Route 替换。", .replace(), scope)
        case .root:
            try await restoreRoot(scope: scope)
        case .custom:
            try await openDetail("Custom 转场", "翻转效果由宿主注册，Router 只分发标识。", .custom("demo.flip"), scope)
        case .newWindow:
            try await openDetail("New Window", "页面由宿主 Window/Scene 回调展示。", .newWindow, scope)
        case .crossTab:
            try await openDetail(
                "跨 Tab 已完成",
                "调用方只传 playground scope；TabBar Driver 自动选择目标 Tab。",
                .push(),
                TFYDemoTab.playground.scope
            )
        case .singleTop:
            let route = TFYDemoDetailRoute(title: "Single Top", message: "重复地址会激活已有页面，不会继续堆叠。")
            try await assembly.router.open(route, presentation: .push(), scope: scope, deduplication: .singleTop)
            try await assembly.router.open(route, presentation: .push(), scope: scope, deduplication: .singleTop)
        case .singleTask:
            let target = TFYDemoDetailRoute(title: "Single Task", message: "第三次打开会回到这个已有页面。")
            try await assembly.router.open(target, presentation: .push(), scope: scope)
            try await assembly.router.open(
                TFYDemoDetailRoute(title: "临时页面", message: "这个页面会被 singleTask 从栈中移除。"),
                presentation: .push(),
                scope: scope
            )
            try await assembly.router.open(target, presentation: .push(), scope: scope, deduplication: .singleTask)
        case .interceptor:
            try await assembly.router.open(TFYDemoLegacyRoute(), presentation: .push(), scope: scope)
        case .deepLink:
            guard let url = URL(string: "tfyrouter://open/detail?title=Deep%20Link%20Route") else { return }
            try await handleExternalURL(url)
        case .picker:
            let result = try await assembly.router.openTyped(
                TFYDemoPickerRoute(),
                input: .init(title: "选择路由策略", options: ["singleTop", "singleTask", "none"]),
                presentation: .sheet(),
                scope: scope
            )
            try await closeResultSheet(scope: scope)
            showMessage("结果已返回", message: result)
        case .session:
            let session = assembly.router.openTypedSession(
                TFYDemoSessionRoute(),
                input: TFYDemoSessionInput(name: "Router Explorer"),
                presentation: .sheet(),
                scope: scope
            )
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                try? session.send(.updateStatus("调用方命令已到达页面"))
            }
            let eventTask = Task { @MainActor in
                var iterator = session.events.makeAsyncIterator()
                return await iterator.next()
            }
            let output = try await session.value
            _ = await eventTask.value
            try await closeResultSheet(scope: scope)
            showMessage("会话完成", message: output.summary)
        case .timeout:
            try await demonstrateSessionTermination(scope: scope, timeout: true)
        case .cancel:
            try await demonstrateSessionTermination(scope: scope, timeout: false)
        case .swiftUI:
            try await assembly.router.open(TFYDemoSwiftUIRoute(), presentation: .sheet(), scope: scope)
        case .registration:
            demonstrateRegistrationRollback()
        case .service:
            try demonstrateComponentService()
        case .restoration:
            try await demonstrateRestoration(returningTo: scope)
        case .back:
            try await assembly.router.back(scope: scope)
        case .backToRoot:
            try await assembly.router.backToRoot(scope: scope)
        case .dismiss:
            try await assembly.router.dismiss(scope: scope)
        case .dismissAll:
            try await assembly.router.dismissAll(scope: scope)
        case .showTimeline:
            try assembly.tabBarDriver?.select(TFYDemoTab.timeline.scope)
        case .clearTimeline:
            history.removeAll()
        }
    }

    private func openDetail(
        _ title: String,
        _ message: String,
        _ presentation: TFYSwiftRoutePresentation,
        _ scope: TFYSwiftNavigationScopeID
    ) async throws {
        try await assembly.router.open(
            TFYDemoDetailRoute(title: title, message: message),
            presentation: presentation,
            scope: scope
        )
    }

    private func closeResultSheet(scope: TFYSwiftNavigationScopeID) async throws {
        try await assembly.router.dismiss(scope: scope)
        for _ in 0..<40 where hasPresentedController(from: tabBarController) {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func demonstrateSessionTermination(
        scope: TFYSwiftNavigationScopeID,
        timeout: Bool
    ) async throws {
        let session = assembly.router.openTypedSession(
            TFYDemoSessionRoute(),
            input: .init(name: timeout ? "Timeout Probe" : "Cancellation Probe"),
            presentation: .sheet(),
            scope: scope
        )
        do {
            if timeout {
                _ = try await session.value(timeout: 0.8)
            } else {
                try? await Task.sleep(for: .milliseconds(450))
                session.cancel()
                _ = try await session.value
            }
            throw TFYSwiftRouteError.presentationFailed("演示会话意外完成")
        } catch {
            let routeError = error as? TFYSwiftRouteError
            let expected = timeout ? routeError == .timeout : routeError == .cancelled || error is CancellationError
            guard expected else { throw error }
            try await closeResultSheet(scope: scope)
            showMessage(
                timeout ? "超时已处理" : "取消已处理",
                message: timeout
                    ? "等待已以 timeout 结束，页面由 Router 关闭。"
                    : "调用方已取消 Result、Command 和 Event 生命周期。"
            )
        }
    }

    private func demonstrateRegistrationRollback() {
        var duplicateWasRejected = false
        do {
            try assembly.routes.performRegistrationTransaction {
                try assembly.routes.register(TFYDemoRegistrationProbeRoute.self) { _, _ in
                    TFYSwiftDestinationDescriptor(identifier: "demo.registration.probe")
                }
                try assembly.routes.register(TFYDemoRegistrationProbeRoute.self) { _, _ in
                    TFYSwiftDestinationDescriptor(identifier: "demo.registration.duplicate")
                }
            }
        } catch {
            duplicateWasRejected = true
        }
        let rolledBack = !assembly.routes.contains(TFYDemoRegistrationProbeRoute.self)
        showMessage(
            "注册事务",
            message: duplicateWasRejected && rolledBack
                ? "重复注册已拒绝，事务中新加入的 Route 已完整回滚。"
                : "事务检查未得到预期结果。"
        )
    }

    private func demonstrateComponentService() throws {
        let services = TFYSwiftComponentServiceRegistry()
        let key = TFYSwiftComponentServiceKey<String>(namespace: "demo.primary")
        try services.performRegistrationTransaction { try services.register("Router Service Ready", for: key) }
        let value = try services.resolve(key)
        services.unregister(key)
        showMessage("组件服务", message: "已解析：\(value)\n注销后 contains = \(services.contains(key))")
    }

    private func demonstrateRestoration(returningTo scope: TFYSwiftNavigationScopeID) async throws {
        let snapshot = try restoration.makeSnapshot(scopes: TFYDemoTab.allCases.map(\.scope))
        let data = try JSONEncoder().encode(snapshot)
        try await restoration.restore(snapshot)
        try assembly.tabBarDriver?.select(scope)
        let routeCount = snapshot.scopes.reduce(0) { $0 + $1.routes.count }
        showMessage(
            "导航快照已恢复",
            message: "已编码 \(snapshot.scopes.count) 个 Scope、\(routeCount) 条 Route，共 \(data.count) 字节。"
        )
    }

    private func restoreRootRequested(_ scope: TFYSwiftNavigationScopeID) {
        run { [weak self] in
            guard let self else { return }
            try await restoreRoot(scope: scope)
        }
    }

    private func restoreRoot(scope: TFYSwiftNavigationScopeID) async throws {
        guard let registration = rootRegistrations.first(where: { $0.scope == scope }) else {
            throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue)
        }
        try await assembly.router.open(
            registration.route,
            presentation: .root(animated: true),
            source: .programmatic,
            scope: scope
        )
    }

    private func select(_ tab: TFYDemoTab) {
        do { try assembly.tabBarDriver?.select(tab.scope) }
        catch { show(error) }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor [weak self] in
            do { try await operation() }
            catch { self?.show(error) }
        }
    }

    private func show(_ error: Error) {
        showMessage("操作未完成", message: error.localizedDescription)
    }

    private func showMessage(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        topViewController(from: tabBarController).present(alert, animated: true)
    }

    private func hasPresentedController(from root: UIViewController) -> Bool {
        if root.presentedViewController != nil { return true }
        if let navigation = root as? UINavigationController, let visible = navigation.visibleViewController {
            return hasPresentedController(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return hasPresentedController(from: selected)
        }
        return false
    }

    private func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController { return topViewController(from: presented) }
        if let navigation = root as? UINavigationController, let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return root
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
}

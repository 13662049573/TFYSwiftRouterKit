import UIKit

@MainActor
final class TFYDemoPlaygroundRouter: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYDemoTab.playground.scope,
        route: TFYDemoPlaygroundRoute.root
    )

    private let assembly: TFYSwiftRouterAssembly
    private let restoration: TFYSwiftRestorationCoordinator
    private let showMessage: @MainActor (String, String) -> Void
    private var windows: [UIWindow] = []

    init(
        assembly: TFYSwiftRouterAssembly,
        restoration: TFYSwiftRestorationCoordinator,
        showMessage: @escaping @MainActor (String, String) -> Void
    ) {
        self.assembly = assembly
        self.restoration = restoration
        self.showMessage = showMessage
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.register(TFYDemoPlaygroundRoute.self) { [weak self] route, context in
            guard let self else { throw TFYSwiftRouteError.destinationUnavailable("Playground Router released") }
            switch route {
            case .root:
                return TFYDemoPlaygroundViewController(model: TFYDemoPlaygroundModel()) { [weak self] action in
                    self?.handle(action)
                }
            case .detail(let title, let message):
                let restore: (() -> Void)?
                if case .replace = context.presentation {
                    let scope = context.routeContext.scope
                    restore = { [weak self] in self?.restoreRootRequested(scope) }
                } else {
                    restore = nil
                }
                return TFYDemoPlaygroundViewController(title: title, message: message, onRestoreRoot: restore)
            case .legacy:
                throw TFYSwiftRouteError.destinationUnavailable("Legacy Route should be redirected")
            }
        }
        try assembly.registerTyped(TFYDemoPlaygroundSessionRoute.self) { _, context in
            TFYDemoPlaygroundViewController(sessionContext: context)
        }
    }

    static func registerRestorableRoutes(in registry: TFYSwiftRestorationRegistry) throws {
        try registry.register(TFYDemoPlaygroundRoute.self, identifier: "demo.playground.v2")
    }

    func installInterceptors() {
        assembly.interceptors.add(identifier: "demo.legacy.redirect", priority: 100) { transaction in
            guard transaction.route.cast(to: TFYDemoPlaygroundRoute.self) == .legacy else { return .proceed }
            return .redirect(
                TFYSwiftAnyRoute(
                    TFYDemoPlaygroundRoute.detail(
                        title: "拦截器已重定向",
                        message: "legacy 地址在解析前被闭包 Interceptor 替换。"
                    )
                )
            )
        }
    }

    func installPlatformPresentations() {
        for driver in assembly.navigationDrivers.values {
            driver.registerCustomPresentation(identifier: "demo.flip") { source, destination, _ in
                destination.modalPresentationStyle = .formSheet
                destination.modalTransitionStyle = .flipHorizontal
                await withCheckedContinuation { continuation in
                    source.present(destination, animated: true) { continuation.resume() }
                }
            }
            driver.registerNewWindowPresentation { [weak self] source, destination, _ in
                guard let self, let scene = source.view.window?.windowScene else {
                    throw TFYSwiftRouteError.sceneUnavailable
                }
                let presentingWindow = source.view.window
                let window = UIWindow(windowScene: scene)
                window.windowLevel = .alert + 1
                let close = { [weak self, weak window] in
                    guard let self, let window else { return }
                    window.isHidden = true
                    windows.removeAll { $0 === window }
                    presentingWindow?.makeKey()
                }
                destination.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    systemItem: .close,
                    primaryAction: UIAction { _ in close() }
                )
                (destination as? TFYDemoWindowCloseHandling)?.onClose = close
                window.rootViewController = UINavigationController(rootViewController: destination)
                windows.append(window)
                window.makeKeyAndVisible()
            }
        }
    }

    private func handle(_ action: TFYDemoPlaygroundAction) {
        run { [weak self] in
            guard let self else { return }
            let scope = assembly.tabBarDriver?.selectedScope ?? TFYDemoTab.playground.scope
            switch action {
            case .push: try await openDetail("Push 路由", "页面已进入当前 Scope 的导航栈。", .push(), scope)
            case .sheet: try await openDetail("Sheet 路由", "支持 Detent、Grabber 与交互关闭。", .sheet(), scope)
            case .fullScreen: try await openDetail("Full Screen", "全屏展示保留完整生命周期。", .fullScreen(), scope)
            case .replace: try await openDetail("Replace 栈顶", "当前栈顶已被新 Route 替换。", .replace(), scope)
            case .root:
                try await restoreRoot(scope: scope)
                showMessage("Root 已完成", "当前 Scope 已使用根 Route 重建。")
            case .custom: try await openDetail("Custom 转场", "完成时机由宿主回调定义。", .custom("demo.flip"), scope)
            case .newWindow: try await openDetail("New Window", "页面由宿主 Window / Scene 展示。", .newWindow, scope)
            case .singleTop: try await demonstrateSingleTop(scope: scope)
            case .singleTask: try await demonstrateSingleTask(scope: scope)
            case .interceptor:
                try await assembly.router.open(TFYDemoPlaygroundRoute.legacy, presentation: .push(), scope: scope)
            case .timeout: try await demonstrateSessionTermination(scope: scope, timeout: true)
            case .cancel: try await demonstrateSessionTermination(scope: scope, timeout: false)
            case .registration: demonstrateRegistrationRollback()
            case .service: try demonstrateComponentService()
            case .restoration: try await demonstrateRestoration(returningTo: scope)
            case .back:
                try await openDetail("Back 目标页", "下一页将由 Router 返回。", .push(), scope)
                try await openDetail("待返回页面", "Router 会移除当前页。", .push(), scope)
                try await assembly.router.back(scope: scope)
            case .backToRoot:
                try await openDetail("临时页面", "Router 将返回根路由。", .push(), scope)
                try await assembly.router.backToRoot(scope: scope)
                showMessage("已返回根路由", "当前 Scope 仅保留根页面。")
            case .dismiss:
                try await openDetail("待关闭 Sheet", "Router 将在短暂停留后关闭。", .sheet(), scope)
                try? await Task.sleep(for: .milliseconds(600))
                try await assembly.router.dismiss(scope: scope)
                showMessage("Dismiss 已完成", "内置 Driver 已等待关闭转场结束。")
            case .dismissAll:
                try await openDetail("第一层 Sheet", "随后会展示第二层。", .sheet(), scope)
                try await openDetail("第二层 Sheet", "Router 将关闭完整模态层级。", .sheet(), scope)
                try? await Task.sleep(for: .milliseconds(600))
                try await assembly.router.dismissAll(scope: scope)
                showMessage("Dismiss All 已完成", "当前 Scope 的全部模态页面已关闭。")
            }
        }
    }

    private func openDetail(
        _ title: String,
        _ message: String,
        _ presentation: TFYSwiftRoutePresentation,
        _ scope: TFYSwiftNavigationScopeID
    ) async throws {
        try await assembly.router.open(
            TFYDemoPlaygroundRoute.detail(title: title, message: message),
            presentation: presentation,
            scope: scope
        )
    }

    private func demonstrateSingleTop(scope: TFYSwiftNavigationScopeID) async throws {
        let route = TFYDemoPlaygroundRoute.detail(title: "Single Top", message: "重复地址不会继续堆叠。")
        try await assembly.router.open(route, presentation: .push(), scope: scope, deduplication: .singleTop)
        try await assembly.router.open(route, presentation: .push(), scope: scope, deduplication: .singleTop)
    }

    private func demonstrateSingleTask(scope: TFYSwiftNavigationScopeID) async throws {
        let target = TFYDemoPlaygroundRoute.detail(title: "Single Task", message: "再次打开会回到已有页面。")
        try await assembly.router.open(target, presentation: .push(), scope: scope)
        try await openDetail("临时页面", "随后会被 singleTask 移除。", .push(), scope)
        try await assembly.router.open(target, presentation: .push(), scope: scope, deduplication: .singleTask)
    }

    private func demonstrateSessionTermination(scope: TFYSwiftNavigationScopeID, timeout: Bool) async throws {
        let session = assembly.router.openTypedSession(
            TFYDemoPlaygroundSessionRoute(),
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
            try await assembly.router.dismiss(scope: scope)
            showMessage(
                timeout ? "超时已处理" : "取消已处理",
                timeout
                    ? "等待已以 timeout 结束，页面由 Router 关闭。"
                    : "调用方已取消 Result、Command 和 Event 生命周期。"
            )
        }
    }

    private func demonstrateRegistrationRollback() {
        var duplicateWasRejected = false
        do {
            try assembly.routes.performRegistrationTransaction {
                try assembly.routes.register(TFYDemoPlaygroundRegistrationProbeRoute.self) { _, _ in
                    TFYSwiftDestinationDescriptor(identifier: "demo.registration.probe")
                }
                try assembly.routes.register(TFYDemoPlaygroundRegistrationProbeRoute.self) { _, _ in
                    TFYSwiftDestinationDescriptor(identifier: "demo.registration.duplicate")
                }
            }
        } catch {
            duplicateWasRejected = true
        }
        let rolledBack = !assembly.routes.contains(TFYDemoPlaygroundRegistrationProbeRoute.self)
        showMessage(
            "注册事务",
            duplicateWasRejected && rolledBack
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
        showMessage("组件服务", "已解析：\(value)\n注销后 contains = \(services.contains(key))")
    }

    private func demonstrateRestoration(returningTo scope: TFYSwiftNavigationScopeID) async throws {
        let snapshot = try restoration.makeSnapshot(scopes: TFYDemoTab.allCases.map(\.scope))
        let data = try JSONEncoder().encode(snapshot)
        try await restoration.restore(snapshot)
        try assembly.tabBarDriver?.select(scope)
        let routeCount = snapshot.scopes.reduce(0) { $0 + $1.routes.count }
        showMessage(
            "导航快照已恢复",
            "已编码 \(snapshot.scopes.count) 个 Scope、\(routeCount) 条 Route，共 \(data.count) 字节。"
        )
    }

    private func restoreRootRequested(_ scope: TFYSwiftNavigationScopeID) {
        run { [weak self] in try await self?.restoreRoot(scope: scope) }
    }

    private func restoreRoot(scope: TFYSwiftNavigationScopeID) async throws {
        try await assembly.router.open(
            TFYDemoPlaygroundRoute.root,
            presentation: .root(animated: true),
            source: .programmatic,
            scope: scope
        )
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor [weak self] in
            do { try await operation() }
            catch { self?.showMessage("操作未完成", error.localizedDescription) }
        }
    }
}

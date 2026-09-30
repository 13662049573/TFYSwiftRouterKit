import UIKit

/// 视频项目组合根：五个独立 Scope，共享账号和业务数据。
@MainActor
final class TFYDemoAppCoordinator {
    let state = TFYDemoAppState()
    let tabBarController: TFYDemoTabBarController
    let assembly: TFYSwiftRouterAssembly
    lazy var home = TFYDemoHomeRouter(app: self)
    lazy var free = TFYDemoFreeRouter(app: self)
    lazy var publish = TFYDemoPublishRouter(app: self)
    lazy var member = TFYDemoMemberRouter(app: self)
    lazy var profile = TFYDemoProfileRouter(app: self)
    private let links = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tfyswift"))
    private var started = false
    private var operation: Task<Void, Never>?
    private var activeScope: TFYSwiftNavigationScopeID { TFYDemoTab.allCases[tabBarController.selectedIndex].scope }

    init() throws {
        let tabs = TFYDemoTabBarController()
        tabBarController = tabs
        let containers = TFYDemoTab.allCases.map { tab -> TFYSwiftTabBarScope in
            let navigation = UINavigationController()
            navigation.delegate = tabs
            navigation.setNavigationBarHidden(true, animated: false)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .black
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigation.navigationBar.standardAppearance = appearance
            navigation.navigationBar.scrollEdgeAppearance = appearance
            navigation.navigationBar.tintColor = .white
            return .init(scope: tab.scope, navigationController: navigation)
        }
        assembly = try TFYSwiftRouterAssembly(
            tabBarController: tabs, tabs: containers, initialScope: TFYDemoTab.home.scope)
        try registerPages()
        tabs.onSelect = { [weak self] tab in
            guard let self, self.operation == nil else { return }
            if tab == .publish { self.compose() } else { self.select(tab) }
        }
        assembly.interceptors.add(identifier: "video.account", priority: 100) { [weak self] transaction in
            guard let self else { return .reject(.cancelled) }
            let protected =
                transaction.route.cast(to: TFYDemoPublishRoute.self) != nil
                || transaction.route.cast(to: TFYDemoBuyRoute.self) != nil
            guard protected, self.state.account == nil else { return .proceed }
            return .suspend(
                .init(reason: "登录后继续") { [weak self] in
                    guard let self else { return false }
                    try await self.authenticate(scope: transaction.context.scope)
                    return self.state.account != nil
                })
        }
    }
    private func registerPages() throws {
        try assembly.register(TFYDemoHomeRoute.self) { [unowned self] route, context in
            let page = try home.make(route, scope: context.routeContext.scope)
            if case .root = route {} else { page.hidesBottomBarWhenPushed = true }
            return page
        }
        try assembly.register(TFYDemoFreeRoute.self) { [unowned self] _ in free.make() }
        try assembly.register(TFYDemoMemberRoute.self) { [unowned self] _ in member.make() }
        try assembly.register(TFYDemoProfileRoute.self) { [unowned self] route in
            let page = profile.make(route)
            if case .root = route {} else { page.hidesBottomBarWhenPushed = true }
            return page
        }
        try assembly.registerTyped(TFYDemoPublishRoute.self) { [unowned self] _, context in publish.make(context) }
        try assembly.registerTyped(TFYDemoBuyRoute.self) { [unowned self] _, context in member.makeCheckout(context) }
        try assembly.registerTyped(TFYDemoLoginRoute.self) { [unowned self] _, context in profile.makeLogin(context) }
    }
    func start() async throws {
        guard !started else { return }
        try await assembly.router.open(TFYDemoHomeRoute.root, presentation: .root(), scope: TFYDemoTab.home.scope)
        try await assembly.router.open(TFYDemoFreeRoute.root, presentation: .root(), scope: TFYDemoTab.free.scope)
        try await assembly.router.open(TFYDemoMemberRoute.root, presentation: .root(), scope: TFYDemoTab.member.scope)
        try await assembly.router.open(TFYDemoProfileRoute.root, presentation: .root(), scope: TFYDemoTab.profile.scope)
        // 加号是发布动作，不切换到空的 Tab 页面。
        await links.add(TFYDemoVideoLinkParser())
        started = true
        select(.home)
    }
    func select(_ tab: TFYDemoTab) {
        guard tab != .publish else {
            compose()
            return
        }
        try? assembly.tabBarDriver?.select(tab.scope)
        tabBarController.refreshBar()
    }
    func open<R: TFYSwiftRoute>(_ route: R, scope: TFYSwiftNavigationScopeID) {
        run { [self] in
            let presentation: TFYSwiftRoutePresentation
            if let homeRoute = route as? TFYDemoHomeRoute, case .player = homeRoute {
                tabBarController.floatingBar.isHidden = true
                presentation = .fullScreen()
            } else {
                presentation = .push()
            }
            try await assembly.router.open(route, presentation: presentation, scope: scope, deduplication: .singleTop)
        }
    }
    func dismiss(_ scope: TFYSwiftNavigationScopeID) {
        run { [self] in try await assembly.router.dismiss(scope: scope) }
    }
    func logout() {
        run { [self] in
            state.account = nil
            try await assembly.router.backToRoot(scope: TFYDemoTab.profile.scope)
            select(.home)
        }
    }
    func login() {
        let scope = activeScope
        run { [self] in try await authenticate(scope: scope) }
    }
    private func authenticate(scope: TFYSwiftNavigationScopeID) async throws {
        tabBarController.floatingBar.isHidden = true
        do {
            let account = try await assembly.router.openTyped(
                TFYDemoLoginRoute(), input: "登录后可发布影评、开通会员",
                presentation: .sheet(.init(detents: [.large], allowsInteractiveDismiss: false)), scope: scope)
            try await assembly.router.dismiss(scope: scope)
            state.account = account
        } catch {
            try? await assembly.router.dismiss(scope: scope)
            throw error
        }
    }
    func compose() {
        let scope = activeScope
        run { [self] in
            tabBarController.floatingBar.isHidden = true
            do {
                let post = try await assembly.router.openTyped(
                    TFYDemoPublishRoute(), input: state.draft, presentation: .fullScreen(), scope: scope)
                let account = state.accountKey
                try await assembly.router.dismiss(scope: scope)
                state.posts[account, default: []].insert(post, at: 0)
                state.draft = ""
                select(.profile)
            } catch {
                try? await assembly.router.dismiss(scope: scope)
                throw error
            }
        }
    }
    func buy(_ plan: TFYDemoMembershipPlan) {
        let scope = activeScope
        run { [self] in
            tabBarController.floatingBar.isHidden = true
            do {
                let order = try await assembly.router.openTyped(
                    TFYDemoBuyRoute(), input: plan,
                    presentation: .sheet(.init(detents: [.large], allowsInteractiveDismiss: false)), scope: scope)
                try await assembly.router.dismiss(scope: scope)
                state.orders.append(order)
                state.memberAccounts.insert(order.account)
                // UIKit 的 appearance 回调发生在 dismiss 完成前，显式更新当前可见业务状态。
                refreshVisiblePage()
            } catch {
                try? await assembly.router.dismiss(scope: scope)
                throw error
            }
        }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        guard operation == nil else { return }
        operation = Task { [weak self] in
            guard let self else { return }
            defer {
                operation = nil
                tabBarController.refreshBar()
            }
            do {
                try await action()
                refreshVisiblePage()
            } catch TFYSwiftRouteError.cancelled {} catch is CancellationError {} catch {
                let page =
                    (tabBarController.selectedViewController as? UINavigationController)?.visibleViewController
                    as? TFYDemoViewController
                page?.showMessage("操作未完成", message: error.localizedDescription)
            }
        }
    }
    private func refreshVisiblePage() {
        let page = (tabBarController.selectedViewController as? UINavigationController)?.visibleViewController
        (page as? TFYDemoStateRefreshing)?.refreshState()
    }
    func handleExternalURL(_ url: URL) async throws {
        let route = try await links.route(for: .init(url: url))
        guard let videoRoute = route.cast(to: TFYDemoHomeRoute.self) else {
            throw TFYSwiftRouteError.invalidDeepLink("不支持的地址")
        }
        try await assembly.router.open(
            videoRoute, presentation: .push(), source: .deepLink, scope: TFYDemoTab.home.scope,
            deduplication: .singleTop)
    }
}

protocol TFYDemoStateRefreshing: AnyObject { @MainActor func refreshState() }

struct TFYDemoVideoLinkParser: TFYSwiftDeepLinkParser {
    let identifier = "video.detail"
    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
        guard request.url.host == "video" else { return nil }
        let parts = request.url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1, TFYDemoVideo.samples.contains(where: { $0.id == parts[0] }) else {
            throw TFYSwiftRouteError.invalidDeepLink("视频不存在")
        }
        return .init(TFYDemoHomeRoute.detail(parts[0]))
    }
}

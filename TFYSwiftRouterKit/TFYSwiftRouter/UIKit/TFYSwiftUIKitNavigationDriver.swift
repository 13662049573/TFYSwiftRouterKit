// TFYSwiftUIKitNavigationDriver.swift
// UIKit 导航适配。弱持有 UINavigationController，追踪地址与控制器关系并清理移除页面的交互。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if canImport(UIKit)
import UIKit
import ObjectiveC.runtime
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
/// 把平台无关的导航请求映射到 UINavigationController 与模态呈现。
public final class TFYSwiftUIKitNavigationDriver: NSObject, TFYSwiftNavigationDriver, TFYSwiftNavigationCheckpointing {
    public typealias CustomPresentation = @MainActor (
        _ source: UIViewController,
        _ destination: UIViewController,
        _ transaction: TFYSwiftRouteTransaction
    ) async throws -> Void

    private weak var navigationController: UINavigationController?
    private let destinations: TFYSwiftUIKitDestinationRegistry
    private final class TrackedController {
        weak var controller: UIViewController?
        let route: TFYSwiftAnyRoute
        var isNavigationStackEntry = false

        init(controller: UIViewController, route: TFYSwiftAnyRoute) {
            self.controller = controller
            self.route = route
        }
    }

    private var trackedControllers: [TrackedController] = []
    private var customPresentations: [String: CustomPresentation] = [:]
    private var newWindowPresentation: CustomPresentation?
    private let navigationDelegateObserver = TFYSwiftNavigationDelegateObserver()
    private struct CheckpointState {
        let id: UUID
        let viewControllers: [UIViewController]
    }
    private final class Checkpoint: TFYSwiftNavigationCheckpoint {
        private weak var driver: TFYSwiftUIKitNavigationDriver?
        private let id: UUID
        private var isResolved = false

        init(driver: TFYSwiftUIKitNavigationDriver, id: UUID) {
            self.driver = driver
            self.id = id
        }

        func commit() {
            guard !isResolved else { return }
            isResolved = true
            driver?.resolveCheckpoint(id: id, commit: true)
        }

        func rollback() {
            guard !isResolved else { return }
            isResolved = true
            driver?.resolveCheckpoint(id: id, commit: false)
        }
    }
    private var checkpointState: CheckpointState?

    /// 注入导航容器与页面工厂表；便利初始化器创建空表，容器由 App 强持有。
    public init(
        navigationController: UINavigationController,
        destinations: TFYSwiftUIKitDestinationRegistry
    ) {
        self.navigationController = navigationController
        self.destinations = destinations
        super.init()
        navigationDelegateObserver.onDidShow = { [weak self] navigationController in
            self?.navigationControllerDidShow(navigationController)
        }
        installNavigationDelegateObserver()
    }

    /// 注入导航容器与页面工厂表；便利初始化器创建空表，容器由 App 强持有。
    public convenience init(navigationController: UINavigationController) {
        self.init(
            navigationController: navigationController,
            destinations: TFYSwiftUIKitDestinationRegistry()
        )
    }

    /// 安装指定标识的自定义呈现处理器；处理器负责实际展示及生命周期管理。
    public func registerCustomPresentation(identifier: String, handler: @escaping CustomPresentation) {
        customPresentations[identifier] = handler
    }

    /// Scene owners can provide app-specific UIWindowScene activation and dependency wiring.
    /// 安装由 App 提供的新窗口/Scene 处理器；核心不会自动创建 Scene。
    public func registerNewWindowPresentation(handler: @escaping CustomPresentation) {
        newWindowPresentation = handler
    }

    /// 由具体平台驱动创建并展示目标页面，工厂或呈现失败通过 throws 回传。
    public func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        guard let navigationController else {
            throw TFYSwiftRouteError.scopeUnavailable(transaction.context.scope.rawValue)
        }
        installNavigationDelegateObserver()
        if checkpointState != nil {
            guard navigationController.presentedViewController == nil else {
                throw TFYSwiftRouteError.restorationFailed("恢复期间出现了新的模态页面")
            }
            switch transaction.presentation {
            case .automatic, .push, .replace, .root: break
            default:
                throw TFYSwiftRouteError.restorationFailed("恢复检查点只支持 root/push 导航")
            }
        }

        let context = TFYSwiftDestinationContext(
            routeContext: transaction.context,
            presentation: transaction.presentation,
            interaction: interaction
        )
        let viewController = try destinations.makeViewController(
            identifier: destination.identifier,
            route: route,
            context: context
        )
        let trackedController = track(viewController, route: route)
        if let interaction {
            objc_setAssociatedObject(
                viewController,
                &TFYSwiftResultLifecycleAssociation.key,
                TFYSwiftResultLifecycleToken(interaction: interaction),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        switch transaction.presentation {
        case .automatic:
            trackedController.isNavigationStackEntry = true
            navigationController.pushViewController(viewController, animated: true)
            await navigationController.awaitTransitionCompletion()
        case .push(let animated):
            trackedController.isNavigationStackEntry = true
            navigationController.pushViewController(viewController, animated: animated)
            await navigationController.awaitTransitionCompletion()
        case .sheet(let configuration):
            configureSheet(viewController, configuration: configuration)
            try await topViewController(from: navigationController).presentSafely(viewController, animated: true)
            observeModalDismissal(of: viewController, interaction: interaction)
        case .fullScreen(let animated):
            viewController.modalPresentationStyle = .fullScreen
            try await topViewController(from: navigationController).presentSafely(viewController, animated: animated)
            observeModalDismissal(of: viewController, interaction: interaction)
        case .replace(let animated):
            trackedController.isNavigationStackEntry = true
            var stack = navigationController.viewControllers
            let replacedController = stack.last
            if stack.isEmpty {
                stack = [viewController]
            } else {
                stack[stack.count - 1] = viewController
            }
            navigationController.setViewControllers(stack, animated: animated)
            await navigationController.awaitTransitionCompletion()
            if checkpointState == nil, let replacedController {
                cancelInteraction(of: replacedController)
            }
        case .root(let animated):
            trackedController.isNavigationStackEntry = true
            let presentedControllers = presentedHierarchy(from: navigationController)
            // 只关闭此 Scope 展示的子弹层，不能把作为模态容器的导航控制器自身关闭。
            if navigationController.presentedViewController != nil {
                await navigationController.dismissAwaitingCompletion(animated: false)
            }
            let previousControllers = navigationController.viewControllers
            navigationController.setViewControllers([viewController], animated: animated)
            await navigationController.awaitTransitionCompletion()
            presentedControllers.forEach(cancelInteraction(of:))
            if checkpointState == nil {
                previousControllers.forEach(cancelInteraction(of:))
            }
        case .newWindow:
            guard let newWindowPresentation else { throw TFYSwiftRouteError.sceneUnavailable }
            try await newWindowPresentation(topViewController(from: navigationController), viewController, transaction)
        case .custom(let identifier):
            guard let handler = customPresentations[identifier] else {
                throw TFYSwiftRouteError.presentationFailed("自定义转场未注册：\(identifier)")
            }
            try await handler(topViewController(from: navigationController), viewController, transaction)
        }
    }

    /// 判断给定地址是否为当前 Scope 的可见顶层页面。
    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        guard let navigationController else { return false }
        pruneTrackedControllers()
        return self.route(for: topViewController(from: navigationController)) == route
    }

    /// 尝试激活已有地址；命中时返回 true，并按驱动语义移除其上的页面。
    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        guard let navigationController else { return false }
        pruneTrackedControllers()
        if self.route(for: topViewController(from: navigationController)) == route { return true }
        guard let target = navigationController.viewControllers.last(where: {
            self.route(for: $0) == route
        }) else { return false }
        let presentedControllers = presentedHierarchy(from: navigationController)
        if navigationController.presentedViewController != nil {
            await navigationController.dismissAwaitingCompletion(animated: false)
        }
        let removed = Array(navigationController.viewControllers.drop {
            $0 !== target
        }.dropFirst())
        navigationController.popToViewController(target, animated: true)
        await navigationController.awaitTransitionCompletion()
        presentedControllers.forEach(cancelInteraction(of:))
        removed.forEach(cancelInteraction(of:))
        return true
    }

    /// 返回当前驱动追踪的地址，包含受支持的模态页面。
    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        guard let navigationController else { return [] }
        pruneTrackedControllers()
        var result = navigationController.viewControllers.compactMap { route(for: $0) }
        result.append(contentsOf: presentedHierarchy(from: navigationController).compactMap { route(for: $0) })
        return result
    }

    /// 返回可用于恢复的 root/push 地址顺序；内置驱动排除模态和自定义呈现。
    public func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        guard let navigationController else { return [] }
        pruneTrackedControllers()
        return navigationController.viewControllers.compactMap { route(for: $0) }
    }

    /// 保存当前导航控制器中的页面实例；存在子模态页面时拒绝开始恢复。
    public func makeNavigationCheckpoint(
        in scope: TFYSwiftNavigationScopeID
    ) throws -> any TFYSwiftNavigationCheckpoint {
        guard checkpointState == nil else {
            throw TFYSwiftRouteError.restorationFailed("UIKit 导航已有未完成的恢复事务")
        }
        guard let navigationController else {
            throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue)
        }
        guard navigationController.presentedViewController == nil else {
            throw TFYSwiftRouteError.restorationFailed("恢复前请先关闭当前 Scope 的模态页面")
        }
        let id = UUID()
        checkpointState = CheckpointState(
            id: id,
            viewControllers: navigationController.viewControllers
        )
        return Checkpoint(driver: self, id: id)
    }

    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        let stack = navigationController.viewControllers
        guard stack.count > 1 else { throw TFYSwiftRouteError.presentationFailed("已位于根页面") }
        let index = max(0, stack.count - 1 - max(1, count))
        let removed = Array(stack.suffix(from: index + 1))
        navigationController.popToViewController(stack[index], animated: true)
        await navigationController.awaitTransitionCompletion()
        removed.forEach(cancelInteraction(of:))
    }

    /// 清理当前导航栈的根页之后的页面及其交互。
    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        let removed = Array(navigationController.viewControllers.dropFirst())
        navigationController.popToRootViewController(animated: true)
        await navigationController.awaitTransitionCompletion()
        removed.forEach(cancelInteraction(of:))
    }

    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        let source = topViewController(from: navigationController)
        guard source.presentingViewController != nil || navigationController.presentedViewController != nil else {
            throw TFYSwiftRouteError.presentationFailed("没有可关闭的模态页面")
        }
        await source.dismissAwaitingCompletion(animated: true)
        cancelInteraction(of: source)
    }

    /// 关闭当前 Scope 的全部模态页面及其交互。
    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        let presentedControllers = presentedHierarchy(from: navigationController)
        guard !presentedControllers.isEmpty else { return }
        await navigationController.dismissAwaitingCompletion(animated: true)
        presentedControllers.forEach(cancelInteraction(of:))
    }

    private func configureSheet(_ viewController: UIViewController, configuration: TFYSwiftSheetConfiguration) {
        viewController.modalPresentationStyle = .pageSheet
        viewController.isModalInPresentation = !configuration.allowsInteractiveDismiss
        guard let sheet = viewController.sheetPresentationController else { return }
        sheet.prefersGrabberVisible = configuration.prefersGrabberVisible
        sheet.detents = configuration.detents.map { detent in
            switch detent {
            case .medium: .medium()
            case .large: .large()
            }
        }
    }

    private func observeModalDismissal(of viewController: UIViewController, interaction: TFYSwiftRouteInteraction?) {
        guard let interaction else { return }
        let lifecycleObserver = TFYSwiftModalDismissObserverViewController(owner: viewController) {
            interaction.cancel()
        }
        let lifecycleHost = (viewController as? UINavigationController)?.visibleViewController ?? viewController
        lifecycleHost.addChild(lifecycleObserver)
        lifecycleHost.view.addSubview(lifecycleObserver.view)
        lifecycleObserver.didMove(toParent: lifecycleHost)

        guard let presentationController = viewController.presentationController else { return }
        let observer = TFYSwiftPresentationDismissObserver {
            interaction.cancel()
        }
        observer.forwardingDelegate = presentationController.delegate
        objc_setAssociatedObject(
            viewController,
            &TFYSwiftResultLifecycleAssociation.dismissObserverKey,
            observer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        presentationController.delegate = observer
    }

    private func installNavigationDelegateObserver() {
        guard let navigationController,
              navigationController.delegate !== navigationDelegateObserver else { return }
        navigationDelegateObserver.forwardingDelegate = navigationController.delegate
        navigationController.delegate = navigationDelegateObserver
    }

    private func navigationControllerDidShow(_ navigationController: UINavigationController) {
        if checkpointState != nil {
            pruneTrackedControllers()
            return
        }
        let controllers = Set(navigationController.viewControllers.map(ObjectIdentifier.init))
        trackedControllers.removeAll { trackedController in
            guard let controller = trackedController.controller else { return true }
            guard trackedController.isNavigationStackEntry,
                  !controllers.contains(ObjectIdentifier(controller)) else { return false }
            cancelInteraction(of: controller)
            return true
        }
    }

    @discardableResult
    private func track(_ controller: UIViewController, route: TFYSwiftAnyRoute) -> TrackedController {
        pruneTrackedControllers()
        trackedControllers.removeAll { $0.controller === controller }
        let trackedController = TrackedController(controller: controller, route: route)
        trackedControllers.append(trackedController)
        return trackedController
    }

    private func route(for controller: UIViewController) -> TFYSwiftAnyRoute? {
        var candidate: UIViewController? = controller
        while let current = candidate {
            if let route = trackedControllers.last(where: { $0.controller === current })?.route {
                return route
            }
            candidate = current.parent
        }
        return nil
    }

    private func pruneTrackedControllers() {
        trackedControllers.removeAll { $0.controller == nil }
    }

    private func presentedHierarchy(from root: UIViewController) -> [UIViewController] {
        var result: [UIViewController] = []
        var current = root.presentedViewController
        while let controller = current {
            result.append(controller)
            current = controller.presentedViewController
        }
        return result
    }

    private func cancelPresentedHierarchy(from root: UIViewController) {
        presentedHierarchy(from: root).forEach(cancelInteraction(of:))
    }

    private func cancelInteraction(of controller: UIViewController) {
        var candidate: UIViewController? = controller
        while let current = candidate {
            if let token = objc_getAssociatedObject(
                current,
                &TFYSwiftResultLifecycleAssociation.key
            ) as? TFYSwiftResultLifecycleToken {
                token.cancel()
                return
            }
            candidate = current.parent
        }
    }

    private func resolveCheckpoint(id: UUID, commit: Bool) {
        guard let checkpoint = checkpointState, checkpoint.id == id,
              let navigationController else { return }
        let previousIDs = Set(checkpoint.viewControllers.map(ObjectIdentifier.init))
        let currentControllers = navigationController.viewControllers
        let currentIDs = Set(currentControllers.map(ObjectIdentifier.init))
        if commit {
            checkpoint.viewControllers
                .filter { !currentIDs.contains(ObjectIdentifier($0)) }
                .forEach(cancelInteraction(of:))
        } else {
            currentControllers
                .filter { !previousIDs.contains(ObjectIdentifier($0)) }
                .forEach(cancelInteraction(of:))
            navigationController.setViewControllers(checkpoint.viewControllers, animated: false)
        }
        checkpointState = nil
        navigationControllerDidShow(navigationController)
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
}

private enum TFYSwiftResultLifecycleAssociation {
    nonisolated(unsafe) static var key: UInt8 = 0
    nonisolated(unsafe) static var dismissObserverKey: UInt8 = 0
}

@MainActor
private final class TFYSwiftModalDismissObserverViewController: UIViewController {
    private weak var owner: UIViewController?
    private var onDismiss: (() -> Void)?

    init(owner: UIViewController, onDismiss: @escaping () -> Void) {
        self.owner = owner
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isAccessibilityElement = false
        self.view = view
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let owner else { return }
        let wasDismissed = owner.isBeingDismissed
            || owner.navigationController?.isBeingDismissed == true
            || (owner.presentingViewController == nil
                && owner.navigationController?.presentingViewController == nil)
        guard wasDismissed else { return }
        let operation = onDismiss
        onDismiss = nil
        operation?()
    }
}

private final class TFYSwiftResultLifecycleToken: NSObject {
    private let interaction: TFYSwiftRouteInteraction

    @MainActor
    init(interaction: TFYSwiftRouteInteraction) { self.interaction = interaction }

    @MainActor
    /// 取消结果等待并按当前对象职责关闭交互资源；不等同于自动关闭 UI。
    func cancel() { interaction.cancel() }

    deinit {
        let interaction = interaction
        Task { @MainActor in interaction.cancel() }
    }
}

@MainActor
private final class TFYSwiftPresentationDismissObserver: NSObject, UIAdaptivePresentationControllerDelegate {
    nonisolated(unsafe) weak var forwardingDelegate: UIAdaptivePresentationControllerDelegate?
    private let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
        forwardingDelegate?.presentationControllerDidDismiss?(presentationController)
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || forwardingDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        guard forwardingDelegate?.responds(to: selector) == true else {
            return super.forwardingTarget(for: selector)
        }
        return forwardingDelegate
    }
}

private final class TFYSwiftNavigationDelegateObserver: NSObject, UINavigationControllerDelegate {
    nonisolated(unsafe) weak var forwardingDelegate: UINavigationControllerDelegate?
    var onDidShow: (@MainActor (UINavigationController) -> Void)?

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        forwardingDelegate?.navigationController?(
            navigationController,
            willShow: viewController,
            animated: animated
        )
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        onDidShow?(navigationController)
        forwardingDelegate?.navigationController?(
            navigationController,
            didShow: viewController,
            animated: animated
        )
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || forwardingDelegate?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        guard forwardingDelegate?.responds(to: selector) == true else {
            return super.forwardingTarget(for: selector)
        }
        return forwardingDelegate
    }
}

@MainActor
private extension UIViewController {
    func presentSafely(_ viewController: UIViewController, animated: Bool) async throws {
        guard presentedViewController == nil else {
            throw TFYSwiftRouteError.presentationFailed("当前页面正在展示其他模态页面")
        }
        await withCheckedContinuation { continuation in
            present(viewController, animated: animated) {
                continuation.resume()
            }
        }
    }

    func dismissAwaitingCompletion(animated: Bool) async {
        await withCheckedContinuation { continuation in
            dismiss(animated: animated) {
                continuation.resume()
            }
        }
    }
}

@MainActor
private extension UINavigationController {
    func awaitTransitionCompletion() async {
        guard let coordinator = transitionCoordinator else { return }
        await withCheckedContinuation { continuation in
            let queued = coordinator.animate(alongsideTransition: nil) { _ in
                continuation.resume()
            }
            if !queued {
                continuation.resume()
            }
        }
    }
}
#endif

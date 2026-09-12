import UIKit
import ObjectiveC.runtime
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
public final class TFYSwiftUIKitNavigationDriver: NSObject, TFYSwiftNavigationDriver {
    public typealias CustomPresentation = @MainActor (
        _ source: UIViewController,
        _ destination: UIViewController,
        _ transaction: TFYSwiftRouteTransaction
    ) async throws -> Void

    private weak var navigationController: UINavigationController?
    private let destinations: TFYSwiftUIKitDestinationRegistry
    private var routesByController: [ObjectIdentifier: TFYSwiftAnyRoute] = [:]
    private var customPresentations: [String: CustomPresentation] = [:]
    private var dismissalObservers: [ObjectIdentifier: TFYSwiftPresentationDismissObserver] = [:]
    private var newWindowPresentation: CustomPresentation?

    public init(
        navigationController: UINavigationController,
        destinations: TFYSwiftUIKitDestinationRegistry
    ) {
        self.navigationController = navigationController
        self.destinations = destinations
        super.init()
    }

    public convenience init(navigationController: UINavigationController) {
        self.init(
            navigationController: navigationController,
            destinations: TFYSwiftUIKitDestinationRegistry()
        )
    }

    public func registerCustomPresentation(identifier: String, handler: @escaping CustomPresentation) {
        customPresentations[identifier] = handler
    }

    /// Scene owners can provide app-specific UIWindowScene activation and dependency wiring.
    public func registerNewWindowPresentation(handler: @escaping CustomPresentation) {
        newWindowPresentation = handler
    }

    public func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        guard let navigationController else {
            throw TFYSwiftRouteError.scopeUnavailable(transaction.context.scope.rawValue)
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
        routesByController[ObjectIdentifier(viewController)] = route
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
            navigationController.pushViewController(viewController, animated: true)
        case .push(let animated):
            navigationController.pushViewController(viewController, animated: animated)
        case .sheet(let configuration):
            configureSheet(viewController, configuration: configuration)
            try topViewController(from: navigationController).presentSafely(viewController, animated: true)
            observeInteractiveDismiss(of: viewController, interaction: interaction)
        case .fullScreen(let animated):
            viewController.modalPresentationStyle = .fullScreen
            try topViewController(from: navigationController).presentSafely(viewController, animated: animated)
        case .replace(let animated):
            var stack = navigationController.viewControllers
            if stack.isEmpty { stack = [viewController] } else { stack[stack.count - 1] = viewController }
            navigationController.setViewControllers(stack, animated: animated)
        case .root(let animated):
            navigationController.setViewControllers([viewController], animated: animated)
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

    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        guard let top = navigationController?.topViewController else { return false }
        return routesByController[ObjectIdentifier(top)] == route
    }

    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        guard let navigationController,
              let target = navigationController.viewControllers.last(where: {
                  routesByController[ObjectIdentifier($0)] == route
              }) else { return false }
        navigationController.popToViewController(target, animated: true)
        return true
    }

    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        navigationController?.viewControllers.compactMap { routesByController[ObjectIdentifier($0)] } ?? []
    }

    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        let stack = navigationController.viewControllers
        guard stack.count > 1 else { throw TFYSwiftRouteError.presentationFailed("已位于根页面") }
        let index = max(0, stack.count - 1 - max(1, count))
        navigationController.popToViewController(stack[index], animated: true)
    }

    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        navigationController.popToRootViewController(animated: true)
    }

    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        let source = topViewController(from: navigationController)
        guard source.presentingViewController != nil || navigationController.presentedViewController != nil else {
            throw TFYSwiftRouteError.presentationFailed("没有可关闭的模态页面")
        }
        source.dismiss(animated: true)
    }

    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        guard let navigationController else { throw TFYSwiftRouteError.scopeUnavailable(scope.rawValue) }
        navigationController.dismiss(animated: true)
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

    private func observeInteractiveDismiss(of viewController: UIViewController, interaction: TFYSwiftRouteInteraction?) {
        guard let interaction, let presentationController = viewController.presentationController else { return }
        let identifier = ObjectIdentifier(viewController)
        let observer = TFYSwiftPresentationDismissObserver { [weak self] in
            interaction.cancel()
            self?.dismissalObservers.removeValue(forKey: identifier)
        }
        dismissalObservers[identifier] = observer
        presentationController.delegate = observer
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
}

private final class TFYSwiftResultLifecycleToken: NSObject {
    private let interaction: TFYSwiftRouteInteraction

    @MainActor
    init(interaction: TFYSwiftRouteInteraction) { self.interaction = interaction }

    deinit {
        let interaction = interaction
        Task { @MainActor in interaction.cancel() }
    }
}

@MainActor
private final class TFYSwiftPresentationDismissObserver: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { onDismiss() }
}

@MainActor
private extension UIViewController {
    func presentSafely(_ viewController: UIViewController, animated: Bool) throws {
        guard presentedViewController == nil else {
            throw TFYSwiftRouteError.presentationFailed("当前页面正在展示其他模态页面")
        }
        present(viewController, animated: animated)
    }
}

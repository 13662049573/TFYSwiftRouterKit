import UIKit
import XCTest
@testable import TFYSwiftRouterKit

@MainActor
final class TFYSwiftRouterUIKitLifecycleTests: XCTestCase {
    private enum TestRoute: Hashable, Sendable, TFYSwiftRoute {
        case detail
    }

    private enum RestorableRoute: String, Codable, TFYSwiftRoute {
        case original
        case restoredRoot
        case failing
    }

    private final class NavigationDelegateSpy: NSObject, UINavigationControllerDelegate {
        var willShowCount = 0
        var didShowCount = 0

        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            willShowCount += 1
        }

        func navigationController(
            _ navigationController: UINavigationController,
            didShow viewController: UIViewController,
            animated: Bool
        ) {
            didShowCount += 1
        }
    }

    private final class AdaptivePresentationDelegateSpy: NSObject, UIAdaptivePresentationControllerDelegate {
        var shouldDismissCount = 0
        var didDismissCount = 0

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            shouldDismissCount += 1
            return false
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            didDismissCount += 1
        }
    }

    private final class PresentationHostViewController: UIViewController {
        var adaptiveDelegate: UIAdaptivePresentationControllerDelegate?

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            viewControllerToPresent.presentationController?.delegate = adaptiveDelegate
            completion?()
        }
    }

    private final class DeferredPresentationHostViewController: UIViewController {
        var presentationCompletion: (() -> Void)?

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            presentationCompletion = completion
        }
    }

    private final class PresentedViewController: UIViewController {
        private lazy var controller = UIPresentationController(
            presentedViewController: self,
            presenting: nil
        )

        override var presentationController: UIPresentationController? { controller }
    }

    func testExternalPopCancelsInteractionWhenControllerIsRetained() async throws {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let registry = TFYSwiftUIKitDestinationRegistry()
        var retainedController: UIViewController?
        try registry.register(identifier: "detail", routeType: TestRoute.self) { _, _ in
            let controller = UIViewController()
            retainedController = controller
            return controller
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: registry
        )
        var cancellationCount = 0
        let interaction = makeInteraction { cancellationCount += 1 }

        try await presentDetail(using: driver, interaction: interaction)
        XCTAssertNotNil(retainedController)

        navigationController.popViewController(animated: false)
        navigationController.delegate?.navigationController?(
            navigationController,
            didShow: root,
            animated: false
        )

        XCTAssertEqual(cancellationCount, 1)
        withExtendedLifetime(retainedController) {}
    }

    func testDidShowDoesNotCancelWhileControllerRemainsInStackAndForwardsDelegate() async throws {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let delegate = NavigationDelegateSpy()
        navigationController.delegate = delegate
        let registry = TFYSwiftUIKitDestinationRegistry()
        try registry.register(identifier: "detail", routeType: TestRoute.self) { _, _ in
            UIViewController()
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: registry
        )
        var cancellationCount = 0
        let interaction = makeInteraction { cancellationCount += 1 }

        try await presentDetail(using: driver, interaction: interaction)
        let detail = try XCTUnwrap(navigationController.topViewController)
        let forwardedWillShowCountBeforeCallback = delegate.willShowCount
        let forwardedCountBeforeCallback = delegate.didShowCount

        navigationController.delegate?.navigationController?(
            navigationController,
            willShow: detail,
            animated: true
        )
        navigationController.delegate?.navigationController?(
            navigationController,
            didShow: detail,
            animated: true
        )

        XCTAssertEqual(cancellationCount, 0)
        XCTAssertEqual(delegate.willShowCount, forwardedWillShowCountBeforeCallback + 1)
        XCTAssertEqual(delegate.didShowCount, forwardedCountBeforeCallback + 1)
    }

    func testInteractiveDismissCancelsInteractionAndForwardsExistingDelegate() async throws {
        let root = PresentationHostViewController()
        let delegate = AdaptivePresentationDelegateSpy()
        root.adaptiveDelegate = delegate
        let navigationController = UINavigationController(rootViewController: root)

        let registry = TFYSwiftUIKitDestinationRegistry()
        var presentedController: UIViewController?
        try registry.register(identifier: "detail", routeType: TestRoute.self) { _, _ in
            let controller = PresentedViewController()
            presentedController = controller
            return controller
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: registry
        )
        var cancellationCount = 0
        let interaction = makeInteraction { cancellationCount += 1 }

        try await presentDetail(
            using: driver,
            interaction: interaction,
            presentation: .sheet()
        )
        let presentationController = try XCTUnwrap(presentedController?.presentationController)
        let installedDelegate = try XCTUnwrap(presentationController.delegate)

        XCTAssertFalse(installedDelegate.presentationControllerShouldDismiss?(presentationController) ?? true)
        installedDelegate.presentationControllerDidDismiss?(presentationController)

        XCTAssertEqual(delegate.shouldDismissCount, 1)
        XCTAssertEqual(delegate.didDismissCount, 1)
        XCTAssertEqual(cancellationCount, 1)
    }

    func testPresentReturnsOnlyAfterUIKitPresentationCompletes() async throws {
        let root = DeferredPresentationHostViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let registry = TFYSwiftUIKitDestinationRegistry()
        try registry.register(identifier: "detail", routeType: TestRoute.self) { _, _ in
            UIViewController()
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: registry
        )
        var didReturn = false

        let presentation = Task { @MainActor in
            try await presentDetail(
                using: driver,
                interaction: makeInteraction {},
                presentation: .sheet()
            )
            didReturn = true
        }
        for _ in 0..<10 where root.presentationCompletion == nil {
            await Task.yield()
        }

        XCTAssertNotNil(root.presentationCompletion)
        XCTAssertFalse(didReturn)
        root.presentationCompletion?()
        try await presentation.value
        XCTAssertTrue(didReturn)
    }

    func testModalNavigationControllerKeepsOnlyItsNavigationStackChildren() async throws {
        let root = PresentationHostViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let registry = TFYSwiftUIKitDestinationRegistry()
        let modalRoot = UITableViewController(style: .insetGrouped)
        let modalNavigationController = UINavigationController(rootViewController: modalRoot)
        try registry.register(identifier: "detail", routeType: TestRoute.self) { _, _ in
            modalNavigationController
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: registry
        )

        try await presentDetail(
            using: driver,
            interaction: makeInteraction {},
            presentation: .sheet()
        )

        XCTAssertEqual(modalNavigationController.children.count, 1)
        XCTAssertTrue(modalNavigationController.children.first === modalRoot)
    }

    func testFullScreenExternalDismissCancelsInteractionWhileControllerIsRetained() async throws {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(50))
        let registry = TFYSwiftUIKitDestinationRegistry()
        var retainedController: UIViewController?
        try registry.register(identifier: "detail", routeType: TestRoute.self) { _, _ in
            let controller = UIViewController()
            retainedController = controller
            return controller
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: registry
        )
        var cancellationCount = 0
        let interaction = makeInteraction { cancellationCount += 1 }

        try await presentDetail(
            using: driver,
            interaction: interaction,
            presentation: .fullScreen(animated: false)
        )
        let controller = try XCTUnwrap(retainedController)
        XCTAssertTrue(navigationController.presentedViewController === controller)
        controller.dismiss(animated: false)
        for _ in 0..<20 where cancellationCount == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(cancellationCount, 1)
        withExtendedLifetime(retainedController) {}
    }

    func testRestorationFailureRestoresExactControllerWithoutCancellingInteraction() async throws {
        let navigationController = UINavigationController()
        let destinations = TFYSwiftUIKitDestinationRegistry()
        try destinations.register(identifier: "restorable", routeType: RestorableRoute.self) { route, _ in
            if route == .failing {
                throw TFYSwiftRouteError.presentationFailed("injected failure")
            }
            return UIViewController()
        }
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: destinations
        )
        var cancellationCount = 0
        let interaction = makeInteraction { cancellationCount += 1 }
        let originalRoute = TFYSwiftAnyRoute(RestorableRoute.original)
        try await driver.present(
            destination: TFYSwiftDestinationDescriptor(identifier: "restorable"),
            route: originalRoute,
            transaction: TFYSwiftRouteTransaction(
                route: originalRoute,
                context: TFYSwiftRouteContext(),
                presentation: .root(animated: false),
                deduplication: .none
            ),
            interaction: interaction
        )
        let originalController = try XCTUnwrap(navigationController.topViewController)

        let routes = TFYSwiftRouteRegistry()
        try routes.register(RestorableRoute.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "restorable")
        }
        let router = TFYSwiftRouter(
            registry: routes,
            interceptors: TFYSwiftInterceptorPipeline(),
            events: TFYSwiftRouteEventCenter(),
            driver: driver
        )
        let restoration = TFYSwiftRestorationRegistry()
        try restoration.register(RestorableRoute.self, identifier: "restorable.v1")
        let root = try XCTUnwrap(
            restoration.descriptor(for: TFYSwiftAnyRoute(RestorableRoute.restoredRoot))
        )
        let failing = try XCTUnwrap(
            restoration.descriptor(for: TFYSwiftAnyRoute(RestorableRoute.failing))
        )
        let coordinator = TFYSwiftRestorationCoordinator(registry: restoration, router: router)

        do {
            try await coordinator.restore(
                TFYSwiftNavigationSnapshot(scopes: [
                    TFYSwiftNavigationScopeSnapshot(scope: .main, routes: [root, failing])
                ])
            )
            XCTFail("Expected restoration failure")
        } catch {}

        XCTAssertTrue(navigationController.topViewController === originalController)
        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertEqual(cancellationCount, 0)
    }

    private func makeInteraction(onCancel: @escaping () -> Void) -> TFYSwiftRouteInteraction {
        let result = TFYSwiftRouteResult(
            transactionID: UUID(),
            finish: { _ in },
            cancel: { _ in onCancel() }
        )
        return TFYSwiftRouteInteraction(result: result)
    }

    private func presentDetail(
        using driver: TFYSwiftUIKitNavigationDriver,
        interaction: TFYSwiftRouteInteraction,
        presentation: TFYSwiftRoutePresentation = .push(animated: false)
    ) async throws {
        let route = TFYSwiftAnyRoute(TestRoute.detail)
        let transaction = TFYSwiftRouteTransaction(
            route: route,
            context: TFYSwiftRouteContext(),
            presentation: presentation,
            deduplication: .none
        )
        try await driver.present(
            destination: TFYSwiftDestinationDescriptor(identifier: "detail"),
            route: route,
            transaction: transaction,
            interaction: interaction
        )
    }
}

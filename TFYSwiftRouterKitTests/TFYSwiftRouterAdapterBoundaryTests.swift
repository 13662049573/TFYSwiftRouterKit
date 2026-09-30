import XCTest
import SwiftUI
@testable import TFYSwiftRouterKit

@MainActor
final class TFYSwiftRouterAdapterBoundaryTests: XCTestCase {
    private struct Route: TFYSwiftRoute { let id: String }

    func testInvalidInitialScopeDoesNotMutateExistingTabsOrDelegates() throws {
        let original = UINavigationController(rootViewController: UIViewController())
        let candidate = UINavigationController(rootViewController: UIViewController())
        let tabBar = UITabBarController()
        tabBar.setViewControllers([original], animated: false)
        let delegate = Delegate()
        candidate.delegate = delegate

        XCTAssertThrowsError(try TFYSwiftRouterAssembly(
            tabBarController: tabBar, tabs: [.init(scope: "home", navigationController: candidate)],
            initialScope: "missing"
        ))
        XCTAssertTrue(tabBar.viewControllers?.first === original)
        XCTAssertTrue(candidate.delegate === delegate)
    }

    func testDuplicateScopeDoesNotMutateExistingTabsOrDelegates() throws {
        let original = UIViewController()
        let first = UINavigationController()
        let second = UINavigationController()
        let tabBar = UITabBarController()
        tabBar.setViewControllers([original], animated: false)
        let delegate = Delegate()
        first.delegate = delegate

        XCTAssertThrowsError(try TFYSwiftRouterAssembly(
            tabBarController: tabBar,
            tabs: [.init(scope: "home", navigationController: first), .init(scope: "home", navigationController: second)],
            initialScope: "home"
        ))
        XCTAssertTrue(tabBar.viewControllers?.first === original)
        XCTAssertTrue(first.delegate === delegate)
    }

    func testDuplicateNavigationControllerIsRejectedBeforeInstallingTabs() {
        let original = UIViewController()
        let shared = UINavigationController()
        let tabBar = UITabBarController()
        tabBar.setViewControllers([original], animated: false)
        XCTAssertThrowsError(try TFYSwiftRouterAssembly(
            tabBarController: tabBar,
            tabs: [.init(scope: "a", navigationController: shared), .init(scope: "b", navigationController: shared)],
            initialScope: "a"
        ))
        XCTAssertTrue(tabBar.viewControllers?.first === original)
    }

    func testSwiftUISingleTaskReusesClosestDuplicateIncludingRoot() async throws {
        let driver = TFYSwiftSwiftUINavigationDriver()
        let router = TFYSwiftRouter(driver: driver)
        try router.registry.register(Route.self) { _, _ in .init(identifier: "route") }
        try driver.destinations.register(identifier: "route", routeType: Route.self) { _, _ in Text("Route") }
        let duplicate = Route(id: "duplicate")
        try await router.open(duplicate, presentation: .root(animated: false))
        try await router.open(Route(id: "middle"), presentation: .push(animated: false))
        try await router.open(duplicate, presentation: .push(animated: false))
        let reusedID = try XCTUnwrap(driver.path.last?.id)
        try await router.open(Route(id: "top"), presentation: .push(animated: false))
        try await router.open(duplicate, deduplication: .singleTask)

        XCTAssertEqual(driver.path.count, 2)
        XCTAssertEqual(driver.path.last?.id, reusedID)
        XCTAssertEqual(driver.rootEntry?.route, TFYSwiftAnyRoute(duplicate))
    }

    func testSwiftUIRestorationRejectsExternalNavigationAndStalePathUpdate() async throws {
        let driver = TFYSwiftSwiftUINavigationDriver()
        let router = TFYSwiftRouter(driver: driver)
        try router.registry.register(Route.self) { _, _ in .init(identifier: "route") }
        try driver.destinations.register(identifier: "route", routeType: Route.self) { _, _ in Text("Route") }
        try await router.open(Route(id: "original"), presentation: .root(animated: false))
        try await router.open(Route(id: "child"), presentation: .push(animated: false))
        let originalRoot = driver.rootEntry?.id
        let originalPath = driver.path.map(\.id)

        try await router.withNavigationRestoration(scopes: [.main]) {
            let checkpoint = try driver.makeNavigationCheckpoint(in: .main)
            defer { checkpoint.rollback() }
            XCTAssertTrue(driver.isRestoringNavigation)
            driver.updatePath([])
            XCTAssertEqual(driver.path.map(\.id), originalPath)
            do { try await driver.back(count: 1, in: .main); XCTFail("Reserved stack must reject back") }
            catch { guard case .restorationFailed = error as? TFYSwiftRouteError else { return XCTFail("Unexpected error: \(error)") } }
            try await router.open(Route(id: "replacement"), presentation: .root(animated: false), source: .restoration)
        }
        XCTAssertEqual(driver.rootEntry?.id, originalRoot)
        XCTAssertEqual(driver.path.map(\.id), originalPath)
        XCTAssertFalse(driver.isRestoringNavigation)
    }

    func testUIKitCheckpointProtectsStackAndRestoresInteractionFlags() async throws {
        let navigation = UINavigationController()
        let assembly = TFYSwiftRouterAssembly(navigationController: navigation)
        try assembly.register(Route.self) { _ in UIViewController() }
        try await assembly.router.open(Route(id: "original"), presentation: .root(animated: false))
        try await assembly.router.open(Route(id: "child"), presentation: .push(animated: false))
        let originals = navigation.viewControllers
        let originalInteraction = navigation.view.isUserInteractionEnabled
        let originalGesture = navigation.interactivePopGestureRecognizer?.isEnabled

        try await assembly.router.withNavigationRestoration(scopes: [.main]) {
            let checkpoint = try assembly.initialNavigationDriver.makeNavigationCheckpoint(in: .main)
            defer { checkpoint.rollback() }
            XCTAssertFalse(navigation.view.isUserInteractionEnabled)
            XCTAssertEqual(navigation.interactivePopGestureRecognizer?.isEnabled, false)
            do { try await assembly.initialNavigationDriver.back(count: 1, in: .main); XCTFail("Reserved stack must reject back") }
            catch { guard case .restorationFailed = error as? TFYSwiftRouteError else { return XCTFail("Unexpected error: \(error)") } }
            try await assembly.router.open(Route(id: "replacement"), presentation: .root(animated: false), source: .restoration)
        }
        XCTAssertEqual(navigation.viewControllers.map(ObjectIdentifier.init), originals.map(ObjectIdentifier.init))
        XCTAssertEqual(navigation.view.isUserInteractionEnabled, originalInteraction)
        XCTAssertEqual(navigation.interactivePopGestureRecognizer?.isEnabled, originalGesture)
    }

    func testTabCheckpointRollbackPreservesNewerUnrelatedSelection() async throws {
        let tabs = UITabBarController()
        let a = UINavigationController()
        let b = UINavigationController()
        let c = UINavigationController()
        let assembly = try TFYSwiftRouterAssembly(
            tabBarController: tabs,
            tabs: [.init(scope: "a", navigationController: a), .init(scope: "b", navigationController: b), .init(scope: "c", navigationController: c)],
            initialScope: "c"
        )
        try assembly.register(Route.self) { _ in UIViewController() }
        try await assembly.router.open(Route(id: "original"), presentation: .root(animated: false), scope: "a")
        try assembly.tabBarDriver?.select("c")
        let original = try XCTUnwrap(a.viewControllers.first)
        let driver = try XCTUnwrap(assembly.tabBarDriver)

        try await assembly.router.withNavigationRestoration(scopes: ["a"]) {
            let checkpoint = try driver.makeNavigationCheckpoint(in: "a")
            defer { checkpoint.rollback() }
            try await assembly.router.open(Route(id: "replacement"), presentation: .root(animated: false), source: .restoration, scope: "a")
            // A separate task has no restoration token and selects an unaffected scope.
            let unrelatedSelection = Task.detached { @MainActor in try driver.select("b") }
            try await unrelatedSelection.value
        }
        XCTAssertEqual(tabs.selectedIndex, 1)
        XCTAssertTrue(a.viewControllers.first === original)
    }

    func testTabCheckpointRollbackRestoresOwnedSelection() async throws {
        let tabs = UITabBarController()
        let a = UINavigationController()
        let b = UINavigationController()
        let assembly = try TFYSwiftRouterAssembly(
            tabBarController: tabs,
            tabs: [.init(scope: "a", navigationController: a), .init(scope: "b", navigationController: b)],
            initialScope: "b"
        )
        try assembly.register(Route.self) { _ in UIViewController() }
        let driver = try XCTUnwrap(assembly.tabBarDriver)
        try await assembly.router.withNavigationRestoration(scopes: ["a", "b"]) {
            let first = try driver.makeNavigationCheckpoint(in: "a")
            let second = try driver.makeNavigationCheckpoint(in: "b")
            try await assembly.router.open(Route(id: "replacement"), presentation: .root(animated: false), source: .restoration, scope: "a")
            second.rollback()
            first.rollback()
        }
        XCTAssertEqual(tabs.selectedIndex, 1)
        XCTAssertTrue(a.viewControllers.isEmpty)
    }

    func testSingleTopSelectsHiddenTabWithoutPushingDuplicate() async throws {
        let tabs = UITabBarController()
        let a = UINavigationController()
        let b = UINavigationController()
        let assembly = try TFYSwiftRouterAssembly(
            tabBarController: tabs,
            tabs: [.init(scope: "a", navigationController: a), .init(scope: "b", navigationController: b)],
            initialScope: "a"
        )
        try assembly.register(Route.self) { _ in UIViewController() }
        let route = Route(id: "existing")
        try await assembly.router.open(route, presentation: .root(animated: false), scope: "b")
        let existing = try XCTUnwrap(b.viewControllers.first)
        for policy in [TFYSwiftRouteDeduplicationPolicy.singleTop, .ignoreIfTop] {
            try assembly.tabBarDriver?.select("a")
            try await assembly.router.open(route, scope: "b", deduplication: policy)
            XCTAssertEqual(tabs.selectedIndex, 1)
            XCTAssertEqual(b.viewControllers.count, 1)
            XCTAssertTrue(b.viewControllers.first === existing)
        }
    }

    private final class Delegate: NSObject, UINavigationControllerDelegate {}
}

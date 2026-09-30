import XCTest

@testable import TFYSwiftRouterKit

@MainActor
final class TFYDemoVideoProjectTests: XCTestCase {
    func testCancelledBackGestureRestoresNavigationAndFloatingBars() {
        let root = UIViewController()
        let detail = UIViewController()
        let navigation = UINavigationController()
        navigation.setViewControllers([root, detail], animated: false)
        let tabs = TFYDemoTabBarController()
        tabs.setViewControllers([navigation], animated: false)
        tabs.loadViewIfNeeded()
        tabs.navigationController(navigation, willShow: root, animated: false)
        XCTAssertTrue(navigation.isNavigationBarHidden)
        // 交互返回取消，UIKit 最终仍显示详情页。
        tabs.navigationController(navigation, didShow: detail, animated: false)
        XCTAssertFalse(navigation.isNavigationBarHidden)
        XCTAssertTrue(tabs.floatingBar.isHidden)
        navigation.setViewControllers([root], animated: false)
        tabs.navigationController(navigation, didShow: root, animated: false)
        XCTAssertTrue(navigation.isNavigationBarHidden)
        XCTAssertFalse(tabs.floatingBar.isHidden)
        XCTAssertTrue(tabs.floatingBar.isUserInteractionEnabled)
    }

    func testAccountCollectionsAndHistoryAreIsolated() {
        let state = TFYDemoAppState()
        state.account = "甲"
        state.toggleCollection("comedy")
        state.recordPlayback("comedy")
        state.recordPlayback("weapon")
        state.recordPlayback("comedy")
        XCTAssertEqual(state.history["甲"], ["comedy", "weapon"])
        state.account = "乙"
        XCTAssertFalse(state.isCollected("comedy"))
        XCTAssertNil(state.history[state.accountKey])
        state.account = "甲"
        XCTAssertTrue(state.isCollected("comedy"))
    }
    func testOrderRetainsOriginalAccount() {
        let state = TFYDemoAppState()
        state.account = "甲"
        let order = TFYDemoMembershipOrder(id: "order", account: state.accountKey, plan: .samples[0])
        state.account = "乙"
        state.orders.append(order)
        state.memberAccounts.insert(order.account)
        XCTAssertFalse(state.isMember)
        state.account = "甲"
        XCTAssertTrue(state.isMember)
        XCTAssertEqual(state.orders.first?.account, "甲")
    }
    func testFreeAndSearchFilters() {
        let state = TFYDemoAppState()
        XCTAssertTrue(TFYDemoFreeModel(state: state).videos(category: 0).allSatisfy { !$0.vip })
        XCTAssertTrue(TFYDemoFreeModel(state: state).videos(category: 1).allSatisfy { $0.category == "电视剧" })
        XCTAssertEqual(TFYDemoHomeModel(state: state).search("重器").map(\.id), ["weapon"])
        XCTAssertTrue(TFYDemoHomeModel(state: state).search("不存在").isEmpty)
    }
    func testPublishRejectsBlankInput() {
        XCTAssertFalse(TFYDemoPublishModel(title: " \n", body: "内容").canPublish)
        XCTAssertFalse(TFYDemoPublishModel(title: "标题", body: "  ").canPublish)
        XCTAssertTrue(TFYDemoPublishModel(title: "标题", body: "内容").canPublish)
    }
    func testLinkOnlyAcceptsKnownVideoIdentifier() async throws {
        let parser = TFYDemoVideoLinkParser()
        let route = try await parser.parse(.init(url: URL(string: "tfyswift://video/comedy")!))
        XCTAssertEqual(route?.cast(to: TFYDemoHomeRoute.self), .detail("comedy"))
        do {
            _ = try await parser.parse(.init(url: URL(string: "tfyswift://video/missing")!))
            XCTFail("Invalid video must be rejected")
        } catch {}
        let unmatched = try await parser.parse(.init(url: URL(string: "tfyswift://other/comedy")!))
        XCTAssertNil(unmatched)
    }
}

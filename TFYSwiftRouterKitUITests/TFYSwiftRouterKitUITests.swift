import XCTest

final class TFYSwiftRouterKitUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testHomeMatchesReferenceAndFiveEntries() {
        let app = launch()
        for tab in ["home", "free", "publish", "member", "profile"] {
            XCTAssertTrue(app.buttons["video.tab.\(tab)"].exists)
        }
        for title in ["喜剧之王单口季第3季", "抓特务", "低智商犯罪", "重器"] { XCTAssertTrue(app.staticTexts[title].exists) }
        XCTAssertTrue(app.buttons["video.search"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "首页"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["video.tab.free"].tap()
        XCTAssertTrue(app.staticTexts["免费专区"].waitForExistence(timeout: 3))
        app.buttons["video.tab.member"].tap()
        XCTAssertTrue(app.buttons["video.plan.19"].waitForExistence(timeout: 3))
        app.buttons["video.tab.profile"].tap()
        XCTAssertTrue(app.buttons["video.profile.login"].waitForExistence(timeout: 3))
        app.buttons["video.tab.home"].tap()
        XCTAssertTrue(app.cells["video.card.comedy"].isHittable)
    }

    @MainActor
    func testSecondaryHidesBarAndBackRestores() {
        let app = launch()
        app.cells["video.card.comedy"].tap()
        XCTAssertTrue(app.navigationBars["内容详情"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["video.tab.home"].isHittable)
        app.navigationBars["内容详情"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["video.tab.home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["video.tab.home"].isHittable)
        app.buttons["video.tab.free"].tap()
        app.cells["video.card.crime"].tap()
        XCTAssertTrue(app.navigationBars["内容详情"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["video.tab.free"].isHittable)
        app.navigationBars["内容详情"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["video.tab.free"].isHittable)
        XCTAssertTrue(app.buttons["video.tab.free"].isSelected)
    }

    @MainActor
    func testSearchAndEmptyResults() {
        let app = launch()
        app.buttons["video.search"].tap()
        let field = app.searchFields["video.search.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("重器")
        XCTAssertTrue(app.cells["video.card.weapon"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.cells["video.card.comedy"].exists)
        field.typeText("不存在")
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "没有找到相关内容")).firstMatch
                .waitForExistence(timeout: 3))
    }

    @MainActor
    func testCollectionAndPlaybackHistory() {
        let app = launch()
        app.buttons["video.collect.comedy"].tap()
        app.buttons["video.tab.profile"].tap()
        app.buttons["video.profile.collections"].tap()
        XCTAssertTrue(app.cells["video.card.comedy"].waitForExistence(timeout: 3))
        app.cells["video.card.comedy"].tap()
        tap("video.episode.3", app)
        XCTAssertTrue(app.buttons["video.player.toggle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["第3集 · 本地播放演示"].exists)
        app.buttons["video.player.toggle"].tap()
        XCTAssertTrue(app.buttons["video.player.toggle"].label.contains("继续播放"))
        app.buttons["video.player.close"].tap()
        XCTAssertTrue(app.navigationBars["内容详情"].waitForExistence(timeout: 3))
        app.navigationBars["内容详情"].buttons.firstMatch.tap()
        app.navigationBars["我的收藏"].buttons.firstMatch.tap()
        tapLabel("观看历史  ›", app)
        XCTAssertTrue(app.cells["video.card.comedy"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLoginResumesMembershipOrder() {
        let app = launch()
        app.buttons["video.tab.member"].tap()
        app.buttons["video.plan.19"].tap()
        XCTAssertTrue(app.buttons["video.login.submit"].waitForExistence(timeout: 3))
        app.buttons["video.login.submit"].tap()
        XCTAssertTrue(app.buttons["video.buy.confirm"].waitForExistence(timeout: 5))
        app.buttons["video.buy.confirm"].tap()
        XCTAssertTrue(app.staticTexts["会员已开通"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["video.tab.member"].isHittable)
    }

    @MainActor
    func testCancelledLoginCanRetryPublish() {
        let app = launch()
        app.buttons["video.tab.publish"].tap()
        XCTAssertTrue(app.navigationBars["登录光影"].waitForExistence(timeout: 3))
        app.navigationBars["登录光影"].buttons["取消"].tap()
        XCTAssertTrue(app.buttons["video.tab.publish"].waitForExistence(timeout: 3))
        app.buttons["video.tab.publish"].tap()
        XCTAssertTrue(app.buttons["video.login.submit"].waitForExistence(timeout: 3))
        app.buttons["video.login.submit"].tap()
        XCTAssertTrue(app.textFields["video.post.title"].waitForExistence(timeout: 5))
        app.navigationBars["发布影评"].buttons["取消"].tap()
        XCTAssertTrue(app.buttons["video.tab.home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["video.tab.home"].isSelected)
    }

    @MainActor
    func testPublishedReviewAppearsInProfile() {
        let app = launch()
        app.buttons["video.tab.publish"].tap()
        XCTAssertTrue(app.buttons["video.login.submit"].waitForExistence(timeout: 3))
        app.buttons["video.login.submit"].tap()
        let title = app.textFields["video.post.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("值得推荐的喜剧")
        app.textViews["video.post.body"].tap()
        app.textViews["video.post.body"].typeText("生活中的幽默和温暖，值得慢慢欣赏。")
        app.staticTexts["聊聊你刚看过的好故事"].tap()
        tap("video.post.submit", app)
        XCTAssertTrue(app.buttons["video.profile.posts"].waitForExistence(timeout: 5))
        app.buttons["video.profile.posts"].tap()
        XCTAssertTrue(app.staticTexts["值得推荐的喜剧"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLogoutRestoresProfileRootAndHomeBar() {
        let app = launch()
        app.buttons["video.tab.profile"].tap()
        app.buttons["video.profile.login"].tap()
        XCTAssertTrue(app.buttons["video.login.submit"].waitForExistence(timeout: 3))
        app.buttons["video.login.submit"].tap()
        XCTAssertTrue(app.staticTexts["光影体验官"].waitForExistence(timeout: 5))
        app.buttons["video.profile.settings"].tap()
        XCTAssertTrue(app.buttons["video.logout"].waitForExistence(timeout: 3))
        app.buttons["video.logout"].tap()
        XCTAssertTrue(app.buttons["video.tab.home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["video.tab.home"].isSelected)
        app.buttons["video.tab.profile"].tap()
        XCTAssertTrue(app.buttons["video.profile.login"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["video.tab.profile"].isHittable)
    }

    @MainActor
    func testRepeatedScrollKeepsPostersAndSelection() {
        let app = launch()
        let feed = app.collectionViews["video.feed"]
        for _ in 0..<4 {
            feed.swipeUp()
            feed.swipeDown()
        }
        XCTAssertTrue(app.cells["video.card.comedy"].isHittable)
        app.buttons["video.tab.free"].tap()
        app.buttons["video.tab.home"].tap()
        XCTAssertTrue(app.cells["video.card.comedy"].isHittable)
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["video.tab.home"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor
    private func tap(_ id: String, _ app: XCUIApplication) {
        let button = app.buttons[id]
        for _ in 0..<6 {
            if button.exists && button.isHittable {
                button.tap()
                return
            }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTFail("找不到可操作按钮：\(id)")
    }
    @MainActor
    private func tapLabel(_ label: String, _ app: XCUIApplication) {
        let button = app.buttons[label]
        for _ in 0..<6 {
            if button.exists && button.isHittable {
                button.tap()
                return
            }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTFail("找不到按钮：\(label)")
    }
}

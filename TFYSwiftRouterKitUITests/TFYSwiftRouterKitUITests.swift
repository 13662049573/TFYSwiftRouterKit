import XCTest

final class TFYSwiftRouterKitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoStartsWithCompleteInformationArchitecture() {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["开始"].waitForExistence(timeout: 5))
        for tab in ["开始", "演练", "导航栈", "事件"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "缺少 \(tab) Tab")
        }
        XCTAssertTrue(app.staticTexts["TFYSwiftRouterKit"].exists)
        XCTAssertTrue(app.cells["demo.start.push"].exists)

        app.tabBars.buttons["演练"].tap()
        XCTAssertTrue(app.navigationBars["演练"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.cells["demo.playground.window"].exists)
        app.tabBars.buttons["导航栈"].tap()
        XCTAssertTrue(app.navigationBars["导航栈"].waitForExistence(timeout: 3))
        app.tabBars.buttons["事件"].tap()
        XCTAssertTrue(app.navigationBars["事件"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testComponentTabBarRouteSelectsTargetAndPushes() {
        let app = launchApp()

        tapCell("demo.start.crossTab", in: app)

        XCTAssertTrue(app.navigationBars["跨 Tab 已完成"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["演练"].isSelected)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "TabBar Driver")).firstMatch.exists)
    }

    @MainActor
    func testTypedResultCompletesAndReturnsToCaller() {
        let app = launchApp()

        tapCell("demo.start.picker", in: app)
        XCTAssertTrue(app.buttons["demo.picker.option.0"].waitForExistence(timeout: 5))
        app.buttons["demo.picker.option.0"].tap()

        XCTAssertTrue(app.alerts["结果已返回"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["结果已返回"].staticTexts["singleTop"].exists)
    }

    @MainActor
    func testTypedSessionReceivesCommandEventAndFinalOutput() {
        let app = launchApp()

        tapCell("demo.start.session", in: app)
        XCTAssertTrue(app.staticTexts["调用方命令已到达页面"].waitForExistence(timeout: 5))
        app.buttons["demo.session.event"].tap()
        XCTAssertTrue(app.staticTexts["调用方已收到页面事件"].waitForExistence(timeout: 5))
        app.buttons["demo.session.finish"].tap()

        XCTAssertTrue(app.alerts["会话完成"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["会话完成"].staticTexts["会话已完成"].exists)
    }

    @MainActor
    func testRouteEventsAppearInTimeline() {
        let app = launchApp()

        tapCell("demo.start.push", in: app)
        XCTAssertTrue(app.buttons["demo.destination.done"].waitForExistence(timeout: 5))
        app.buttons["demo.destination.done"].tap()
        app.tabBars.buttons["事件"].tap()

        let events = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "demo.timeline.event."))
        XCTAssertTrue(events.firstMatch.waitForExistence(timeout: 5))
        events.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["事件详情"].waitForExistence(timeout: 5))
        let detail = app.textViews["demo.timeline.detail"].value as? String
        for field in ["事务 ID：", "来源：", "呈现：", "去重：", "目标 ID：", "链路 ID：", "错误码："] {
            XCTAssertTrue(detail?.contains(field) == true, "事件详情缺少字段：\(field)")
        }
    }

    @MainActor
    func testSessionTimeoutEndsInteractionAndClosesPage() {
        let app = launchApp()
        app.tabBars.buttons["演练"].tap()

        tapCell("demo.playground.timeout", in: app)

        XCTAssertTrue(app.alerts["超时已处理"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.alerts["超时已处理"].staticTexts["等待已以 timeout 结束，页面由 Router 关闭。"].exists)
    }

    @MainActor
    func testReplaceDoneRestoresPlaygroundRoot() {
        let app = launchApp()
        app.tabBars.buttons["演练"].tap()

        tapCell("demo.playground.replace", in: app)
        XCTAssertTrue(app.navigationBars["Replace 栈顶"].waitForExistence(timeout: 5))
        app.buttons["demo.destination.done"].tap()

        XCTAssertTrue(app.navigationBars["演练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cells["demo.playground.replace"].exists)
    }

    @MainActor
    func testRegistrationServiceAndRestorationProbes() {
        let app = launchApp()
        app.tabBars.buttons["演练"].tap()

        tapCell("demo.playground.registration", in: app)
        XCTAssertTrue(app.alerts["注册事务"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["注册事务"].staticTexts["重复注册已拒绝，事务中新加入的 Route 已完整回滚。"].exists)
        app.alerts["注册事务"].buttons["知道了"].tap()

        tapCell("demo.playground.service", in: app)
        XCTAssertTrue(app.alerts["组件服务"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["组件服务"].staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "contains = false")).firstMatch.exists)
        app.alerts["组件服务"].buttons["知道了"].tap()

        tapCell("demo.playground.restoration", in: app)
        XCTAssertTrue(app.alerts["导航快照已恢复"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["演练"].isSelected)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    @MainActor
    private func tapCell(_ identifier: String, in app: XCUIApplication) {
        let cell = app.cells[identifier]
        for _ in 0..<12 {
            if cell.exists && cell.isHittable { cell.tap(); return }
            app.tables.firstMatch.swipeUp()
        }
        XCTFail("找不到入口：\(identifier)")
    }
}

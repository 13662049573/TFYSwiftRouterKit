//
//  TFYSwiftRouterKitUITests.swift
//  TFYSwiftRouterKitUITests
//
//  Created by tianfengyou on 2026/9/12.
//

import XCTest

final class TFYSwiftRouterKitUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["组件路由首页"].waitForExistence(timeout: 3))
        for tab in ["首页", "商品", "购物车", "我的"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists)
        }

        app.tabBars.buttons["商品"].tap()
        XCTAssertTrue(app.navigationBars["商品组件"].waitForExistence(timeout: 2))
        app.tabBars.buttons["购物车"].tap()
        XCTAssertTrue(app.navigationBars["购物车组件"].waitForExistence(timeout: 2))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.navigationBars["我的组件"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testInteractiveRouteSessionEndToEnd() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Home → Product 双向会话"].waitForExistence(timeout: 3))
        app.staticTexts["Home → Product 双向会话"].tap()
        XCTAssertTrue(app.navigationBars["商品详情 / 路由会话"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["✅ 收到上游命令：updateBadge(3)"].waitForExistence(timeout: 3))

        app.buttons["点击回调：收藏"].tap()
        app.buttons["点击回调：分享"].tap()
        app.buttons["完成并返回结果"].tap()

        XCTAssertTrue(app.alerts["Product 回调到 Home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts["Product 回调到 Home"].staticTexts["最终结果：SKU-2026，收藏 1 次\n连续事件：收藏(SKU-2026)、分享(SKU-2026)"].exists)
    }

    @MainActor
    func testCrossTabServiceCheckoutNestedRouteAndResult() throws {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Home → Cart 服务 + 路由"].tap()
        XCTAssertTrue(app.navigationBars["购物车组件"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Swift 路由实践"].waitForExistence(timeout: 3))

        app.staticTexts["结算：Input → 嵌套路由 → Output"].tap()
        XCTAssertTrue(app.alerts["跨组件登录拦截"].waitForExistence(timeout: 3))
        app.alerts["跨组件登录拦截"].buttons["模拟登录"].tap()
        XCTAssertTrue(app.navigationBars["确认订单"].waitForExistence(timeout: 3))

        app.buttons["Sheet 路由选择优惠券"].tap()
        XCTAssertTrue(app.navigationBars["选择优惠券"].waitForExistence(timeout: 3))
        app.staticTexts["SWIFT-20"].tap()
        XCTAssertTrue(app.staticTexts["优惠券：SWIFT-20"].waitForExistence(timeout: 3))
        app.buttons["提交订单并回调 Cart"].tap()
        XCTAssertTrue(app.alerts["Checkout 回调到 Cart"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

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
    private func tapRow(_ title: String, in app: XCUIApplication) {
        let row = app.cells["demo-action-\(title)"]
        for _ in 0..<14 {
            if row.exists && row.isHittable { row.tap(); return }
            app.tables.firstMatch.swipeUp()
        }
        XCTFail("找不到可操作入口：\(title)")
    }

    @MainActor
    private func launchLaboratory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["路由能力实验室"].waitForExistence(timeout: 5))
        tapRow("路由能力实验室", in: app)
        XCTAssertTrue(app.navigationBars["路由能力实验室"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testLaboratoryTypedResult() {
        let app = launchLaboratory()
        tapRow("强类型 Input → Output", in: app)
        XCTAssertTrue(app.navigationBars["强类型选择器"].waitForExistence(timeout: 5))
        app.staticTexts["SwiftUI"].tap()
        XCTAssertTrue(app.alerts["强类型返回成功"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["强类型返回成功"].staticTexts["SwiftUI"].exists)
    }

    @MainActor
    func testLaboratoryTypedSession() {
        let app = launchLaboratory()
        tapRow("强类型双向会话", in: app)
        XCTAssertTrue(app.staticTexts["✅ 收到上游命令：updateBadge(8)"].waitForExistence(timeout: 5))
        app.buttons["点击回调：收藏"].tap()
        app.buttons["完成并返回结果"].tap()
        XCTAssertTrue(app.alerts["强类型会话完成"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaboratorySessionTimeoutAndCancellation() {
        let app = launchLaboratory()
        tapRow("会话等待超时（5 秒）", in: app)
        XCTAssertTrue(app.alerts["会话超时结果"].waitForExistence(timeout: 10))
        app.alerts["会话超时结果"].buttons["知道了"].tap()
        tapRow("主动取消会话", in: app)
        XCTAssertTrue(app.alerts["主动取消结果"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaboratoryUIKitHostingSwiftUI() {
        let app = launchLaboratory()
        tapRow("UIKit 托管 SwiftUI 页面", in: app)
        XCTAssertTrue(app.staticTexts["UIKit 托管 SwiftUI 页面"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Scope：lab.navigation"].exists)
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists)
    }

    @MainActor
    func testLaboratoryTimeout() {
        let app = launchLaboratory()
        tapRow("结果等待超时（3 秒）", in: app)
        XCTAssertTrue(app.alerts["超时演示结果"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.alerts["超时演示结果"].staticTexts["路由已超时"].exists)
    }

    @MainActor
    func testLaboratoryRegistrationAndRuntimeProbes() {
        let app = launchLaboratory()
        for (row, result) in [
            ("通用配置与业务资源隔离", "通用配置检查通过"),
            ("重复注册与事务回滚", "注册检查通过"),
            ("拦截器与循环保护", "拦截器检查通过"),
            ("Deep Link 优先级与安全校验", "Deep Link 检查通过"),
            ("不可恢复路由 skip / fail", "恢复策略检查通过"),
            ("历史容量与清理", "历史检查通过"),
            ("测试替身与调用记录", "测试替身检查通过")
        ] {
            tapRow(row, in: app)
            XCTAssertTrue(app.alerts[result].waitForExistence(timeout: 5), "\(row) 应显示校验成功")
            app.alerts[result].buttons["知道了"].tap()
        }
    }

    @MainActor
    func testLaboratorySnapshotMigration() {
        let app = launchLaboratory()
        tapRow("v1 → v2 迁移并恢复", in: app)
        XCTAssertTrue(app.alerts["迁移恢复成功"].waitForExistence(timeout: 5))
        app.alerts["迁移恢复成功"].buttons["知道了"].tap()
        XCTAssertTrue(app.navigationBars["实验页面 A"].exists)
        tapRow("保存此导航栈", in: app)
        XCTAssertTrue(app.alerts["快照已保存"].waitForExistence(timeout: 5))
        app.alerts["快照已保存"].buttons["知道了"].tap()
        // 保存行靠近底部；回到顶部使用系统返回按钮，避免依赖旧行的滚动位置。
        app.navigationBars["实验页面 A"].buttons.firstMatch.tap()
        tapRow("恢复已保存快照", in: app)
        XCTAssertTrue(app.alerts["恢复完成"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaboratoryNativeSwiftUIFactoryFailure() {
        let app = launchLaboratory()
        tapRow("原生 SwiftUI RouterHost", in: app)
        XCTAssertTrue(app.buttons["验证工厂错误回传"].waitForExistence(timeout: 5))
        app.buttons["验证工厂错误回传"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "路径数量 0 → 0")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["SwiftUI Sheet"].tap()
        XCTAssertTrue(app.buttons["关闭 / 返回"].waitForExistence(timeout: 5))
        app.buttons["关闭 / 返回"].tap()
        XCTAssertTrue(app.buttons["SwiftUI Push"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

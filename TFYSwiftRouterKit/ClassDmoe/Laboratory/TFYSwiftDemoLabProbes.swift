import SwiftUI
import UIKit

/// 探针会执行真实组件 API，并校验结果；所有破坏性试验均使用新建的注册表或独立驱动。
@MainActor
extension TFYSwiftDemoLaboratory {
    func configurationProbe() throws {
        let services = TFYSwiftComponentServiceRegistry()
        let primary = TFYSwiftComponentServiceKey<String>(namespace: "primary")
        let secondary = TFYSwiftComponentServiceKey<String>(namespace: "secondary")
        try services.register("第一个实例", for: primary)
        try services.register("第二个实例", for: secondary)
        let first = try services.resolve(primary)
        let second = try services.resolve(secondary)
        try require(first != second, "服务命名空间未隔离")
        let codecs = TFYSwiftRestorationRegistry()
        try codecs.register(TFYSwiftDemoProbeRoute.self, identifier: "demo.custom-codec", encode: {
            Data(String($0.id).utf8)
        }, decode: { data in
            guard let value = Int(String(decoding: data, as: UTF8.self)) else {
                throw TFYSwiftRouteError.invalidPayload("示例编码数据损坏")
            }
            return TFYSwiftDemoProbeRoute(id: value)
        })
        guard let descriptor = try codecs.descriptor(for: TFYSwiftAnyRoute(TFYSwiftDemoProbeRoute(id: 42))) else {
            throw TFYSwiftRouteError.restorationFailed("示例编码器未登记")
        }
        let decoded = try codecs.route(from: descriptor)
        try require(decoded.cast(to: TFYSwiftDemoProbeRoute.self)?.id == 42, "自定义格式恢复失败")
        report("通用配置检查通过", "✓ 当前默认 Scope：\(router.defaultScope.rawValue)\n✓ 同一类型的两个命名实例独立\n✓ 非 Codable 地址使用 App 编解码闭包恢复\n✓ 稳定错误码：\(TFYSwiftRouteError.timeout.code)\n✓ SwiftUI 错误图标和文案由 Demo 注入")
    }

    private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TFYSwiftRouteError.invalidPayload("演示校验失败：\(message)") }
    }

    func registrationProbe() throws {
        var checks: [String] = []
        let navigation = UINavigationController()
        let isolated = TFYSwiftRouterAssembly(navigationController: navigation)
        try isolated.destinations.register(identifier: "occupied", routeType: TFYSwiftDemoProbeRoute.self) { _, _ in UIViewController() }
        do {
            try isolated.register(TFYSwiftDemoProbeRoute.self, destinationID: "occupied") { _, _ in UIViewController() }
            throw TFYSwiftRouteError.invalidPayload("应检测到重复页面标识")
        } catch TFYSwiftRouteError.duplicateRegistration {
            try require(!isolated.routes.contains(TFYSwiftDemoProbeRoute.self), "Route 残留")
            checks.append("✓ 页面工厂冲突：Route 注册已回滚")
        }
        try isolated.routes.register(TFYSwiftDemoProbeRoute.self) { _, _ in .init(identifier: "occupied") }
        do {
            try isolated.routes.register(TFYSwiftDemoProbeRoute.self) { _, _ in .init(identifier: "other") }
        } catch TFYSwiftRouteError.duplicateRegistration { checks.append("✓ Route 重复注册被拒绝") }
        try isolated.routes.register(TFYSwiftDemoProbeRoute.self, replacingExisting: true) { _, _ in .init(identifier: "replacement") }
        isolated.routes.unregister(TFYSwiftDemoProbeRoute.self)
        isolated.destinations.unregister(identifier: "occupied")
        try require(!isolated.destinations.contains("occupied"), "页面注销失败")
        checks.append("✓ 显式替换与注销成功")
        do {
            try isolated.register(navigationController: navigation, for: .main)
        } catch TFYSwiftRouteError.duplicateRegistration { checks.append("✓ Scope 重复注册被拒绝") }

        let services = TFYSwiftComponentServiceRegistry()
        let service: any TFYSwiftDemoCartServicing = TFYSwiftDemoCartService()
        do {
            try services.performRegistrationTransaction {
                try services.register(service, for: TFYSwiftDemoComponentKeys.cart)
                try services.register(service, for: TFYSwiftDemoComponentKeys.cart)
            }
        } catch TFYSwiftRouteError.duplicateService {
            try require(!services.contains(TFYSwiftDemoComponentKeys.cart), "服务注册残留")
            checks.append("✓ 服务冲突：整个批次已回滚")
        }
        let swiftUI = TFYSwiftSwiftUIDestinationRegistry()
        do {
            try swiftUI.performRegistrationTransaction {
                try swiftUI.register(identifier: "a", routeType: TFYSwiftDemoProbeRoute.self) { _, _ in Text("A") }
                try swiftUI.register(identifier: "a", routeType: TFYSwiftDemoProbeRoute.self) { _, _ in Text("B") }
            }
        } catch TFYSwiftRouteError.duplicateRegistration {
            try require(!swiftUI.contains("a"), "SwiftUI 工厂残留")
            checks.append("✓ SwiftUI 工厂事务回滚成功")
        }
        report("注册检查通过", checks.joined(separator: "\n"))
    }

    /// 无窗口的真实 SwiftUI 状态驱动，可验证流水线而不改变屏幕上的 UIKit 导航栈。
    private func probeRouter() throws -> TFYSwiftRouter {
        let driver = TFYSwiftSwiftUINavigationDriver()
        let router = TFYSwiftRouter(driver: driver)
        try router.registry.register(TFYSwiftDemoLabRoute.self) { _, _ in .init(identifier: "probe") }
        try driver.destinations.register(identifier: "probe", routeType: TFYSwiftDemoLabRoute.self) { route, _ in Text(route.rawValue) }
        return router
    }

    func interceptorProbe() async throws {
        let router = try probeRouter()
        router.maximumSuspensionDepth = 2
        router.interceptors.add(TFYSwiftDemoProbeInterceptor(.redirect), priority: 100)
        try await router.open(TFYSwiftDemoLabRoute.pageA)
        try require(router.routes().last == TFYSwiftAnyRoute(TFYSwiftDemoLabRoute.pageB), "重定向目标错误")
        var checks = ["✓ A 重定向到 B，并通过 proceed 完成"]
        router.interceptors.add(TFYSwiftDemoProbeInterceptor(.reject))
        do { try await router.open(TFYSwiftDemoLabRoute.pageA) }
        catch TFYSwiftRouteError.invalidPayload { checks.append("✓ reject 阻止导航") }
        router.interceptors.add(TFYSwiftDemoProbeInterceptor(.suspendForever))
        do { try await router.open(TFYSwiftDemoLabRoute.pageA) }
        catch TFYSwiftRouteError.suspensionLoop { checks.append("✓ 重复 suspend 超过上限，终止循环") }
        router.interceptors.remove(identifier: "lab.probe")
        try require(router.interceptors.identifiers.isEmpty, "拦截器移除失败")
        checks.append("✓ 拦截器动态移除成功；登录挂起请体验购物车结算")
        report("拦截器检查通过", checks.joined(separator: "\n"))
    }

    func deepLinkProbe() async throws {
        let engine = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tfyswift", universalLinkHosts: ["router.tfy.com"]))
        await engine.add(TFYSwiftDemoPriorityParser(identifier: "fallback", target: .pageA))
        await engine.add(TFYSwiftDemoPriorityParser(identifier: "preferred", target: .pageB), priority: 100)
        guard let url = URL(string: "tfyswift://lab") else { return }
        let preferred = try await engine.route(for: .init(url: url))
        try require(preferred == TFYSwiftAnyRoute(TFYSwiftDemoLabRoute.pageB), "优先级顺序错误")
        await engine.remove(identifier: "preferred")
        let fallback = try await engine.route(for: .init(url: url))
        try require(fallback == TFYSwiftAnyRoute(TFYSwiftDemoLabRoute.pageA), "回退 Parser 错误")
        var checks = ["✓ 高优先级解析到 B", "✓ 移除后回退解析到 A"]
        for text in ["ftp://lab", "https://untrusted.example/product/1", "tfyswift://user:password@lab"] {
            guard let denied = URL(string: text) else { continue }
            do {
                _ = try await engine.route(for: .init(url: denied))
                throw TFYSwiftRouteError.invalidPayload("应拒绝非法链接")
            } catch TFYSwiftRouteError.invalidDeepLink { checks.append("✓ 拒绝：\(text)") }
        }
        let identifiers = await engine.parserIdentifiers
        checks.append("当前 Parser：\(identifiers.joined(separator: ", "))")
        report("Deep Link 检查通过", checks.joined(separator: "\n"))
    }

    func restorationPolicyProbe() async throws {
        let router = try probeRouter()
        try await router.open(TFYSwiftDemoLabRoute.pageA, presentation: .root())
        let registry = TFYSwiftRestorationRegistry()
        let coordinator = TFYSwiftRestorationCoordinator(registry: registry, router: router)
        var checks: [String] = []
        do { _ = try coordinator.makeSnapshot(scopes: [.main], unrestorableRoutePolicy: .fail) }
        catch TFYSwiftRouteError.restorationFailed { checks.append("✓ fail：未登记编码器时返回错误") }
        let skipped = try coordinator.makeSnapshot(scopes: [.main], unrestorableRoutePolicy: .skip)
        try require(skipped.scopes.first?.routes.isEmpty == true, "skip 未排除地址")
        checks.append("✓ skip：忽略未登记地址，得到空导航列表")
        try registry.register(TFYSwiftDemoLabRoute.self, identifier: "lab.route")
        let saved = try coordinator.makeSnapshot(scopes: [.main])
        try require(saved.scopes.first?.routes.count == 1, "编码失败")
        checks.append("✓ 登记 Codable 地址后可严格保存")
        registry.unregister(TFYSwiftDemoLabRoute.self)
        checks.append("✓ 注销时同时移除编码器和解码器")
        report("恢复策略检查通过", checks.joined(separator: "\n"))
    }

    func historyProbe() async throws {
        let router = try probeRouter()
        let history = TFYSwiftRouteHistory(capacity: 8)
        router.events.add(history)
        router.transactionStateCapacity = 3
        for _ in 0..<6 { try await router.open(TFYSwiftDemoLabRoute.pageA, presentation: .root()) }
        try require(router.transactionStates.count == 3, "终态容量错误")
        try require(history.events.count == 8, "历史容量错误")
        if let id = router.transactionStates.keys.first { router.removeTransactionState(id: id) }
        try require(router.transactionStates.count == 2, "按 ID 清理失败")
        router.removeAllTransactionStates()
        history.removeAll()
        try require(router.transactionStates.isEmpty && history.events.isEmpty, "清理失败")
        report("历史检查通过", "✓ 6 次导航只保留最近 3 个状态记录\n✓ 事件历史限制为 8 条\n✓ 按 ID 移除、全部移除和历史清空通过\n清理诊断记录不会取消运行中的事务。")
    }

    func testingProbe() async throws {
        let mock = TFYSwiftTestRouter()
        let route = TFYSwiftDemoPickerContract()
        mock.provide(String.self) { "默认值" }
        mock.provide(for: route) { "指定路由的结果" }
        let output = try await mock.openTyped(route, input: ["选项"], scope: "test.checkout", metadata: .init(values: ["entry": "lab"], traceID: "lab-trace"))
        try require(output == "指定路由的结果", "结果 Provider 优先级错误")
        try require(mock.invocations.last?.scope == "test.checkout", "Scope 丢失")
        try require(mock.invocations.last?.metadata.traceID == "lab-trace", "Metadata 丢失")
        let product = TFYSwiftDemoCatalog.products[0]
        let sessionRoute = TFYSwiftDemoSessionContract(productID: product.id)
        mock.provide(for: sessionRoute) { [weak mock] in
            // 在 Provider 中取得交互，无需猜测 Task 的调度时机。
            let interaction = mock?.interaction(for: sessionRoute)
            try interaction?.events?.send(TFYSwiftDemoProductEvent.shareTapped(productID: product.id))
            return TFYSwiftDemoProductOutput(productID: product.id, favoriteCount: 0, didConfirm: true)
        }
        let session = mock.openTypedSession(sessionRoute, input: product)
        try session.send(.refresh)
        var eventCount = 0
        for await _ in session.events { eventCount += 1 }
        _ = try await session.value
        try require(eventCount == 1, "事件未传递")
        try await mock.back(count: 2, scope: "test.checkout")
        report("测试替身检查通过", "✓ 指定路由的结果优先于类型默认值\n✓ Scope、Metadata、输入类型已记录\n✓ 异步会话返回一个事件并关闭流\n✓ 回退动作已记录\n调用总数：\(mock.invocations.count)\n无需真正打开页面。")
    }
}

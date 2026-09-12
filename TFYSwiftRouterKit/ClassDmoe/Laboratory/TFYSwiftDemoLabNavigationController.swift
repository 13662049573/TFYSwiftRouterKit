import SwiftUI
import UIKit

/// 实验室拥有独立导航容器和 Router。更换根页面、恢复快照不会影响四个业务 Tab。
final class TFYSwiftDemoLabNavigationController: UINavigationController {
    private var laboratory: TFYSwiftDemoLaboratory!
    private var startupTask: Task<Void, Never>?

    init(laboratory _: Void) throws {
        super.init(nibName: nil, bundle: nil)
        laboratory = try TFYSwiftDemoLaboratory(navigation: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("请使用 init()") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.prefersLargeTitles = true
        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do { try await laboratory.router.open(TFYSwiftDemoLabRoute.root, presentation: .root()) }
            catch {
                setViewControllers([TFYSwiftDemoDetailViewController(
                    heading: "实验室启动失败", message: error.localizedDescription, color: .systemRed
                )], animated: false)
            }
        }
    }

    deinit { startupTask?.cancel() }
}

/// 应用组合根：注册页面工厂、持有历史及恢复服务；页面仅持有按需执行的操作。
@MainActor
final class TFYSwiftDemoLaboratory {
    let assembly: TFYSwiftRouterAssembly
    var router: TFYSwiftRouter { assembly.router }
    let history = TFYSwiftRouteHistory(capacity: 100)
    let restoration: TFYSwiftRestorationCoordinator
    private weak var navigation: UINavigationController?
    private let snapshotKey = "TFYSwiftRouterKit.lab.snapshot.v2"

    init(navigation: UINavigationController) throws {
        self.navigation = navigation
        assembly = TFYSwiftRouterAssembly(navigationController: navigation, initialScope: "lab.navigation")
        let codecs = TFYSwiftRestorationRegistry()
        try codecs.register(TFYSwiftDemoLabRoute.self, identifier: "lab.route")
        restoration = TFYSwiftRestorationCoordinator(registry: codecs, router: assembly.router, currentSchemaVersion: 2)
        // v1 与 v2 的地址载荷相同；真实业务应在此转换已变更的字段和标识。
        try restoration.registerMigration(fromVersion: 1) { old in
            TFYSwiftNavigationSnapshot(schemaVersion: 2, createdAt: old.createdAt, scopes: old.scopes)
        }
        assembly.events.add(history)
        try assembly.destinations.registerSwiftUI(
            identifier: "lab.hosted-swiftui", routeType: TFYSwiftDemoLabRoute.self
        ) { _, context in
            VStack(spacing: 20) {
                Image(systemName: "swift").font(.largeTitle)
                Text("UIKit 托管 SwiftUI 页面").font(.title2)
                Text("registerSwiftUI 创建 UIHostingController；返回按钮由外层 UIKit 导航栈提供。")
                Text("Scope：\(context.routeContext.scope.rawValue)")
            }
            .padding()
        }
        try assembly.register(TFYSwiftDemoLabRoute.self, destinationID: "lab.page", resolver: { route, _ in
            .init(identifier: route == .hostedSwiftUI ? "lab.hosted-swiftui" : "lab.page")
        }) { [weak self] route, _ in
            guard let self else { throw TFYSwiftRouteError.cancelled }
            switch route {
            case .root: return makeMenu()
            case .inspector: return TFYSwiftDemoInspectorViewController(history: history)
            case .swiftUI: return UIHostingController(rootView: try TFYSwiftDemoNativeRouterView())
            case .hostedSwiftUI: throw TFYSwiftRouteError.invalidPayload("托管页面应由专用 SwiftUI 工厂创建")
            case .pageA, .pageB: return makePage(route)
            }
        }
        try assembly.register(TFYSwiftDemoPickerContract.self) { _, context in
            UINavigationController(rootViewController: TFYSwiftDemoValuePickerViewController(
                title: "强类型选择器", values: try context.input(), result: context.result
            ))
        }
        try assembly.register(TFYSwiftDemoSessionContract.self) { _, context in
            TFYSwiftDemoInteractiveProductViewController(product: try context.input(), context: context)
        }
        assembly.driver.registerCustomPresentation(identifier: "lab.fade") { source, destination, _ in
            destination.modalPresentationStyle = .overFullScreen
            destination.modalTransitionStyle = .crossDissolve
            await withCheckedContinuation { continuation in
                source.present(destination, animated: true) { continuation.resume() }
            }
        }
    }

    private func action(_ title: String, _ detail: String, _ symbol: String = "chevron.right.circle",
                        run: @escaping @MainActor (TFYSwiftDemoLaboratory) async throws -> Void) -> TFYSwiftDemoMenuViewController.Action {
        .init(title: title, detail: detail, symbol: symbol) { [weak self] in
            guard let self else { return }
            try await run(self)
        }
    }

    func makeMenu() -> UIViewController {
        let menu = TFYSwiftDemoMenuViewController(title: "路由能力实验室")
        menu.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.navigation?.dismiss(animated: true)
        })
        menu.setSections([
            ("强类型通信与生命周期", [
                action("强类型 Input → Output", "openTyped 自动推导 [String] 输入与 String 输出") { lab in
                    let value = try await lab.router.openTyped(TFYSwiftDemoPickerContract(), input: ["Swift", "UIKit", "SwiftUI"], presentation: .sheet())
                    await lab.waitForModalDismissal()
                    lab.report("强类型返回成功", value)
                },
                action("强类型双向会话", "自动推导 Command/Event/Output，发送刷新并接收收藏事件") { lab in
                    let session = lab.makeSession()
                    var received: [String] = []
                    let observer = session.observeEvents { received.append(String(describing: $0)) }
                    defer { observer.cancel() }
                    try session.send(.refresh)
                    try session.send(.updateBadge(8))
                    let value = try await session.value
                    await observer.value
                    await lab.waitForNavigationTransition()
                    lab.report("强类型会话完成", "商品：\(value.productID)\n收藏次数：\(value.favoriteCount)\n事件：\(received.joined(separator: "、"))")
                },
                action("结果等待超时（3 秒）", "不选择时抛出 timeout；等待结束后由 Demo 关闭页面") { lab in
                    do {
                        let value = try await lab.router.open(TFYSwiftDemoPickerContract(), input: ["提前完成"], presentation: .sheet(), timeout: 3, expecting: String.self)
                        await lab.waitForModalDismissal()
                        lab.report("提前完成", value)
                    } catch {
                        await lab.closeModal()
                        lab.report("超时演示结果", error.localizedDescription)
                    }
                },
                action("会话等待超时（5 秒）", "session.value(timeout:) 关闭通信通道；Demo 返回实验室") { lab in
                    let session = lab.makeSession()
                    do {
                        _ = try await session.value(timeout: 5)
                        await lab.waitForNavigationTransition()
                        lab.report("会话提前完成", "用户在 5 秒内返回了结果。")
                    } catch {
                        lab.navigation?.popToRootViewController(animated: false)
                        lab.report("会话超时结果", error.localizedDescription)
                    }
                },
                action("主动取消会话", "立即 session.cancel()，观察 cancelled 终态及通道关闭") { lab in
                    let session = lab.makeSession()
                    session.cancel()
                    do { _ = try await session.value }
                    catch {
                        lab.navigation?.popToRootViewController(animated: false)
                        lab.report("主动取消结果", error.localizedDescription)
                    }
                }
            ]),
            ("页面呈现、回退与去重", [
                action("Push 与导航操作", "进入 A 页；可继续 Push、Replace、Root、Back 和 Dismiss") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .push())
                },
                action("Sheet 配置", "仅大尺寸、显示拖拽条、允许手势关闭") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .sheet(.init(detents: [.large])))
                },
                action("FullScreen", "全屏展示；目标页面提供 dismiss 和 dismissAll 操作") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .fullScreen())
                },
                action("自定义淡入转场", "注册 lab.fade 后通过 .custom 调用处理器") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .custom("lab.fade"))
                },
                action("新窗口接入边界", "未安装 Scene 处理器时，验证 sceneUnavailable 错误") { lab in
                    do { try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .newWindow) }
                    catch { lab.report("新窗口需要 App 接入", "\(error.localizedDescription)\n\n多窗口由 App 的 SceneDelegate 和系统能力决定，使用 registerNewWindowPresentation 安装处理器。") }
                },
                action("singleTop 去重", "同一地址打开两次，只新增一页；Inspector 记录 deduplicated") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .push(animated: false))
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, deduplication: .singleTop)
                    lab.report("singleTop 结果", "导航页数：\(lab.router.navigationRoutes().count)，预期 2（根页 + A）。")
                },
                action("singleTask 复用", "先打开 A、B，再激活 A；B 从栈中移除") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, presentation: .push(animated: false))
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageB, presentation: .push(animated: false))
                    try await lab.router.open(TFYSwiftDemoLabRoute.pageA, deduplication: .singleTask)
                    await lab.waitForNavigationTransition()
                    lab.report("singleTask 结果", "导航页数：\(lab.router.navigationRoutes().count)，预期 2。")
                }
            ]),
            ("注册、解耦与防护", [
                action("检查注册清单", "查看 Route、Destination、Scope 及恢复标识") { lab in
                    lab.report("注册清单", "Route：\n\(lab.assembly.routes.registeredRouteNames.joined(separator: "\n"))\n\nDestination：\n\(lab.assembly.destinations.registeredDestinationIDs.joined(separator: "\n"))\n\nScope：\(lab.assembly.scopedDriver.registeredScopes.map(\.rawValue))\n恢复：\(lab.restoration.registry.registeredIdentifiers)")
                },
                action("通用配置与业务资源隔离", "自定义默认 Scope、服务命名空间、自定义编码器、稳定错误码") { try $0.configurationProbe() },
                action("重复注册与事务回滚", "真实制造 Route/页面/Scope/服务注册冲突，检查无残留") { try $0.registrationProbe() },
                action("拦截器与循环保护", "运行 proceed、redirect、reject、suspend 上限探针") { try await $0.interceptorProbe() },
                action("Deep Link 优先级与安全校验", "高优先级优先、移除后回退；拒绝非白名单 URL") { try await $0.deepLinkProbe() },
                action("UIKit 托管 SwiftUI 页面", "通过 registerSwiftUI 注册；仍在 UIKit 导航栈中展示") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.hostedSwiftUI)
                },
                action("原生 SwiftUI RouterHost", "独立 NavigationStack、Sheet、FullScreen、工厂错误回传") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.swiftUI)
                }
            ]),
            ("快照、迁移与诊断", [
                action("保存当前导航快照", "JSON 编码后存入 UserDefaults；只保存 root/push 地址") { try $0.saveSnapshot() },
                action("恢复已保存快照", "从 UserDefaults 解码，经过注册表与拦截器重建页面") { try await $0.restoreSnapshot() },
                action("v1 → v2 迁移并恢复", "构造旧快照，执行已注册迁移，恢复根页 + A") { try await $0.migrationProbe() },
                action("不可恢复路由 skip / fail", "未注册恢复编码的契约：严格模式报错，跳过模式排除") { try await $0.restorationPolicyProbe() },
                action("查看事务历史", "created → resolved → presented → completed / cancelled / failed") { lab in
                    try await lab.router.open(TFYSwiftDemoLabRoute.inspector)
                },
                action("历史容量与清理", "限定最近终态数量；演示按 ID 清理与全部清理") { try await $0.historyProbe() },
                action("测试替身与调用记录", "TFYSwiftTestRouter 注入结果、异步会话并验证 Scope/Metadata") { try await $0.testingProbe() }
            ])
        ])
        return menu
    }

    private func makeSession() -> TFYSwiftRouteSession<TFYSwiftDemoProductCommand, TFYSwiftDemoProductEvent, TFYSwiftDemoProductOutput> {
        let product = TFYSwiftDemoCatalog.products[0]
        return router.openTypedSession(TFYSwiftDemoSessionContract(productID: product.id), input: product, presentation: .push())
    }

    private func makePage(_ route: TFYSwiftDemoLabRoute) -> UIViewController {
        let page = TFYSwiftDemoMenuViewController(title: route == .pageA ? "实验页面 A" : "实验页面 B")
        page.setSections([("导航操作（作用于实验室 Scope）", [
            action("继续 Push B", "展示同一 Router 的下一页") { try await $0.router.open(TFYSwiftDemoLabRoute.pageB, presentation: .push()) },
            action("Replace 为 B", "替换当前导航栈顶；原页面的交互会取消") { try await $0.router.open(TFYSwiftDemoLabRoute.pageB, presentation: .replace()) },
            action("Root 重建实验室", "清空导航栈及模态页面，重新安装根路由") { try await $0.router.open(TFYSwiftDemoLabRoute.root, presentation: .root()) },
            action("Back 一层", "路由器回退一页") { try await $0.router.back() },
            action("Back 两层", "不足两层时回退到根页") { try await $0.router.back(count: 2) },
            action("BackToRoot", "回到实验室根页") { try await $0.router.backToRoot() },
            action("Dismiss 当前弹层", "仅在 Sheet、FullScreen、自定义弹层中使用") { try await $0.router.dismiss() },
            action("DismissAll 弹层", "关闭当前 Scope 的全部模态页面") { try await $0.router.dismissAll() },
            action("保存此导航栈", "在 A/B 页面保存后，返回根页点击恢复") { try $0.saveSnapshot() },
            action("查看当前栈", "对比包含弹层的 routes 和可恢复的 navigationRoutes") { lab in
                lab.report("当前栈", "全部：\(lab.router.routes().map(\.description))\n导航：\(lab.router.navigationRoutes().map(\.description))")
            }
        ])])
        return page
    }

    func report(_ title: String, _ message: String) {
        var presenter: UIViewController? = navigation?.visibleViewController
        while let presented = presenter?.presentedViewController { presenter = presented }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        presenter?.present(alert, animated: true)
    }

    /// 结果完成与页面关闭是两个操作；等待 UIKit 的真实转场完成后再展示结果提示。
    private func waitForNavigationTransition() async {
        guard let transition = navigation?.transitionCoordinator else { return }
        await withCheckedContinuation { continuation in
            let accepted = transition.animate(alongsideTransition: nil) { _ in continuation.resume() }
            if !accepted { continuation.resume() }
        }
    }

    private func waitForModalDismissal() async {
        guard let transition = navigation?.presentedViewController?.transitionCoordinator else { return }
        await withCheckedContinuation { continuation in
            let accepted = transition.animate(alongsideTransition: nil) { _ in continuation.resume() }
            if !accepted { continuation.resume() }
        }
    }

    private func closeModal() async {
        guard let navigation, navigation.presentedViewController != nil else { return }
        await withCheckedContinuation { continuation in
            navigation.dismiss(animated: true) { continuation.resume() }
        }
    }

    private func saveSnapshot() throws {
        let snapshot = try restoration.makeSnapshot(scopes: [router.defaultScope])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        UserDefaults.standard.set(data, forKey: snapshotKey)
        report("快照已保存", "版本：\(snapshot.schemaVersion)\n页面数：\(snapshot.scopes.first?.routes.count ?? 0)\nJSON 大小：\(data.count) 字节\n只包含路由地址；退出实验室后仍可恢复。")
    }

    private func restoreSnapshot() async throws {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else {
            throw TFYSwiftRouteError.restorationFailed("请先进入 A/B 页面并保存导航栈")
        }
        try await restoration.restore(JSONDecoder().decode(TFYSwiftNavigationSnapshot.self, from: data))
        report("恢复完成", "已通过正常路由流程重建 \(router.navigationRoutes().count) 个页面。")
    }

    private func migrationProbe() async throws {
        let descriptors = try [TFYSwiftDemoLabRoute.root, .pageA].map {
            guard let descriptor = try restoration.registry.descriptor(for: TFYSwiftAnyRoute($0)) else {
                throw TFYSwiftRouteError.restorationFailed("实验室路由缺少编码器")
            }
            return descriptor
        }
        let old = TFYSwiftNavigationSnapshot(schemaVersion: 1, scopes: [.init(scope: router.defaultScope, routes: descriptors)])
        try await restoration.restore(old)
        let current = try restoration.makeSnapshot(scopes: [router.defaultScope])
        report("迁移恢复成功", "输入 v1 → 输出 v\(current.schemaVersion)；页面数 \(router.navigationRoutes().count)。")
    }
}

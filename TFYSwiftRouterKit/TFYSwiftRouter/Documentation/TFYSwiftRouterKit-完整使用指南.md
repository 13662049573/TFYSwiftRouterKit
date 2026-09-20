# TFYSwiftRouterKit 完整使用指南：从 0 到 1

本文对应 TFYSwiftRouterKit 2.1.0 与当前 `ClassDemo`。目标是从空 UIKit 工程完成单栈路由，再升级到组件级 TabBar 路由、强类型结果、双向 Session、Deep Link、恢复和测试。

## 1. 安装

最低环境为 iOS 16、Swift 6。SwiftPM 按需选择 Core、UIKit、SwiftUI、DeepLink、Restoration 与 Testing；小型 App 可以直接使用运行时聚合产品 `TFYSwiftRouterKit`，测试 Target 仍需单独依赖 `TFYSwiftRouterTesting`。

~~~swift
dependencies: [
    .package(
        url: "https://github.com/13662049573/TFYSwiftRouterKit.git",
        from: "2.1.0"
    )
]
~~~

CocoaPods：

~~~ruby
pod 'TFYSwiftRouterKit', '~> 2.1'
~~~

## 2. 第一次路由

地址表达“去哪里”，不持有控制器、闭包或服务实例：

~~~swift
enum AppRoute: Hashable, Sendable, TFYSwiftRoute {
    case home
    case detail(id: String)
}
~~~

让页面声明自己的 Route、目标标识、工厂和根 Scope 关联：

~~~swift
final class HomeViewController: UIViewController {
    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<AppRoute> {
        .init(
            rootScope: .main,
            rootRoute: AppRoute.home,
            destinationID: "app.page"
        ) { route, _ in
            let page = HomeViewController()
            switch route {
            case .home: page.title = "首页"
            case .detail(let id): page.title = "详情 \(id)"
            }
            return page
        }
    }
}

@MainActor
final class AppFlow {
    let navigationController = UINavigationController()
    let assembly: TFYSwiftRouterAssembly

    init() throws {
        assembly = TFYSwiftRouterAssembly(
            navigationController: navigationController
        )
        _ = try assembly.registerConfigurations([
            HomeViewController.routeConfiguration()
        ])
    }

    func start() async throws {
        try await assembly.router.open(
            AppRoute.home,
            presentation: .root(animated: false),
            source: .programmatic
        )
    }
}
~~~

`AppFlow`、Assembly 和导航控制器必须被 Scene 强持有。页面跳转：

~~~swift
try await assembly.router.open(
    AppRoute.detail(id: "1001"),
    presentation: .push(),
    deduplication: .singleTop
)
~~~

## 3. 组件级 TabBar 路由

每个 Tab 对应一个稳定 Scope 和一个导航控制器。TabBar Assembly 会建立 Scope、Tab 索引与 Driver 的唯一映射：

~~~swift
let tabBarController = UITabBarController()
let homeNavigation = UINavigationController()
let exploreNavigation = UINavigationController()

let assembly = try TFYSwiftRouterAssembly(
    tabBarController: tabBarController,
    tabs: [
        TFYSwiftTabBarScope(
            scope: "app.home",
            navigationController: homeNavigation
        ),
        TFYSwiftTabBarScope(
            scope: "app.explore",
            navigationController: exploreNavigation
        )
    ],
    initialScope: "app.home"
)
~~~

跨 Tab 打开页面只指定目标 Scope：

~~~swift
try await assembly.router.open(
    AppRoute.detail(id: "2001"),
    presentation: .push(),
    scope: "app.explore"
)
~~~

执行链路：

~~~text
Router → TabBar Driver 选择 app.explore → Scoped Driver
       → exploreNavigation → Push
~~~

只切换 Tab、不打开页面：

~~~swift
try assembly.tabBarDriver?.select("app.explore")
~~~

每个底层 UIKit Driver 可独立配置宿主能力：

~~~swift
for driver in assembly.navigationDrivers.values {
    driver.registerCustomPresentation(identifier: "app.flip") {
        source, destination, _ in
        destination.modalTransitionStyle = .flipHorizontal
        source.present(destination, animated: true)
    }
}
~~~

重复 Scope、重复 Tab 索引和不存在的初始 Scope 会在装配阶段抛错。

## 4. 呈现、回退与去重

呈现方式包括 `automatic`、`push`、`sheet`、`fullScreen`、`replace`、`root`、`custom` 和 `newWindow`。

~~~swift
try await assembly.router.back(scope: "app.explore")
try await assembly.router.backToRoot(scope: "app.explore")
try await assembly.router.dismiss(scope: "app.explore")
try await assembly.router.dismissAll(scope: "app.explore")
~~~

去重策略：

- `none`：每次创建目标。
- `singleTop`：目标已经位于栈顶时激活现有页面。
- `singleTask`：目标位于栈内时回到该页面并移除其后页面。

带新 Input、Result 或 Session 的请求不应复用旧页面，交互流程优先使用 `none`。

## 5. 强类型 Input 与 Output

~~~swift
struct PickerRoute: Hashable, Sendable, TFYSwiftRouteContract {
    typealias Input = [String]
    typealias Output = String
}

try assembly.registerTyped(PickerRoute.self) { _, context in
    PickerViewController(
        values: context.input,
        onSelect: { value in try? context.finish(value) },
        onCancel: { context.cancel() }
    )
}

let value = try await assembly.router.openTyped(
    PickerRoute(),
    input: ["singleTop", "singleTask", "none"],
    presentation: .sheet(),
    scope: "app.explore"
)
try await assembly.router.dismiss(scope: "app.explore")
~~~

Result 结束通信，不自动决定页面应当 Pop 还是 Dismiss。Demo 由调用方通过 Router 关闭页面，并等待真实视图层级结束模态转场后再显示反馈。

## 6. 双向 Session

~~~swift
enum PlayerCommand: Sendable { case refresh }
enum PlayerEvent: Sendable { case refreshed }
struct PlayerOutput: Sendable { let summary: String }

struct PlayerRoute: Hashable, Sendable, TFYSwiftSessionRouteContract {
    typealias Input = String
    typealias Command = PlayerCommand
    typealias Event = PlayerEvent
    typealias Output = PlayerOutput
}

let session = assembly.router.openTypedSession(
    PlayerRoute(),
    input: "1001",
    presentation: .sheet(),
    scope: "app.explore"
)
try session.send(.refresh)
let eventTask = session.observeEvents { print($0) }
let output = try await session.value(timeout: 15)
eventTask.cancel()
~~~

页面通过 `context.commands()` 消费命令、`context.send(...)` 发送连续事件、`context.finish(...)` 完成最终输出。`session.cancel()` 会结束等待、Command 和 Event 生命周期，但不会隐式关闭 UI。

## 7. 拦截器与 Deep Link

拦截器可以 `proceed`、`reject`、`redirect` 或 `suspend`。重定向和恢复后的请求仍走完整 Router 流水线。

~~~swift
assembly.interceptors.add(AppAuthInterceptor())

let engine = TFYSwiftDeepLinkEngine(
    policy: .app(
        scheme: "myapp",
        universalLinkHosts: ["example.com"]
    )
)
await engine.add(AppDeepLinkParser(), priority: 100)

try await assembly.router.open(
    TFYSwiftDeepLinkRequest(url: url),
    using: engine,
    presentation: .push(),
    scope: "app.explore"
)
~~~

App 需要同时处理冷启动 URL/NSUserActivity 与热启动入口。Universal Link 还需要 Associated Domains 和服务端关联文件。

## 8. 导航快照与恢复

只登记明确允许持久化的 Codable Route：

~~~swift
let registry = TFYSwiftRestorationRegistry()
try registry.register(AppRoute.self, identifier: "app.route.v1")

let restoration = TFYSwiftRestorationCoordinator(
    registry: registry,
    router: assembly.router
)
let snapshot = try restoration.makeSnapshot(
    scopes: ["app.home", "app.explore"]
)
let data = try JSONEncoder().encode(snapshot)
let decoded = try JSONDecoder().decode(
    TFYSwiftNavigationSnapshot.self,
    from: data
)
try await restoration.restore(decoded)
~~~

恢复先完成迁移和全量解码，再为受影响 Scope 创建页面实例级检查点。任一 Scope 展示失败或任务取消时，UIKit、SwiftUI 和 Scoped Driver 会回滚已修改的页面栈。Sheet、Input、Session、服务实例、选中 Tab 和滚动位置不在快照中。

## 9. 组件服务与注册事务

~~~swift
let services = TFYSwiftComponentServiceRegistry()
let key = TFYSwiftComponentServiceKey<String>(namespace: "primary")

try services.performRegistrationTransaction {
    try services.register("ready", for: key)
}
let value = try services.resolve(key)
services.unregister(key)
~~~

Route Registry、Destination Registry 与 Service Registry 都支持事务登记；同步闭包抛错时恢复映射。事务不回滚网络请求或服务对象内部副作用。

## 10. SwiftUI

UIKit 栈托管 SwiftUI 页面：

~~~swift
try assembly.destinations.registerSwiftUI(
    identifier: "app.swiftui",
    routeType: AppRoute.self
) { _, _ in
    AppSwiftUIView()
}
~~~

纯 SwiftUI App 使用 `TFYSwiftSwiftUINavigationDriver` 和 `TFYSwiftSwiftUIRouterHost`。接入方应提供自己的 `errorContent`；组件不内置产品化错误视觉。

## 11. 可观测性与测试

~~~swift
let history = TFYSwiftRouteHistory(capacity: 200)
assembly.events.add(history)
~~~

Demo 的“事件”Tab 展示 created、resolved、presented、completed、failed 等真实事件；“导航栈”Tab 展示每个 Scope 的真实地址栈。

~~~swift
let router = TFYSwiftTestRouter()
router.provide(String.self) { "selected" }
let result = try await router.openTyped(
    PickerRoute(),
    input: ["A", "B"],
    scope: "test"
)
assert(result == "selected")
assert(router.invocations.last?.scope == "test")
~~~

## 12. Demo 0→1 操作顺序

1. “开始”点击“打开详情”，确认普通 Push。
2. 点击“自动跨 Tab”，确认组件自动选择“演练”并 Push。
3. 返回“开始”，点击“等待页面结果”，选择一项并确认调用方反馈。
4. 点击“双向会话”，确认命令、页面事件和最终输出。
5. 在“演练”操作全部呈现方式、singleTop/singleTask、拦截和 Deep Link。
6. 操作超时、主动取消、注册事务、组件服务和导航快照。
7. 在“导航栈”检查四个 Scope，在“事件”核对事务生命周期。

~~~text
ClassDemo/
├─ App/TFYDemoAppCoordinator.swift
├─ Models/TFYDemoRoutes.swift
└─ UI/
   ├─ TFYDemoMenuViewControllers.swift
   ├─ TFYDemoDestinationViewControllers.swift
   └─ TFYDemoInspectorViewControllers.swift
~~~

## 13. 接入检查

- Scene 强持有 Flow、Assembly、TabBar 和导航控制器。
- Route 只保存稳定地址数据，大模型通过 Input 传递。
- Tab 应用使用 TabBar Assembly，不在业务页面手动改 `selectedIndex`。
- 每个 Scope 唯一，目标工厂在第一次打开前完成登记。
- Result/Session 明确 finish、cancel、timeout 和 UI 关闭策略。
- 外部 URL 先校验，再解析，并继续经过拦截器。
- 仅持久化允许恢复且不含敏感数据的 Route。
- 先跑单元测试和 build-for-testing，再用真机验证转场、Deep Link 和多窗口。

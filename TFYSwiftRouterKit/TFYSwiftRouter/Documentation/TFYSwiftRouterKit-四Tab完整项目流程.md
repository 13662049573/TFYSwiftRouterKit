# TFYSwiftRouterKit TabBar 路由与 Demo 0→1 流程

本文说明组件级 TabBar 路由的装配方式，以及仓库 Demo 如何从空目录建立“开始、演练、导航栈、事件”四个 Tab。

## 1. 为什么 TabBar 必须进入组件

只有 Scoped Driver 时，Scope 能找到目标导航栈，但不会改变 `UITabBarController.selectedIndex`。如果每个业务模块都自行执行“选 Tab + open”，映射会散落在 App 和页面里。

`TFYSwiftTabBarNavigationDriver` 把这条规则收进组件：

1. Scope 与 Tab 索引只登记一次。
2. `present`、`activate`、`back`、`backToRoot`、`dismiss`、`dismissAll` 都先选择目标 Tab。
3. 实际导航仍交给 `TFYSwiftScopedNavigationDriver`。
4. 查询栈和导航检查点不产生额外选中副作用。

## 2. 建立四个 Tab

~~~swift
let tabBarController = UITabBarController()

let start = UINavigationController()
let playground = UINavigationController()
let stack = UINavigationController()
let timeline = UINavigationController()

let assembly = try TFYSwiftRouterAssembly(
    tabBarController: tabBarController,
    tabs: [
        TFYSwiftTabBarScope(scope: "demo.start", navigationController: start),
        TFYSwiftTabBarScope(scope: "demo.playground", navigationController: playground),
        TFYSwiftTabBarScope(scope: "demo.stack", navigationController: stack),
        TFYSwiftTabBarScope(scope: "demo.timeline", navigationController: timeline)
    ],
    initialScope: "demo.start"
)
~~~

Assembly 会：

- 把四个导航控制器安装到 TabBar。
- 为每个 Scope 创建 `TFYSwiftUIKitNavigationDriver`。
- 拒绝重复 Scope 和重复索引。
- 创建 TabBar Driver，并将它注入核心 Router。
- 公开 `navigationDrivers`，供宿主配置 custom/newWindow。

## 3. 页面声明 RouteConfiguration

~~~swift
struct StartRoute: Hashable, Codable, Sendable, TFYSwiftRoute {}

final class StartViewController: UIViewController {
    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<StartRoute> {
        .init(
            rootScope: "demo.start",
            rootRoute: StartRoute(),
            destinationID: "demo.root.start"
        ) { _, _ in
            StartViewController()
        }
    }
}

let roots = try assembly.registerConfigurations([
    StartViewController.routeConfiguration(),
    PlaygroundViewController.routeConfiguration(),
    StackViewController.routeConfiguration(),
    TimelineViewController.routeConfiguration(),
    DetailViewController.routeConfiguration()
])
~~~

Route、目标标识、页面工厂和可选根 Scope 在同一份配置中关联。页面不持有 Router；AppCoordinator 也不创建具体页面，只安装配置目录。

## 4. 安装根路由

~~~swift
for root in roots {
    try await assembly.router.open(
        root.route,
        presentation: .root(animated: false),
        source: .programmatic,
        scope: root.scope
    )
}
try assembly.tabBarDriver?.select("demo.start")
~~~

顺序固定为：创建容器 → 注册 Route/工厂 → 安装各 Scope 根路由 → 选择初始 Tab → 处理冷启动外部链接。

## 5. 自动跨 Tab

~~~swift
try await assembly.router.open(
    DemoRoute.detail(title: "跨 Tab 已完成"),
    presentation: .push(),
    scope: "demo.playground"
)
~~~

调用方不读取 Tab 索引，也不修改 `selectedIndex`。Tab 顺序变化时，只调整装配数组即可。

只选 Tab：

~~~swift
try assembly.tabBarDriver?.select("demo.timeline")
~~~

## 6. 宿主呈现能力

~~~swift
for driver in assembly.navigationDrivers.values {
    driver.registerCustomPresentation(identifier: "demo.flip") {
        source, destination, _ in
        destination.modalTransitionStyle = .flipHorizontal
        source.present(destination, animated: true)
    }

    driver.registerNewWindowPresentation { source, destination, _ in
        // Window/Scene 的创建和所有权由宿主决定。
    }
}
~~~

组件只提供扩展点，不擅自创建系统 Scene。

## 7. Demo 信息架构

### 开始

按顺序展示最短主链路：

1. Route → Resolver → Destination → Push。
2. 指定 Scope 自动跨 Tab。
3. 强类型 Input/Output。
4. Route Event 时间线。
5. 双向 Session、Deep Link 和 SwiftUI destination。

### 演练

集中展示可操作能力：

- automatic/push、sheet、fullScreen、replace、root。
- custom 与 newWindow 宿主扩展。
- singleTop 与 singleTask。
- Interceptor redirect 与 Deep Link。
- 强类型结果、Session、back/backToRoot/dismiss/dismissAll。
- timeout、主动 cancel。
- Route 注册事务回滚。
- 组件服务注册、解析、注销。
- 四 Scope 导航快照编码与原子恢复。

### 导航栈

读取 `router.navigationRoutes(scope:)`，显示四个 Scope 的真实栈，并可以选择对应 Tab 或执行回退操作。

### 事件

使用 `TFYSwiftRouteHistory` 展示 Router 生命周期事件，并支持清空诊断历史。它不是业务持久化存储。

## 8. Result 与 Session 的关闭顺序

页面只负责 `finish` 或 `cancel` 通信。调用方拿到结果后：

1. 调用 Router `dismiss`。
2. 等待 UIKit 真实模态层级消失。
3. 从当前 Tab 的可见控制器显示结果反馈。

这样不会在页面自我关闭动画期间竞争展示下一弹层。

## 9. 恢复范围

Demo 的四个根 Route 与详情 Route 分别遵守 Codable，并以稳定 identifier 登记。快照包含四个 Scope 的 root/push Route，不包含 Sheet、Input、Session、选中 Tab 和窗口。

恢复时 TabBar Driver 为每个 Scope 提供导航检查点。失败时恢复原页面实例；成功后 Demo 主动选回发起恢复的 Tab。

## 10. 验证矩阵

| 层级 | 验证内容 |
|---|---|
| SwiftPM 单测 | Core、Session、缓冲、恢复、Testing |
| UIKit 单测 | Tab 映射、自动选择、重复 Scope、交互关闭生命周期 |
| build-for-testing | App、Unit Tests、UI Tests 的 iOS 编译 |
| 真机 UI | 四 Tab 首屏、跨 Tab、Typed Result、Session、事件时间线 |
| 人工视觉 | 首屏层级、滚动、Tab 可达性、文字不重叠 |

Demo 源码入口：

- `ClassDemo/App/TFYDemoAppCoordinator.swift`
- `ClassDemo/Models/TFYDemoRoutes.swift`
- `ClassDemo/Module/TFYDemoRouteCatalog.swift`
- `ClassDemo/UI/TFYDemoMenuViewControllers.swift`
- `ClassDemo/UI/TFYDemoDestinationViewControllers.swift`
- `ClassDemo/UI/TFYDemoInspectorViewControllers.swift`

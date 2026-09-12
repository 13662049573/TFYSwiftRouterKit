# TFYSwiftRouterKit 四 Tab 完整项目流程

本文对应 **TFYSwiftRouterKit 2.0.0** 与仓库 `ClassDmoe` 示例，说明 Home、Product、Cart、Profile 四个组件怎样完成装配、跨 Tab 导航、双向会话和状态恢复。完整发布说明见仓库根目录 [CHANGELOG](../../../CHANGELOG.md)。

## 1. 依赖方向

```text
App Shell
  ├─ 创建 UITabBarController / UINavigationController
  ├─ 持有 Router Assembly 与 Service Registry
  └─ 选择 Feature Module 实现

Feature Interface
  ├─ Route 与 Input/Command/Event/Output
  └─ 跨组件 Service Protocol

Feature Implementation
  ├─ Resolver / Destination Factory
  └─ UIViewController / SwiftUI View
```

App 壳不初始化业务控制器；组件之间只依赖 Interface 中的 Route 和服务协议。

## 2. 建立独立 Scope

每个 Tab 使用稳定且唯一的 `TFYSwiftNavigationScopeID`。先用 Home 栈创建 Assembly，再注册其他栈：

```swift
let assembly = TFYSwiftRouterAssembly(
    navigationController: homeNavigation,
    initialScope: "app.home"
)

try assembly.register(navigationController: productNavigation, for: "app.products")
try assembly.register(navigationController: cartNavigation, for: "app.cart")
try assembly.register(navigationController: profileNavigation, for: "app.profile")
```

重复 Scope 会抛错，不会静默替换已有 Driver。

## 3. 注册组件和根路由

每个组件通过 `TFYSwiftUIKitComponentModule` 输出类型擦除的根地址，页面工厂留在 Implementation Target：

```swift
struct ProductModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: "app.products",
        route: ProductRoute.root
    )

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        // 注册 ProductRoute resolver 与 product.* 页面工厂。
    }
}
```

批量注册会先检查重复 Scope 和缺失 Driver，再以事务方式提交 Route 与 Destination。任一组件失败时整批回滚。

```swift
let roots = try assembly.registerComponents([
    HomeModule(), ProductModule(), CartModule(), ProfileModule()
])

for root in roots {
    try await assembly.router.open(
        root.route,
        presentation: .root(animated: false),
        source: .programmatic,
        scope: root.scope
    )
}
```

启动顺序应为：创建容器 → 注册 Scope → 注册组件 → 安装根 Route → 处理初始 Deep Link。

## 4. 跨 Tab 导航

App 层 Navigator 先切换 Tab，再把 Route 交给目标 Scope。业务组件不直接持有其他组件的控制器：

```swift
tabBarController.selectedIndex = cartTabIndex
try await assembly.router.open(
    CartRoute.summary,
    presentation: .push(),
    scope: "app.cart"
)
```

## 5. 完整模型和双向会话

Route 只保存稳定 ID，大模型通过瞬时 Input 传递：

```swift
let session = router.openSession(
    ProductRoute.detail(id: product.id),
    input: product,
    scope: "app.products",
    commands: ProductCommand.self,
    events: ProductEvent.self,
    expecting: ProductOutput.self
)

let eventTask = session.observeEvents(handle)
try session.send(.refresh)
let output = try await session.value(timeout: 15)
await eventTask.value
```

页面被 Pop、Dismiss、Replace、Root 替换、任务取消或超时时，框架会结束 Result、Command 和 Event 生命周期。

## 6. 跨组件服务

不展示页面的能力通过 Interface 协议调用：

```swift
let cart = try services.resolve(ComponentKeys.cart)
let snapshot = try await cart.add(product)
```

Service Registry 由 Scene/App Composition Root 持有，不使用全局单例。

## 7. Deep Link

URL 先经过 Scheme、Host、凭据和长度校验，再由带优先级的 Parser 映射为 Route：

```swift
await deepLinks.add(ProductDeepLinkParser(), priority: 100)
try await router.open(request, using: deepLinks, scope: "app.products")
```

外部路由仍会经过 Interceptor、Resolver、Deduplication 和 Observer。

## 8. 状态恢复

只注册允许落盘且不含敏感信息的 Codable Route：

```swift
try restorationRegistry.register(ProductRoute.self, identifier: "product.route.v1")
let coordinator = TFYSwiftRestorationCoordinator(
    registry: restorationRegistry,
    router: assembly.router
)

let snapshot = try coordinator.makeSnapshot(
    scopes: ["app.home", "app.products", "app.cart", "app.profile"]
)
try await coordinator.restore(snapshot)
```

快照包含每个 Scope 的根页面和 Push 路径；Sheet、Input、Command、Event、Output 与 Service 实例不会持久化。

## 9. 测试清单

- 四个 Scope 不重复且各有一个根 Route。
- 组件批量注册失败后 Registry 没有残留。
- 四个导航栈互不修改。
- 页面移除后等待结果的任务收到取消。
- Deep Link 不能绕过 Interceptor。
- 快照版本不兼容或 Payload 损坏时恢复失败。
- `TFYSwiftTestRouter.invocations` 中的 source、scope、metadata 和 deduplication 正确。

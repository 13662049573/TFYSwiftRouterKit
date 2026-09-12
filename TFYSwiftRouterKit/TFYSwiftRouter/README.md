# TFYSwiftRouter

`TFYSwiftRouter` 是一套 iOS 16+、Swift Concurrency First 的组件路由运行时。它将内部强类型 Route、完整模型输入、双向命令/事件、外部链接、拦截器、页面解析、展示方式、异步返回值、跨组件服务和可观测性接入同一条链路，同时不使用全局单例。

> 从多 Target 拆分、组件依赖规则到模型传递、点击回调、页面方法触发和跨组件调用，请阅读 [完整中文使用指南](Documentation/TFYSwiftRouterKit-完整使用指南.md)。
>
> 四个 Tab、四个独立路由容器、跨 Tab/跨组件调用和完整结算链路，请阅读 [四 Tab 完整项目流程](Documentation/TFYSwiftRouterKit-四Tab完整项目流程.md)。

## 模块

- `Core`：Route、Registry、Transaction、Interceptor、Router、双向 Session、组件服务、Scope、事件。
- `UIKit`：`UINavigationController` Driver、UIKit/SwiftUI 页面工厂、自定义转场。
- `SwiftUI`：原生 `NavigationStack`/sheet/fullScreen 状态 Driver 与 Router Host。
- `DeepLink`：Scheme/Host/长度/凭据校验与 Parser 链。
- `Restoration`：仅对白名单内的 Codable Route 编解码。
- `Testing`：记录导航意图并注入返回结果的 `TFYSwiftTestRouter`。

仓库根目录提供 `Package.swift`，已拆为 Core/UIKit/SwiftUI/DeepLink/Restoration/Testing 独立 Target，可按需引入；Package 本身零第三方依赖。

## 最小接入

```swift
enum ProductRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case detail(id: String)
}

let assembly = TFYSwiftRouterAssembly(navigationController: navigationController)

try assembly.register(ProductRoute.self) { route, context in
    switch route {
    case .root:
        return ProductViewController()
    case .detail(let id):
        return ProductDetailViewController(productID: id)
    }
}

try await assembly.router.open(
    ProductRoute.detail(id: "1001"),
    presentation: .push(),
    deduplication: .singleTop
)
```

Route 只表达业务目的；页面类型、URL 和 Presentation 不进入 Route。

## 独立组件根页面

Tab 根页面也通过路由地址安装，App 壳不应直接初始化业务控制器。每个 UIKit 组件实现 `TFYSwiftUIKitComponentModule`：

```swift
struct ProductModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: "app.product",
        route: ProductRoute.root
    )

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        // Product 的 Resolver 和 UIViewController Factory 全部留在组件内部。
    }
}

let modules: [any TFYSwiftUIKitComponentModule] = [HomeModule(), ProductModule()]
let roots = try assembly.registerComponents(modules)
for root in roots {
    try await assembly.router.open(
        root.route,
        presentation: .root(animated: false),
        scope: root.scope
    )
}
```

`TFYSwiftRootRouteRegistration` 会擦除具体 Route 类型，只保留 Scope 和路由意图；`TFYSwiftUIKitComponentModule` 则把控制器工厂留在组件 Implementation Target 内。

## 带返回值

```swift
let value: String = try await router.open(
    DemoRoute.selector,
    presentation: .sheet(),
    expecting: String.self
)
```

目标页面通过工厂收到的 `TFYSwiftDestinationContext.result` 完成：

```swift
context.result?.finish(with: "selected")
```

Result 内建类型检查、单次完成保护和调用方 Task 取消处理。

## 完整模型与双向会话

```swift
let session = router.openSession(
    ProductRoute.detail(id: product.id),
    input: product,
    presentation: .push(),
    commands: ProductCommand.self,
    events: ProductEvent.self,
    expecting: ProductOutput.self
)

try session.send(.refresh)              // 调用方触发页面方法
for await event in session.events { }   // 页面多次点击回调
session.observeEvents { event in }      // 也可使用闭包风格（与上一行二选一）
let output = try await session.value    // 页面最终结果
```

页面使用 `try context.input()` 读取模型、`try context.commands()` 接收命令、`try context.send(...)` 发送事件、`context.result?.finish(with:)` 返回最终值。Route 中无需保存闭包或大型模型。

## Deep Link

先配置输入边界，再把 URL 映射为强类型 Route：

```swift
let engine = TFYSwiftDeepLinkEngine(
    policy: .app(scheme: "myapp", universalLinkHosts: ["example.com"])
)
await engine.add(ProductDeepLinkParser())

try await router.open(
    TFYSwiftDeepLinkRequest(url: url),
    using: engine
)
```

外部输入进入 Router 后仍会经过完整的 interceptor、resolver、deduplication 和 observer 链路。

## 生产接入原则

1. 在 Scene/Flow Composition Root 创建 `TFYSwiftRouterAssembly`，不要增加 `shared`。
2. 每个 Feature 自己声明 Route Interface，由 Implementation 的 `TFYSwiftUIKitComponentModule` 注册页面实现。
3. 为鉴权、权限、Feature Flag 等分别实现小型拦截器，用 priority 排序。
4. 仅将明确允许落盘且不含敏感值的 Route 注册到 Restoration Registry。
5. 用 `TFYSwiftRouting` 注入业务对象，单元测试替换为 `TFYSwiftTestRouter`。
6. 多 Tab/Flow 调用 `assembly.register(navigationController:for:)` 建立独立 Scope 栈。

完整可运行示例位于 `ClassDmoe`：Home、Product、Cart、Profile 四个 Tab 分别拥有独立 Scope/导航栈，覆盖路由注册、跨 Tab 跳转、完整模型、双向 Session、服务协议、嵌套路由结果、登录挂起恢复、Deep Link 和 Route Inspector。

# TFYSwiftRouterKit 完整使用指南

## 1. 它解决什么问题

TFYSwiftRouterKit 将“我要去哪里”与“页面怎样创建、怎样展示”分开，并把鉴权、Deep Link、回调、跨组件方法调用和导航观测统一到一条运行链路中。

核心原则：

- Feature Interface 只暴露 Route、输入模型、命令、事件、输出以及服务协议。
- Feature Implementation 持有 UIViewController/SwiftUI View、网络与存储实现。
- 调用组件不 import 目标组件的 Implementation，也不持有目标页面类。
- Route 中不放 UIViewController、View、闭包或大型可变对象。
- App/Scene Composition Root 是唯一装配点；库内没有全局 `shared`。
- Tab/Flow 根页面也必须声明为 Route，由组件自己的工厂创建，App 壳不直接初始化业务控制器。

### 相对 NaviCore 方案的保留与增强

本实现保留 NaviCore 的 Route → Guard/Interceptor → Resolver → Transition → Lifecycle 主链路，并针对真实组件化工程补充：

- 将一个源码目录改为真正的 Swift Package 多 Target 依赖边界。
- 将“路由标识”和“临时完整模型”分离，避免大型模型破坏 Route 去重与恢复。
- 将单次 completion 扩展为 Command、Event、Output 三类强类型通信。
- 增加协议键控的组件服务注册表，区分页面导航和无页面方法调用。
- 增加 `TFYSwiftUIKitComponentModule` 与根路由注册，解决组件根页面被 App 壳直接引用的问题。
- UIKit 与 SwiftUI 共用 UI 无关的 DestinationContext 和会话协议。
- 对输入、命令、事件、结果、服务缺失提供独立错误；取消时统一关闭全部通道。

## 2. 模块与依赖方向

Swift Package 已拆分为可独立引用的 Target：

| 模块 | 职责 | 依赖 |
| --- | --- | --- |
| `TFYSwiftRouterCore` | Route、Router、根路由地址、会话、拦截器、服务协议、观测 | Foundation |
| `TFYSwiftRouterUIKit` | UIKit 页面工厂、导航 Driver、组件 Module 注册协议 | Core、UIKit |
| `TFYSwiftRouterSwiftUI` | 原生 NavigationStack Driver 与 Host | Core、SwiftUI |
| `TFYSwiftRouterDeepLink` | 外部 URL 安全校验和 Parser 链 | Core |
| `TFYSwiftRouterRestoration` | 白名单 Route 状态恢复 | Core |
| `TFYSwiftRouterTesting` | 记录路由意图、注入结果 | Core |
| `TFYSwiftRouterKit` | 一次性导出以上模块的便捷入口 | 全部 |

推荐真实业务组件结构：

```text
ProductInterface ───────► TFYSwiftRouterCore
      ▲
      │
ProductImplementation ─► ProductInterface + TFYSwiftRouterUIKit

HomeImplementation ────► ProductInterface + CartInterface
CartImplementation ────► CartInterface

AppCompositionRoot ────► 各 Implementation 的 Module Registrar
                                  │
                                  └── 控制器 Factory 留在组件内部
```

只声明跳转协议的组件可以仅依赖 `TFYSwiftRouterCore`，不会被 UIKit、SwiftUI、Deep Link 或目标组件实现传染。

## 3. 安装

在 Xcode 的 Package Dependencies 中加入仓库。按需选择产品：

```swift
import TFYSwiftRouterCore       // 业务 Interface、非 UI 组件
import TFYSwiftRouterUIKit      // UIKit App
import TFYSwiftRouterSwiftUI    // 纯 SwiftUI App
import TFYSwiftRouterDeepLink   // 需要外链时
```

小型应用也可以直接：

```swift
import TFYSwiftRouterKit
```

支持 iOS 16+、Swift 6，零第三方依赖。

## 4. 最小 UIKit 组件装配

### 4.1 Interface Target 声明 Route

根页面与普通页面使用同一种强类型 Route：

```swift
public enum ProductRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case detail(id: String)
    case reviews(productID: String)
}
```

Interface Target 只依赖 `TFYSwiftRouterCore`，不出现 `UIViewController`。

### 4.2 Implementation Target 提供 Module Registrar

```swift
@MainActor
public struct ProductModule: TFYSwiftUIKitComponentModule {
    public let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYSwiftNavigationScopeID("app.product"),
        route: ProductRoute.root
    )

    public init() {}

    public func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.routes.register(ProductRoute.self) { route, _ in
            switch route {
            case .root:
                TFYSwiftDestinationDescriptor(identifier: "product.root")
            case .detail:
                TFYSwiftDestinationDescriptor(identifier: "product.detail")
            case .reviews:
                TFYSwiftDestinationDescriptor(identifier: "product.reviews")
            }
        }

        try assembly.destinations.register(
            identifier: "product.root",
            routeType: ProductRoute.self
        ) { _, _ in
            ProductViewController()
        }

        try assembly.destinations.register(
            identifier: "product.detail",
            routeType: ProductRoute.self
        ) { route, context in
            guard case .detail(let id) = route else {
                throw TFYSwiftRouteError.invalidPayload("ProductRoute 与页面不匹配")
            }
            return ProductDetailViewController(productID: id, context: context)
        }

        try assembly.destinations.register(
            identifier: "product.reviews",
            routeType: ProductRoute.self
        ) { route, _ in
            guard case .reviews(let productID) = route else {
                throw TFYSwiftRouteError.invalidPayload("ProductRoute 与页面不匹配")
            }
            return ReviewViewController(productID: productID)
        }
    }
}
```

具体控制器只存在于 ProductImplementation 的 Destination Factory 中。

### 4.3 App 壳注册组件并安装根路由

```swift
@MainActor
final class AppCompositionRoot {
    let assembly: TFYSwiftRouterAssembly
    private let roots: [TFYSwiftRootRouteRegistration]

    init(navigationController: UINavigationController) throws {
        assembly = TFYSwiftRouterAssembly(
            navigationController: navigationController,
            initialScope: "app.product"
        )

        let modules: [any TFYSwiftUIKitComponentModule] = [
            ProductModule()
        ]
        roots = try assembly.registerComponents(modules)
    }

    func start() async throws {
        for root in roots {
            try await assembly.router.open(
                root.route,
                presentation: .root(animated: false),
                source: .programmatic,
                scope: root.scope
            )
        }
    }
}
```

App 壳知道 `ProductModule` 这个装配入口，但不知道也不持有 `ProductViewController`。`registerComponents` 还会在注册页面前拒绝重复的根 Scope。

注册顺序必须保持为：创建导航容器 → 注册 Scope Driver → 注册 Component Module → 安装根 Route → 处理初始 Deep Link。`rootRegistration.scope` 必须与 `assembly.register(navigationController:for:)` 使用的 Scope 完全一致，否则安装根页面时会抛出 `scopeUnavailable`。

### 4.4 普通页面调用

任何调用方只需要目标组件的 Interface：

```swift
try await router.open(
    ProductRoute.detail(id: "SKU-1001"),
    presentation: .push(),
    scope: "app.product"
)
```

## 5. 传值：何时放 Route，何时传完整模型

### 5.1 稳定的小参数放 Route

ID、枚举、筛选条件等参与去重、Deep Link 或恢复的稳定值适合放 Route：

```swift
enum OrderRoute: Hashable, Sendable, TFYSwiftRoute {
    case detail(orderID: String)
}
```

### 5.2 完整模型作为临时 Input

大型模型、不可 Hashable 的模型、仅本次页面使用的数据，不要为迁就 Route 强行实现 Hashable：

```swift
public struct ProductPageInput: Sendable {
    public let product: Product
    public let recommendationIDs: [String]
    public let entryName: String
}

try await router.open(
    ProductRoute.detail(id: input.product.id),
    input: input,
    presentation: .push()
)
```

目标页面在工厂中强类型读取：

```swift
try destinations.register(
    identifier: "product.detail",
    routeType: ProductRoute.self
) { route, context in
    let input: ProductPageInput = try context.input()
    return ProductViewController(route: route, input: input)
}
```

输入只存在于本次 transaction，不参与 Hash、Deep Link、日志内容和状态恢复，避免把隐私模型意外序列化。

## 6. 三种返回方式

### 6.1 无返回值

```swift
try await router.open(SettingsRoute.home)
```

`open` 在目标页面成功展示后返回。

### 6.2 一个最终结果

调用方：

```swift
let address: Address = try await router.open(
    AddressRoute.selector,
    presentation: .sheet(),
    expecting: Address.self
)
```

页面：

```swift
context.result?.finish(with: selectedAddress)
```

每次路由只接受一次最终结果。返回类型错误、关闭页面或调用 Task 被取消时会抛出明确错误，不会重复恢复 continuation。

### 6.3 连续点击回调 + 方法触发 + 最终结果

这是完整的双向 Session，适合播放器、编辑器、商品详情等长生命周期页面。

先在目标组件 Interface 中定义通信契约：

```swift
public enum ProductCommand: Sendable {
    case refresh
    case updateBadge(Int)
}

public enum ProductEvent: Sendable {
    case favoriteTapped(productID: String)
    case shareTapped(productID: String)
}

public struct ProductOutput: Sendable {
    public let didPurchase: Bool
}
```

调用方创建会话：

```swift
let session = router.openSession(
    ProductRoute.detail(id: product.id),
    input: ProductPageInput(product: product),
    presentation: .push(),
    commands: ProductCommand.self,
    events: ProductEvent.self,
    expecting: ProductOutput.self
)
```

监听任意次数的页面事件：

```swift
let eventTask = Task { @MainActor in
    for await event in session.events {
        switch event {
        case .favoriteTapped(let id):
            analytics.track("favorite", id: id)
        case .shareTapped(let id):
            coordinator.share(productID: id)
        }
    }
}
```

偏好闭包写法时可使用等价的便捷 API（同一个会话二选一，不要再同时遍历 `events`）：

```swift
let eventTask = session.observeEvents { event in
    analytics.handle(event)
}
```

页面打开后，上游仍可触发目标页面方法：

```swift
try session.send(.refresh)
try session.send(.updateBadge(3))
```

页面接收命令：

```swift
let commands: AsyncStream<ProductCommand> = try context.commands()

for await command in commands {
    switch command {
    case .refresh:
        await viewModel.reload()
    case .updateBadge(let value):
        viewModel.badge = value
    }
}
```

页面把按钮点击发送回调用组件：

```swift
try context.send(ProductEvent.favoriteTapped(productID: product.id))
```

页面完成后发送一次最终值：

```swift
context.result?.finish(with: ProductOutput(didPurchase: true))
```

调用方等待完成，并让事件监听自然结束：

```swift
let output = try await session.value
await eventTask.value
```

不再需要会话时调用 `session.cancel()`；命令流、事件流和最终结果会一起结束。

## 7. 多组件跨组件关联

路由用于“展示一个页面”，服务协议用于“不展示页面但调用方法”。不要为了调用一个数据方法打开隐藏页面，也不要把页面控制器当服务。

### 7.1 CartInterface 声明协议

```swift
public protocol CartServicing: TFYSwiftComponentService {
    func add(productID: String) async throws -> CartSnapshot
}

public enum CartComponentKeys {
    public static let service = TFYSwiftComponentServiceKey<any CartServicing>()
}
```

### 7.2 CartImplementation 实现协议

```swift
public actor CartService: CartServicing {
    public func add(productID: String) async throws -> CartSnapshot {
        // repository/network implementation
    }
}
```

### 7.3 App 根部注册实现

```swift
@MainActor
func registerServices() throws {
    let service: any CartServicing = CartService()
    try componentServices.register(
        service,
        for: CartComponentKeys.service
    )
}
```

`componentServices` 由 App 持有并注入，不要创建全局单例。

### 7.4 Product 调用 Cart 方法

```swift
let cart = try componentServices.resolve(CartComponentKeys.service)
let snapshot = try await cart.add(productID: product.id)
```

Product 仅依赖 CartInterface。替换 CartImplementation、做 A/B 实验或单测时只需注册另一实现。

## 8. 一个完整的 Home → Product → Cart 流程

```text
Home 点击商品
  └─ Router.openSession(ProductRoute, ProductInput)
       ├─ Product 页面创建并读取模型
       ├─ Home → ProductCommand.refresh → Product 执行 reload()
       ├─ Product 收藏按钮 → ProductEvent.favoriteTapped → Home 收到回调
       ├─ Product → CartServicing.add() → CartImplementation
       └─ Product 完成 → ProductOutput → Home
```

整个过程没有以下依赖：

- Home 不引用 `ProductViewController`。
- Product 不引用 `CartService` 实现。
- Route 不持有闭包。
- UIKit 不进入 Core。
- Deep Link 不直接实例化页面。

## 9. 多 Tab、多 Flow 与 Scope

每个独立导航栈使用一个 Scope。App 壳只创建平台导航容器，不创建组件根页面：

```swift
let homeScope: TFYSwiftNavigationScopeID = "app.home"
let productScope: TFYSwiftNavigationScopeID = "app.product"

let homeNavigation = UINavigationController()
let productNavigation = UINavigationController()

let assembly = TFYSwiftRouterAssembly(
    navigationController: homeNavigation,
    initialScope: homeScope
)
assembly.register(
    navigationController: productNavigation,
    for: productScope
)

tabBarController.viewControllers = [homeNavigation, productNavigation]
```

然后注册独立组件，并通过根路由安装每个栈的首页：

```swift
let modules: [any TFYSwiftUIKitComponentModule] = [
    HomeModule(),
    ProductModule()
]
let roots = try assembly.registerComponents(modules)

for root in roots {
    try await assembly.router.open(
        root.route,
        presentation: .root(animated: false),
        source: .programmatic,
        scope: root.scope
    )
}
```

跨 Tab 时，应用级 Navigator 只负责“选中 Tab + 指定 Scope 路由”：

```swift
tabBarController.selectedIndex = 1
try await router.open(
    ProductRoute.detail(id: "1"),
    presentation: .push(),
    scope: productScope
)
```

路由注册表和拦截器可以共享，但页面栈、back、dismiss 和去重判断按 Scope 隔离。不要在 AppCoordinator 中用 `setViewControllers([FeatureViewController(...)])` 安装业务根页面，否则壳工程会重新依赖组件实现细节。

## 10. SwiftUI 接入

注册 View：

```swift
let destinations = TFYSwiftSwiftUIDestinationRegistry()
try destinations.register(
    identifier: "product.detail",
    routeType: ProductRoute.self
) { route, context in
    ProductView(route: route, context: context)
}

let driver = TFYSwiftSwiftUINavigationDriver(destinations: destinations)
let router = TFYSwiftRouter(driver: driver)
```

在 Scene 中承载：

```swift
TFYSwiftSwiftUIRouterHost(driver: driver) {
    HomeView(router: router)
}
```

Input、Command、Event 和 Output 与 UIKit 使用相同 Core API。

## 11. Deep Link

外部 URL 必须先通过 Policy 和 Parser，再转换为内部强类型 Route：

```swift
let engine = TFYSwiftDeepLinkEngine(
    policy: .app(
        scheme: "myapp",
        universalLinkHosts: ["example.com"]
    )
)
await engine.add(ProductDeepLinkParser())

try await router.open(
    TFYSwiftDeepLinkRequest(url: url),
    using: engine
)
```

Parser 只解析 ID 等外部可表达值。完整内存模型不能来自 URL，应在 resolver/业务服务中按 ID 加载。

## 12. 拦截、重定向与恢复

- 鉴权/权限：返回 `.suspend`，完成登录或授权后恢复原 transaction。
- 旧路由迁移：返回 `.redirect(newRoute)`。
- 拒绝：返回 `.reject(error)`。
- 状态恢复：只向 `TFYSwiftRestorationRegistry` 注册明确允许 Codable 的 Route。
- Input、命令、事件和服务实例不会落盘，恢复后应根据 Route ID 重建。

## 13. 去重注意事项

`.singleTop`、`.singleTask` 在复用已有页面时不会创建新的通信会话，因此不要对需要新结果的 `openSession` 使用页面复用策略。框架会明确报错，避免调用方永久等待。

普通无返回导航可以安全使用：

```swift
try await router.open(
    ProductRoute.detail(id: "same"),
    presentation: .push(),
    deduplication: .singleTop
)
```

## 14. 测试

业务对象依赖 `TFYSwiftRouting`，测试时替换：

```swift
let router = TFYSwiftTestRouter()
router.provide(Address.self) { fixtureAddress }

let sut = CheckoutViewModel(router: router)
await sut.selectAddress()

XCTAssertEqual(router.actions.count, 1)
```

建议覆盖：

- Route 注册与重复注册。
- 输入模型类型匹配和错误类型。
- Command、Event、Output 的完整生命周期。
- 拦截器顺序、挂起、拒绝与 redirect 上限。
- Deep Link scheme/host/长度/凭据校验。
- Scope 隔离和去重。
- Component Module 根 Scope 唯一性，以及根 Route 是否真正进入对应导航栈。
- 服务协议的注册、替换与缺失错误。

## 15. 生命周期和常见错误

| 场景 | 行为 |
| --- | --- |
| 页面正常完成 | `finish(with:)` 恢复最终结果并关闭双向流 |
| Sheet 手势关闭 | 会话抛出 `cancelled` |
| 页面释放且未完成 | UIKit 生命周期令牌取消会话 |
| 调用 Task 取消 | pending result 被取消，流结束 |
| 重复 finish | 后续调用被忽略 |
| 输入/命令/事件/结果类型错误 | 抛出对应 type mismatch |
| 服务未注册 | 抛出 `serviceNotRegistered` |
| 两个组件声明相同根 Scope | `registerComponents` 抛出 `duplicateRegistration` |

页面拥有接收 Command 的 Task，并应在页面释放时取消；`AsyncStream` 结束也会让循环自然退出。

## 16. 推荐的组件落地清单

1. 每个业务域拆 `FeatureInterface` 与 `FeatureImplementation`。
2. Interface 只依赖 Core，声明包含 `.root` 的 Route，以及 Input/Command/Event/Output/Service Protocol。
3. Implementation 实现 `TFYSwiftUIKitComponentModule`，公开 `TFYSwiftRootRouteRegistration`。
4. Implementation 在 `register(in:)` 内注册 resolver 和所有页面工厂，控制器不离开组件。
5. App Composition Root 创建 Router、Service Registry、各 Scope 导航容器并调用 `registerComponents`。
6. App 启动时遍历根路由注册，使用 `.root(animated: false)` 安装每个组件首页。
7. 页面跳转用 Route；无页面业务调用用 Service Protocol；长生命周期页面交互用 Session。
8. Deep Link 只负责外部输入到 Route，不越过 Registry 创建页面。
9. 用 Observer/Inspector 记录 transaction，不在 Route 中记录隐私模型。
10. 每个组件提供注册测试、根路由测试和契约测试。

## 17. 仓库内可运行示例

Demo 已升级为 Home、Product、Cart、Profile 四 Tab 完整项目。每个 Tab 拥有独立 Navigation Scope；四个根页面全部由组件 Module 注册并通过 Router 安装，AppCoordinator 不创建业务控制器。详细工程说明见 [四 Tab 完整项目流程](TFYSwiftRouterKit-四Tab完整项目流程.md)。

启动 Demo 后重点查看：

- Home → Product：完整模型、Command、Event、Output 双向 Session。
- Product → Cart：服务协议调用后跨 Tab 定位。
- Cart Checkout：Input、登录 suspend/resume、优惠券嵌套路由、Output。
- Profile：订单鉴权、设置 Sheet、主题选择结果和跨组件商品 Session。
- Deep Link 自动定位 Product/Profile/Cart Tab，以及全局 Route Inspector。

对应代码位于 `ClassDmoe/Application`、`ClassDmoe/Features`、`ClassDmoe/Routes` 和 `ClassDmoe/Screens`。

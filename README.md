# TFYSwiftRouterKit

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0"/>
  <img src="https://img.shields.io/badge/iOS-16.0%2B-blue.svg" alt="iOS 16.0+"/>
  <img src="https://img.shields.io/badge/SPM-compatible-brightgreen.svg" alt="Swift Package Manager"/>
  <img src="https://img.shields.io/badge/CocoaPods-compatible-red.svg" alt="CocoaPods"/>
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT"/>
</p>

TFYSwiftRouterKit 是一套面向组件化 iOS 工程的强类型路由工具。它将 Route、页面解析、导航容器、模型传值、双向回调、拦截器、Deep Link、状态恢复和跨组件服务统一到一条可测试的 Swift Concurrency 流程中。

组件根页面也通过 Route 注册和安装，App 壳只管理 `UITabBarController`、`UINavigationController` 与 Scope，不直接初始化业务 `UIViewController`。

## 核心能力

- 强类型 `TFYSwiftRoute`，不依赖字符串反射创建页面。
- 每个 Tab/Flow 使用独立 `TFYSwiftNavigationScopeID` 和导航栈。
- `TFYSwiftUIKitComponentModule` 隔离组件页面工厂。
- 完整模型通过 transient Input 传递，不强迫业务模型实现 `Hashable`。
- Command、Event、Output 双向 Session：方法触发、连续事件、最终结果。
- async/await 单次返回值和统一取消生命周期。
- 鉴权、权限、Feature Flag、重定向等拦截器流水线。
- Deep Link/Universal Link 安全解析后仍进入完整 Router 流程。
- 协议键控的跨组件 Service Registry。
- UIKit、SwiftUI、状态恢复、可观测性和测试替身。
- 无全局 `shared`，便于多 Scene、依赖注入和单元测试。

## 环境要求

- iOS 16.0+
- Swift 6.0+
- Xcode 16 或更高版本
- CocoaPods 1.16+（使用 CocoaPods 时）

## 安装

### CocoaPods

安装完整工具：

```ruby
pod 'TFYSwiftRouterKit', '~> 1.0.0'
```

按需选择模块：

```ruby
pod 'TFYSwiftRouterKit/Core'
pod 'TFYSwiftRouterKit/UIKit'
pod 'TFYSwiftRouterKit/SwiftUI'
pod 'TFYSwiftRouterKit/DeepLink'
pod 'TFYSwiftRouterKit/Restoration'
pod 'TFYSwiftRouterKit/Testing'
```

CocoaPods 使用统一模块名：

```swift
import TFYSwiftRouterKit
```

### Swift Package Manager

在 Xcode 中选择 **File → Add Package Dependencies**，输入：

```text
https://github.com/13662049573/TFYSwiftRouterKit.git
```

或在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(
        url: "https://github.com/13662049573/TFYSwiftRouterKit.git",
        from: "1.0.0"
    )
]
```

按业务 Target 选择产品：

```swift
.target(
    name: "ProductInterface",
    dependencies: [
        .product(name: "TFYSwiftRouterCore", package: "TFYSwiftRouterKit")
    ]
),
.target(
    name: "ProductImplementation",
    dependencies: [
        "ProductInterface",
        .product(name: "TFYSwiftRouterUIKit", package: "TFYSwiftRouterKit")
    ]
)
```

SPM 产品可以分别导入：

```swift
import TFYSwiftRouterCore
import TFYSwiftRouterUIKit
import TFYSwiftRouterSwiftUI
import TFYSwiftRouterDeepLink
import TFYSwiftRouterRestoration
import TFYSwiftRouterTesting
```

小型工程也可以只选择并导入聚合产品：

```swift
import TFYSwiftRouterKit
```

## 模块对应关系

`Package.swift` products、CocoaPods subspecs 与源码目录保持一一对应：

| 源码目录 | SPM Product | CocoaPods Subspec | 内部依赖 |
| --- | --- | --- | --- |
| `Core` | `TFYSwiftRouterCore` | `Core` | Foundation |
| `UIKit` | `TFYSwiftRouterUIKit` | `UIKit` | Core、UIKit、SwiftUI |
| `SwiftUI` | `TFYSwiftRouterSwiftUI` | `SwiftUI` | Core、SwiftUI、Combine |
| `DeepLink` | `TFYSwiftRouterDeepLink` | `DeepLink` | Core、Foundation |
| `Restoration` | `TFYSwiftRouterRestoration` | `Restoration` | Core、Foundation |
| `Testing` | `TFYSwiftRouterTesting` | `Testing` | Core、Foundation |
| `Umbrella` | `TFYSwiftRouterKit` | `Umbrella` | 上述全部模块 |

CocoaPods 默认安装 `Umbrella`，由它依赖并包含全部子模块；选择某个子模块时会自动带入 Core。

## 快速开始

### 1. Interface 声明 Route

```swift
import TFYSwiftRouterCore

public enum ProductRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case detail(id: String)
    case reviews(productID: String)
}
```

Route 只保存稳定 ID 和业务意图，不保存控制器、闭包或大型模型。

### 2. Implementation 注册组件

```swift
import TFYSwiftRouterUIKit

@MainActor
public struct ProductModule: TFYSwiftUIKitComponentModule {
    public let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: "app.product",
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

具体控制器只出现在 ProductImplementation 内部。

### 3. App 壳注册并启动

```swift
@MainActor
final class AppCoordinator {
    let assembly: TFYSwiftRouterAssembly
    private let roots: [TFYSwiftRootRouteRegistration]

    init(productNavigation: UINavigationController) throws {
        assembly = TFYSwiftRouterAssembly(
            navigationController: productNavigation,
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

调用普通页面：

```swift
try await assembly.router.open(
    ProductRoute.detail(id: "SKU-1001"),
    presentation: .push(),
    scope: "app.product"
)
```

推荐启动顺序：

```text
创建导航容器
→ 注册 Scope Driver
→ 注册 Component Module
→ 安装根 Route
→ 处理初始 Deep Link
```

## 完整模型、点击回调与方法触发

```swift
let session = router.openSession(
    ProductRoute.detail(id: product.id),
    input: product,
    presentation: .push(),
    scope: "app.product",
    commands: ProductCommand.self,
    events: ProductEvent.self,
    expecting: ProductOutput.self
)

let eventTask = session.observeEvents { event in
    // 接收收藏、分享等任意次数的页面事件
}

try session.send(.refresh)
try session.send(.updateBadge(3))

let output = try await session.value
await eventTask.value
```

目标页面通过 `TFYSwiftDestinationContext` 完成交互：

```swift
let product: Product = try context.input()
let commands: AsyncStream<ProductCommand> = try context.commands()
try context.send(ProductEvent.favoriteTapped(productID: product.id))
context.result?.finish(with: ProductOutput(didConfirm: true))
```

## 多 Tab 和跨组件调用

每个 Tab 注册独立 Scope：

```swift
assembly.register(navigationController: homeNavigation, for: "app.home")
assembly.register(navigationController: cartNavigation, for: "app.cart")
assembly.register(navigationController: profileNavigation, for: "app.profile")
```

跨 Tab Navigator 执行两个动作：

```swift
tabBarController.selectedIndex = cartTabIndex
try await router.open(
    CartRoute.summary,
    presentation: .push(),
    scope: "app.cart"
)
```

不展示页面的业务能力使用服务协议：

```swift
let cart = try services.resolve(CartComponentKeys.service)
let snapshot = try await cart.add(product)
```

业务组件只依赖目标组件 Interface，不依赖其控制器或 Service 实现。

## Demo

仓库 Demo 提供 Home、Product、Cart、Profile 四个 Tab，每个 Tab 都有独立导航栈，并完整演示：

- 根页面 Route 注册和组件 Module 装配。
- 同 Tab Push、Sheet、返回根页面。
- 跨 Tab 跳转和独立导航历史。
- 完整模型 Input。
- Command/Event/Output 双向页面会话。
- Product → Cart 服务调用。
- 登录拦截挂起及成功后续跑。
- Checkout → Coupon Picker 嵌套路由结果。
- Deep Link 跨组件定位和 Route Inspector。

直接打开 `TFYSwiftRouterKit.xcodeproj`，选择 `TFYSwiftRouterKit` Scheme 和任意 iOS 16+ Simulator 运行。

## 文档

- [完整使用指南](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md)
- [四 Tab 完整项目流程](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-四Tab完整项目流程.md)
- [库内快速说明](TFYSwiftRouterKit/TFYSwiftRouter/README.md)

## 目录结构

```text
TFYSwiftRouterKit/
├── Package.swift
├── TFYSwiftRouterKit.podspec
├── LICENSE
├── README.md
├── TFYSwiftRouterKit/
│   ├── TFYSwiftRouter/
│   │   ├── Core/
│   │   ├── UIKit/
│   │   ├── SwiftUI/
│   │   ├── DeepLink/
│   │   ├── Restoration/
│   │   ├── Testing/
│   │   └── Umbrella/
│   └── ClassDmoe/                  # 四 Tab 可运行示例
├── TFYSwiftRouterKitTests/
└── TFYSwiftRouterKitUITests/
```

## License

TFYSwiftRouterKit 使用 MIT License，详见 [LICENSE](LICENSE)。

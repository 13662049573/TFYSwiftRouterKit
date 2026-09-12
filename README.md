# TFYSwiftRouterKit

面向 iOS 16+、Swift 6 的组件路由工具。使用强类型地址连接页面、导航容器和业务流程，支持 UIKit、原生 SwiftUI、双向会话、跨组件服务、外部链接、导航恢复和测试替身。

App 管理容器与依赖，组件管理自己的页面工厂。首页、商品、购物车、我的四个根页面也通过 Route 安装；App 不需要直接创建业务 UIViewController。

[从 0 到 1 完整中文指南](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md) · [四 Tab 项目流程](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-四Tab完整项目流程.md) · [变更记录](CHANGELOG.md)

> 当前文档版本：**2.0.0**（2026-09-12）。SwiftPM 发布版本由同名 Git Tag 提供；CocoaPods 版本与 `TFYSwiftRouterKit.podspec` 保持一致。

## 2.0.0 更新说明

2.0.0 是面向通用组件化接入的主版本：路由核心不再假设固定业务名称、资源、URL、默认容器或错误界面，App 可以独立注入产品语义与视觉资源。

- 新增强类型 Route/Session Contract、结果与会话超时、主动取消和更完整的交互生命周期。
- 新增原子注册与回滚、重复 Scope 检测、服务命名空间、可配置默认 Scope。
- 新增导航快照、恢复迁移、自定义编解码、Deep Link 解析器优先级和测试替身调用记录。
- 修复 UIKit/SwiftUI 页面交互释放、模态导航域存活、SwiftUI 工厂错误回传及冷启动 Universal Link 等问题。
- `TFYSwiftRouterAssembly.register(navigationController:for:)` 现在会抛错，调用处需使用 `try`。
- 运行时聚合产品不再包含 Testing；测试 Target 需单独依赖 `TFYSwiftRouterTesting` 或 `TFYSwiftRouterKit/Testing`。
- `ignoreIfTop` 保留兼容，但新代码统一推荐 `singleTop`。

完整条目、兼容影响和迁移示例见 [CHANGELOG](CHANGELOG.md)，从空工程接入见[完整使用指南](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md)。

### 版本关联与发布顺序

| 入口 | 2.0.0 的版本来源 | 作用 |
|---|---|---|
| `Package.swift` | Git Tag `2.0.0` | SwiftPM 清单只描述产品和 Target，不保存独立版本号 |
| `TFYSwiftRouterKit.podspec` | `spec.version = '2.0.0'` | CocoaPods 源码 Tag 自动使用 `spec.version` |
| README / 完整指南 / CHANGELOG | 文档中的 2.0.0 声明 | 安装、迁移、更新说明保持一致 |
| Demo Xcode 工程 | `MARKETING_VERSION = 2.0.0` | 运行示例时显示与组件发布相同的版本 |

建议在发布前依次执行：

1. 完成构建、测试、`swift package dump-package` 和 `pod lib lint`。
2. 提交本版本的代码、Demo、Podspec 与文档。
3. 在该提交创建并推送 `2.0.0` Tag，SwiftPM 随即可以解析该版本。
4. 以同一 Tag 执行 `pod trunk push TFYSwiftRouterKit.podspec`。
5. 将 [CHANGELOG 的 2.0.0 内容](CHANGELOG.md)作为 GitHub Release 说明，并再次验证远端 SPM/CocoaPods 接入。

本仓库当前只准备发布文件，不会自动创建提交、Tag、GitHub Release 或执行 CocoaPods 发布。

## 先运行 Demo

1. 打开 TFYSwiftRouterKit.xcodeproj。
2. 选择 TFYSwiftRouterKit Scheme 和已安装的 iOS 模拟器。
3. 运行，进入四 Tab 首页。
4. 点击首页第一组“路由能力实验室”，体验新增功能。
5. 右上角关闭实验室，继续体验商品会话、购物车服务、登录结算与跨 Tab 导航。

实验室使用独立 Router 和导航容器。Replace、Root、快照恢复等操作不会覆盖外面的四个业务 Tab。快照会真实保存到本地，可退出实验室后再次恢复。

## 功能与演示入口

| 能力 | 使用方式 | 可操作的 Demo |
|---|---|---|
| 强类型地址 | TFYSwiftRoute，地址仅包含 ID/小型值 | 四个 Tab 的全部导航 |
| 完整模型输入 | open(input:)，context.input() | 首页 → 商品详情 |
| 一次性返回 | expecting / context.result.finish | 优惠券、主题、选择器 |
| 编译期输入输出契约 | TFYSwiftRouteContract / openTyped | 实验室 → 强类型 Input → Output |
| 编译期双向契约 | TFYSwiftSessionRouteContract / openTypedSession | 实验室 → 强类型双向会话 |
| 命令与连续事件 | session.send / context.send | 商品刷新、角标、收藏、分享 |
| 结果超时 | open(timeout:) / session.value(timeout:) | 实验室 → 3 秒 / 5 秒超时 |
| 主动取消 | session.cancel / result.cancel | 实验室 → 主动取消会话 |
| 多导航栈 | Scope + ScopedNavigationDriver | Home/Product/Cart/Profile 四 Tab |
| 可配置默认容器 | initialScope / defaultScope | 实验室使用 lab.navigation，不注册 main |
| 通用性与资源隔离 | App 错误 UI、服务命名空间、自定义编解码 | 实验室 → 通用配置与业务资源隔离 |
| 模块注册与解耦 | TFYSwiftUIKitComponentModule | AppCoordinator 与各 Feature Module |
| 原子注册 | performRegistrationTransaction | 实验室 → 重复注册与事务回滚 |
| 重复检测与显式覆盖 | replacingExisting，contains，unregister | 实验室 → 注册清单及冲突检查 |
| 呈现和回退 | Push、Sheet、FullScreen、Replace、Root、Back、Dismiss | 实验室 → 页面呈现 |
| 去重 | singleTop / singleTask | 实验室 → 去重与复用 |
| 自定义转场 | registerCustomPresentation | 实验室 → 淡入转场 |
| 新窗口扩展点 | registerNewWindowPresentation | 实验室 → 新窗口接入边界 |
| 服务协议调用 | ComponentServiceRegistry | 首页加购 → Cart 服务 |
| 登录挂起恢复 | Interceptor.suspend | 购物车结算、我的订单 |
| 拦截保护 | reject / redirect / 挂起次数上限 | 实验室 → 拦截器与循环保护 |
| URL 解析 | DeepLinkEngine、白名单、Parser | 首页 Deep Link / 实验室优先级检查 |
| UIKit 托管 SwiftUI | registerSwiftUI | 实验室 → UIKit 托管 SwiftUI 页面 |
| 原生 SwiftUI 导航 | SwiftUIDriver + RouterHost | 实验室 → 原生 SwiftUI RouterHost |
| 工厂错误回传 | 先构建 View，再变更路径 | SwiftUI 实验室 → 验证工厂错误 |
| 导航快照落盘 | Codable + makeSnapshot + JSON | 实验室 → 保存当前导航快照 |
| 导航恢复与迁移 | restore / registerMigration | 实验室 → 恢复、v1 → v2 |
| 恢复白名单策略 | .skip / .fail | 实验室 → 不可恢复路由策略 |
| 可观测性 | EventCenter / History / transactionStates | Inspector、历史容量与清理 |
| 测试替身 | TestRouter、Provider、invocations | 实验室 → 测试替身与调用记录 |

新窗口是 App 接入点，并非组件自动创建系统 Scene。Demo 展示未注册处理器时的明确错误；真实多窗口需配套 App Scene 配置。Universal Link 的白名单演示也不等于域名与 App 已完成系统关联。

## 环境和安装

组件最低声明为 iOS 16、Swift 6。选择支持 Swift 6 的 Xcode。iOS 页面需要模拟器/真机验证；macOS 的 swift test 只覆盖可在主机运行的模块。

当前 README、Package 清单、Podspec 和完整指南均对应 2.0.0。若远端尚未创建 `2.0.0` Tag，请先使用本地依赖；Tag 发布后再切换到下面的远端版本约束。

### Swift Package Manager

本地试用：在 Xcode 添加本地 Package，选择本仓库根目录，然后选择需要的产品。

远端接入：在 Xcode 的 Add Package Dependencies 中填写 `https://github.com/13662049573/TFYSwiftRouterKit.git`，Dependency Rule 选择 **Up to Next Major Version**，起始版本填写 `2.0.0`。其他 Package 的清单写法如下：

~~~swift
dependencies: [
    .package(
        url: "https://github.com/13662049573/TFYSwiftRouterKit.git",
        from: "2.0.0"
    )
]
~~~

SwiftPM 从 Git Tag 解析版本，`Package.swift` 本身没有 `version` 字段。仓库在创建并推送 `2.0.0` Tag 前，远端版本约束不会生效。

| SPM 产品 | 内容 |
|---|---|
| TFYSwiftRouterCore | Route、Router、Session、Service、Scope、Interceptor、事件 |
| TFYSwiftRouterUIKit | UIViewController 工厂、UIKit Driver、Assembly、组件模块协议 |
| TFYSwiftRouterSwiftUI | 原生 NavigationStack/Sheet/FullScreen 与 RouterHost |
| TFYSwiftRouterDeepLink | URL 校验、优先级解析引擎 |
| TFYSwiftRouterRestoration | Codable 地址、快照、版本迁移与恢复 |
| TFYSwiftRouterTesting | 无 UI 的测试替身 |
| TFYSwiftRouterKit | 聚合所有运行时模块，不含 Testing |

UIKit 工程可按需导入：

~~~swift
import TFYSwiftRouterCore
import TFYSwiftRouterUIKit
~~~

小型工程也可以只选择聚合产品：

~~~swift
import TFYSwiftRouterKit
~~~

测试 Target 单独依赖 TFYSwiftRouterTesting，并 import TFYSwiftRouterTesting。

### CocoaPods

`2.0.0` 发布到 CocoaPods 后使用：

~~~ruby
platform :ios, '16.0'
use_frameworks!

target 'MyApp' do
  pod 'TFYSwiftRouterKit', '~> 2.0'

  target 'MyAppTests' do
    inherit! :search_paths
    pod 'TFYSwiftRouterKit/Testing', '~> 2.0'
  end
end
~~~

验证尚未发布的工作区源码时，在自己的 Podfile 中使用本地路径：

~~~ruby
platform :ios, '16.0'
use_frameworks!

target 'MyApp' do
  pod 'TFYSwiftRouterKit', :path => '../TFYSwiftRouterKit'

  target 'MyAppTests' do
    inherit! :search_paths
    pod 'TFYSwiftRouterKit/Testing', :path => '../TFYSwiftRouterKit'
  end
end
~~~

按需选择 Core、UIKit、SwiftUI、DeepLink、Restoration、Testing 子规格。CocoaPods 统一使用 import TFYSwiftRouterKit。安装后打开生成的 xcworkspace。

仓库 Demo 直接编译组件源码，因而没有这些包 import；复制示例到独立工程时需要补上。

## 最小接入：定义、注册、打开

以下代码在 @MainActor 的 App/Scene 组合根中执行。导航控制器和 Assembly 应由 Scene/Flow 属性强持有；window.rootViewController 设置好后再安装根路由。

~~~swift
import UIKit
import TFYSwiftRouterCore
import TFYSwiftRouterUIKit

enum ProductRoute: TFYSwiftRoute, Codable {
    case root
    case detail(id: String)
}

let navigationController = UINavigationController()
let assembly = TFYSwiftRouterAssembly(
    navigationController: navigationController
)

try assembly.register(ProductRoute.self, destinationID: "product.page") {
    route, context in
    let page = UIViewController()
    page.view.backgroundColor = .systemBackground
    switch route {
    case .root: page.title = "商品"
    case .detail(let id): page.title = "商品 \(id)"
    }
    return page
}

try await assembly.router.open(
    ProductRoute.root,
    presentation: .root(animated: false),
    source: .programmatic
)
try await assembly.router.open(
    ProductRoute.detail(id: "1001"),
    presentation: .push(),
    deduplication: .singleTop
)
~~~

这段代码只使用组件与 UIKit 自带类型；完整的按钮、SceneDelegate、所有权和启动错误处理见使用指南第 3 节。

## 如何保持组件解耦

~~~text
Interface：Route / Input / Output / Command / Event / Service 协议
     ↑
Implementation：页面、服务实现、Resolver、Destination Factory、Module
     ↑
App：选择模块、注入服务、创建容器、安装根地址、处理外部入口
~~~

组件实现 TFYSwiftUIKitComponentModule，在 register(in:) 中登记自己的页面。rootRegistration 公开根 Route 和 Scope，App 只负责打开返回的类型擦除地址。

~~~swift
@MainActor
struct ProductModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: "app.products", route: ProductRoute.root
    )

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.register(ProductRoute.self) { route, _ in
            let page = UIViewController()
            page.view.backgroundColor = .systemBackground
            page.title = String(describing: route)
            return page
        }
    }
}
~~~

每个 Tab 先注册独立 UINavigationController，再注册模块：

~~~swift
try assembly.register(
    navigationController: productNavigationController,
    for: "app.products"
)
let roots = try assembly.registerComponents([ProductModule()])
for root in roots {
    try await assembly.router.open(
        root.route,
        presentation: .root(animated: false),
        scope: root.scope
    )
}
~~~

这里的 productNavigationController 由 App 的 Tab 组装代码提供。不同章节的注册例子是不同方案，不能在同一个 Assembly 中不加区分地重复执行。

Scope 不自动切换选中的 Tab。Demo 用 TFYSwiftDemoTabRouter 封装“选 Tab + 打开地址”，组件页面依赖 TFYSwiftDemoNavigating 协议。

## 输入、返回值与双向会话

### 临时模型输入

Input 只要求 Sendable；不用为了路由给整个业务模型补 Hashable/Codable：

~~~swift
struct ProductInput: Sendable {
    let id: String
    let name: String
}

try await assembly.router.open(
    ProductRoute.detail(id: "1001"),
    input: ProductInput(id: "1001", name: "Swift 路由实践")
)
// 在对应页面工厂内：
// let input: ProductInput = try context.input()
~~~

Route 用于地址、去重和恢复；Input 是单次请求临时数据，不会自动写入 URL/快照。

### 强类型选择器

~~~swift
struct PickerRoute: TFYSwiftRouteContract {
    typealias Input = [String]
    typealias Output = String
}

// 登记 PickerRoute 的页面工厂后：
let selection = try await assembly.router.openTyped(
    PickerRoute(),
    input: ["Swift", "UIKit", "SwiftUI"],
    presentation: .sheet()
)
~~~

页面通过 context.result?.finish(with: selection) 返回一次结果，然后自行 dismiss。Result 不会自动关闭 UI。完整可复制的 PickerPage 与注册代码见指南第 6 节；Demo 使用 TFYSwiftDemoPickerContract。

### 强类型双向会话

~~~swift
enum ProductCommand: Sendable { case refresh }
enum ProductEvent: Sendable { case favorite(String) }
struct ProductOutput: Sendable { let confirmed: Bool }

struct ProductSessionRoute: TFYSwiftSessionRouteContract {
    typealias Input = ProductInput
    typealias Command = ProductCommand
    typealias Event = ProductEvent
    typealias Output = ProductOutput
    let id: String
}

// 登记该契约的页面工厂后：
let session = assembly.router.openTypedSession(
    ProductSessionRoute(id: "1001"),
    input: ProductInput(id: "1001", name: "Swift 路由实践")
)
let observation = session.observeEvents { event in
    print("连续事件：\(event)")
}
defer {
    observation.cancel()
    session.cancel()
}
try session.send(.refresh)
let output = try await session.value(timeout: 30)
await observation.value
~~~

目标页面的四个入口：

- try context.input()：读取初始模型。
- try context.commands()：返回命令 AsyncStream，使用 for await 消费。
- try context.send(ProductEvent.favorite("1001"))：发送连续事件。
- context.result?.finish(with: ProductOutput(confirmed: true))：最终完成。

observeEvents 与遍历 session.events 二选一；当前 AsyncStream 不是广播总线。页面拥有的命令 Task 应在生命周期结束时取消，避免强捕获页面形成环。

基础 open/openSession 仍可使用；契约是可选的编译期增强。

## 超时、取消与页面关闭

~~~swift
let value: String = try await assembly.router.open(
    PickerRoute(),
    input: ["A", "B"],
    presentation: .sheet(),
    timeout: 15,
    expecting: String.self
)
~~~

timeout 单位为秒。普通 open 超时覆盖该次调用；session.value(timeout:) 从调用该方法时开始计时。超时/取消会结束等待与通信，不自动决定 UI 如何关闭，App Flow 需按业务执行 dismiss/back。

UIKit 导航方法的 async 返回不保证动画已经结束。Result 完成后马上展示下一弹层，应等待转场完成；实验室有真实完成回调处理。

## 注册可靠性

地址、Destination、Scope、服务、恢复编码器都进行重复检测；需要覆盖时显式传 replacingExisting。UIKit Assembly 的成对注册和组件批量登记，会在失败时回滚地址表与页面表。

~~~swift
try services.performRegistrationTransaction {
    // 同步批量登记服务；抛错时恢复服务映射。
}
~~~

事务只回滚注册映射，不回滚网络请求或服务对象内部状态。注销不自动关闭已有页面。实验室的冲突探针会真实制造错误并检查残留。

## 拦截器和外部链接

拦截器提供 proceed、reject、redirect、suspend 四种决策，优先级越大越先执行。登录挂起恢复成功后重新经过拦截器，因此必须先更新登录状态。Router 有重定向和挂起次数上限。

~~~swift
let engine = TFYSwiftDeepLinkEngine(
    policy: .app(
        scheme: "tfyswift",
        universalLinkHosts: ["router.tfy.com"]
    )
)
await engine.add(TFYSwiftDemoDeepLinkParser(), priority: 100)
~~~

上述 Parser 是仓库 Demo 类型；独立项目实现自己的 TFYSwiftDeepLinkParser。引擎先验证 Scheme、HTTP/HTTPS Host、长度和凭据，然后调用 Parser。Parser 负责业务参数合法性，解析后的地址仍经过 Router。

外部入口需覆盖冷启动 URL/NSUserActivity、热启动 openURLContexts/continue。先安装根路由再处理链接。Universal Link 还需要 App Associated Domains 和服务端关联文件，详见指南第 13 节。

## 原生 SwiftUI 与恢复

原生 SwiftUI 使用 TFYSwiftSwiftUINavigationDriver + TFYSwiftSwiftUIRouterHost，工厂在路径变更前构建，因此同步工厂失败会抛回调用方，导航状态不变。

~~~swift
let driver = TFYSwiftSwiftUINavigationDriver()
let router = TFYSwiftRouter(driver: driver)
// 登记 router.registry 与 driver.destinations 后，交给：
// TFYSwiftSwiftUIRouterHost(driver: driver) { RootView() }
~~~

如果只是在 UIKit 栈中展示 SwiftUI，使用 assembly.destinations.registerSwiftUI，仍由 UIKit Driver 管理。

恢复只保存显式登记了编解码器的地址；以下使用默认 Codable/JSON，也支持注入自定义格式：

~~~swift
let codecs = TFYSwiftRestorationRegistry()
try codecs.register(ProductRoute.self, identifier: "product.route")
let restoration = TFYSwiftRestorationCoordinator(
    registry: codecs,
    router: assembly.router
)

let snapshot = try restoration.makeSnapshot(scopes: [.main])
let data = try JSONEncoder().encode(snapshot)
UserDefaults.standard.set(data, forKey: "navigation.snapshot")

let decoded = try JSONDecoder().decode(TFYSwiftNavigationSnapshot.self, from: data)
try await restoration.restore(decoded)
~~~

恢复前先完成容器/工厂注册。框架先迁移与完整解码，再逐页 root/push；运行期展示失败不自动回滚已恢复页面。Sheet、完整 Input、选中 Tab、滚动位置和运行中会话不在快照里。存储介质、账户隔离和降级由 App 决定。

实验室提供本地保存/重开、v1 → v2 迁移、skip/fail 三类可操作示例。

## 诊断和测试

EventCenter 弱持有观察者，App 应持有 History。transactionStates 与 History 都是有限诊断记录，不是永久存储。手工清理不会取消正在运行的导航。

~~~swift
let history = TFYSwiftRouteHistory(capacity: 200)
assembly.events.add(history)
assembly.router.transactionStateCapacity = 500
~~~

业务依赖 any TFYSwiftRouting，测试注入 TFYSwiftTestRouter：

~~~swift
import TFYSwiftRouterTesting

let mock = TFYSwiftTestRouter()
mock.provide(String.self) { "默认结果" }
mock.provide(for: PickerRoute()) { "指定路由结果" }
let result = try await mock.openTyped(
    PickerRoute(),
    input: ["A"],
    scope: "test.picker",
    metadata: .init(traceID: "test-trace")
)
assert(result == "指定路由结果")
assert(mock.invocations.last?.scope == "test.picker")
~~~

actions 记录导航动作，invocations 额外记录 Scope、Source、Metadata、去重及输入类型名，不保存完整 Input。支持异步 Provider 和会话交互模拟，详见指南第 17 节。

## 源码结构

~~~text
TFYSwiftRouterKit/
├─ AppDelegate/                    Scene 启动、冷/热外部入口
├─ ClassDmoe/
│  ├─ Application/                 四 Tab 组装、业务导航协议实现
│  ├─ Routes/                      地址、输入输出、服务协议
│  ├─ Features/                    四个组件与注册入口
│  ├─ Screens/                     选择器、商品会话、结算、Inspector
│  └─ Laboratory/                  最新能力的完整操作演示
└─ TFYSwiftRouter/
   ├─ Core/                        平台无关路由核心
   ├─ UIKit/                       页面工厂、驱动、Assembly
   ├─ SwiftUI/                     原生导航状态与 RouterHost
   ├─ DeepLink/                    外部输入适配
   ├─ Restoration/                 快照、编解码和迁移
   ├─ Testing/                     测试替身
   ├─ Umbrella/                    SPM 聚合导出
   └─ Documentation/               0→1 指南与四 Tab 流程
~~~

组件 23 个 Swift 文件已补齐中文职责/API 注释。阅读顺序建议 Route → Registry → Router → NavigationDriver → Interaction → 平台适配。

## 构建与验证

~~~sh
swift test

xcodebuild build \
  -project TFYSwiftRouterKit.xcodeproj \
  -scheme TFYSwiftRouterKit \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project TFYSwiftRouterKit.xcodeproj \
  -scheme TFYSwiftRouterKit \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -only-testing:TFYSwiftRouterKitTests \
  CODE_SIGNING_ALLOWED=NO
~~~

模拟器名称按本机替换。UI 测试位于 TFYSwiftRouterKitUITests，新增 testLaboratory 系列覆盖真实页面操作，原有测试覆盖跨 Tab 商品会话和嵌套结算流程。

## 常见接入问题

- 跳转到错误 Tab：Scope 负责定位容器，App 还要设置 selectedIndex。
- scopeUnavailable：容器未登记或没有被 App 持有。
- 注册重复：检查类型/目标标识，必要时显式替换。
- inputMissing：Deep Link/恢复没有临时模型，应按地址 ID 加载。
- 没有事件通道：需要双向通信的页面必须通过 openSession/openTypedSession 打开。
- 返回值一直等待：目标需要 finish/cancel；流程放弃时主动取消，并按业务设置超时。
- 返回结果但页面没关：Result 只结束通信，页面需独立 pop/dismiss。
- 结果请求去重报错：新结果不能绑定到旧页面，结果流程优先使用 none。
- 恢复失败：检查 Codable、稳定标识、版本迁移、Scope 与目标工厂。
- Testing 类型找不到：测试 Target 需要显式依赖 Testing，聚合运行时包不再导出它。

## 兼容性与许可

组件不依赖 Demo 类型、业务 URL、资源包或快照存储键。图标、主题、错误页面和业务名称由 App 决定，完整配置说明见[指南第 21 节](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md#21-通用组件与-app-资源的边界)。

~~~swift
// 自定义缺省容器。普通导航、契约、Session、超时、Deep Link 和回退统一继承。
let assembly = TFYSwiftRouterAssembly(
    navigationController: navigationController,
    initialScope: "workspace.navigation"
)

// 同一服务类型可以按调用方提供的命名空间登记多个实例。
let primary = TFYSwiftComponentServiceKey<String>(namespace: "primary")
let secondary = TFYSwiftComponentServiceKey<String>(namespace: "secondary")

// 恢复的默认 JSON 策略可配置，也可 register(..., encode:decode:) 使用自定义格式。
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let codecs = TFYSwiftRestorationRegistry(encoder: encoder, decoder: decoder)
~~~

SwiftUI RouterHost 的 errorContent 闭包接收 App 自己的错误 View；组件已移除固定图标、橙色和标题，未配置时不强加视觉样式。正常工厂异常仍通过 open 抛回调用方。错误新增稳定 code，方便映射自己的多语言资源；原中文 errorDescription 保留诊断兼容。

从 1.0.0 升级到 2.0.0 时，Scope 注册接口需要补 `try` 并处理重复注册；旧 ScopedDriver 无错误覆盖接口已弃用。Testing 改为测试 Target 显式依赖，`ignoreIfTop` 保持兼容但推荐 `singleTop`。RouteContract 是可选增强，不要求重写已有 Route。具体迁移代码见 [CHANGELOG](CHANGELOG.md)。

项目采用 [MIT License](LICENSE)。作者：田风有。

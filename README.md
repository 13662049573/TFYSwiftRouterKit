# TFYSwiftRouterKit

面向 iOS 16+、Swift 6 的组件路由工具。使用强类型地址连接页面、导航容器和业务流程，支持 UIKit、原生 SwiftUI、双向会话、跨组件服务、外部链接、导航恢复和测试替身。

App 管理容器与依赖，组件管理自己的 Route 和页面工厂。内置 TabBar Driver 会把 Scope 映射到真实 Tab：跨 Tab 路由只需指定目标 Scope，不再由业务层手动修改 `selectedIndex`。

[从 0 到 1 完整中文指南](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md) · [四 Tab 项目流程](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-四Tab完整项目流程.md) · [变更记录](CHANGELOG.md)

> 当前开发版本：**2.3.0**（2026-09-21）。

## 3 分钟开始使用

普通页面只需要 Route、Assembly 和一个单参数页面工厂：

~~~swift
import UIKit
import TFYSwiftRouterKit

enum AppRoute: TFYSwiftRoute {
    case home
    case detail(id: String)
}

let navigationController = UINavigationController()
let assembly = TFYSwiftRouterAssembly(navigationController: navigationController)

try assembly.register(AppRoute.self) { route in
    let page = UIViewController()
    switch route {
    case .home: page.title = "首页"
    case .detail(let id): page.title = "详情 \(id)"
    }
    return page
}

try await assembly.router.open(AppRoute.home, presentation: .root(animated: false))
try await assembly.router.open(AppRoute.detail(id: "1001"), presentation: .push())
~~~

先用这条默认路径即可。需求出现后再逐层加入能力：

| 需求 | 按需使用 |
|---|---|
| 页面自己管理注册 | `TFYSwiftUIKitRouteConfiguration` |
| 编译期输入/输出 | `registerTyped` / `openTyped` |
| 多 Tab 或多导航栈 | Scope / TabBar Assembly |
| 登录、权限等保护 | 闭包 Interceptor；复杂状态再实现协议 |
| 外链、恢复、双向通信 | DeepLink / Restoration / Session 独立模块 |

## 2.3.0 更新说明

2.3.0 补齐结构化路由诊断与无模拟器验证流水线。

- 事件新增来源、链路 ID、呈现方式、去重策略、目标 ID 与稳定错误码。
- 目标 ID 在解析完成后贯穿 presented、completed 和 failed 等后续事件。
- Demo 事件详情展示完整结构化字段，并补充事件模型回归测试。
- CI 使用 generic iOS 真机 SDK 构建，不再依赖 Simulator，并对上一版本执行公开 API 兼容性检查。

完整条目、兼容影响和迁移示例见 [CHANGELOG](CHANGELOG.md)，从空工程接入见[完整使用指南](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md)。

### 版本关联与发布顺序

| 入口 | 2.3.0 的版本来源 | 作用 |
|---|---|---|
| `Package.swift` | Git Tag `2.3.0` | SwiftPM 清单只描述产品和 Target，不保存独立版本号 |
| `TFYSwiftRouterKit.podspec` | `spec.version = '2.3.0'` | CocoaPods 源码 Tag 自动使用 `spec.version` |
| README / 完整指南 / CHANGELOG | 文档中的 2.3.0 声明 | 安装、迁移、更新说明保持一致 |
| Demo Xcode 工程 | `MARKETING_VERSION = 2.3.0` | 运行示例时显示与组件发布相同的版本 |

建议在发布前依次执行：

1. 完成构建、测试、`swift package dump-package` 和 `pod lib lint`。
2. 提交本版本的代码、Demo、Podspec 与文档。
3. 在该提交创建并推送 `2.3.0` Tag，SwiftPM 随即可以解析该版本。
4. 以同一 Tag 执行 `pod trunk push TFYSwiftRouterKit.podspec`。
5. 将 [CHANGELOG 的 2.3.0 内容](CHANGELOG.md)作为 GitHub Release 说明，并再次验证远端 SPM/CocoaPods 接入。

## 先运行 Demo

1. 打开 TFYSwiftRouterKit.xcodeproj。
2. 选择 TFYSwiftRouterKit Scheme 和一台 iOS 16+ 真机。
3. 运行后从“开始”Tab 依次执行“打开详情 → 自动跨 Tab → 等待页面结果 → 查看事件”。
4. 在“演练”Tab 操作全部呈现方式、去重、拦截、Deep Link、强类型结果和双向 Session。
5. 使用“导航栈”和“事件”Tab 核对每个 Scope 的真实页面栈与事务事件。

Demo 已从空目录重新构建，四个 Tab 分别承担引导、能力操作、状态核对和事件诊断；所有按钮都调用公开 API，没有 Demo 专用路由替身。

路由不会消灭 `UIViewController`：UIKit 最终仍需要页面实例。它消除的是调用方对具体页面类、构造参数和展示方式的依赖。Demo 按 Start、Playground、Stack、Timeline 分成四套 Feature，每套各自包含 ViewController、Model、Routes、Router；`AppCoordinator` 只安装四个组件并打开根 Route。

## 功能与演示入口

| 能力 | 使用方式 | 可操作的 Demo |
|---|---|---|
| 强类型地址 | TFYSwiftRoute，地址只包含稳定标识 | 开始/演练的全部页面 |
| 一次性返回 | registerTyped / openTyped / finish | 开始 → 等待页面结果 |
| 编译期输入输出契约 | TFYSwiftRouteContract | 演练 → 强类型结果 |
| 编译期双向契约 | TFYSwiftSessionRouteContract / openTypedSession | 演练 → 双向 Session |
| 命令与连续事件 | session.send / context.send | Session 状态、事件与最终输出 |
| 有界会话缓冲 | TFYSwiftRouteSessionBuffering | Command/Event 默认各保留最新 64 条 |
| 多导航栈 | Scope + ScopedNavigationDriver | 四个 Tab 的独立导航栈 |
| TabBar 路由 | TFYSwiftTabBarNavigationDriver | 自动跨 Tab、选择目标 Scope |
| 呈现和回退 | Push、Sheet、FullScreen、Replace、Root、Back、Dismiss | 演练 → 呈现方式与栈操作 |
| 去重 | singleTop / singleTask | 演练 → Single Top |
| 自定义转场 | registerCustomPresentation | 演练 → Custom |
| 新窗口扩展点 | registerNewWindowPresentation | 演练 → New Window |
| 拦截保护 | proceed / reject / redirect / suspend | 演练 → Interceptor Redirect |
| URL 解析 | DeepLinkEngine、白名单、Parser | 开始/演练 → Deep Link |
| UIKit 托管 SwiftUI | registerSwiftUI | 开始 → SwiftUI 页面 |
| 可观测性 | EventCenter / History / transactionStates | 导航栈、事件时间线 |
| 导航恢复 | Codable、检查点、迁移与原子回滚 | Core/SwiftUI/UIKit 回归测试 |
| 测试替身 | TestRouter、Provider、invocations | SwiftPM 单元测试 |

新窗口是 App 接入点，并非组件自动创建系统 Scene。Demo 展示未注册处理器时的明确错误；真实多窗口需配套 App Scene 配置。Universal Link 的白名单演示也不等于域名与 App 已完成系统关联。

## 环境和安装

组件最低声明为 iOS 16、Swift 6。选择支持 Swift 6 的 Xcode。iOS 页面使用真机验证；macOS 的 swift test 只覆盖可在主机运行的模块。

当前 README、Package 清单、Podspec 和完整指南均对应 2.3.0。

### Swift Package Manager

本地试用：在 Xcode 添加本地 Package，选择本仓库根目录，然后选择需要的产品。

远端接入：在 Xcode 的 Add Package Dependencies 中填写 `https://github.com/13662049573/TFYSwiftRouterKit.git`，Dependency Rule 选择 **Up to Next Major Version**，起始版本填写 `2.3.0`。其他 Package 的清单写法如下：

~~~swift
dependencies: [
    .package(
        url: "https://github.com/13662049573/TFYSwiftRouterKit.git",
        from: "2.3.0"
    )
]
~~~

SwiftPM 从 Git Tag 解析版本，`Package.swift` 本身没有 `version` 字段。

| SPM 产品 | 内容 |
|---|---|
| TFYSwiftRouterCore | Route、Router、Session、Service、Scope、Interceptor、事件 |
| TFYSwiftRouterUIKit | RouteConfiguration、UIViewController 工厂、UIKit Driver、Assembly、组件模块协议 |
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

`2.3.0` 发布到 CocoaPods 后使用：

~~~ruby
platform :ios, '16.0'
use_frameworks!

target 'MyApp' do
  pod 'TFYSwiftRouterKit', '~> 2.3'

  target 'MyAppTests' do
    inherit! :search_paths
    pod 'TFYSwiftRouterKit/Testing', '~> 2.3'
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

## 组件化接入：页面自管理注册

以下代码在 @MainActor 的 App/Scene 组合根中执行。导航控制器和 Assembly 应由 Scene/Flow 属性强持有；window.rootViewController 设置好后再安装根路由。

~~~swift
import UIKit
import TFYSwiftRouterCore
import TFYSwiftRouterUIKit

enum ProductRoute: TFYSwiftRoute, Codable {
    case root
    case detail(id: String)
}

final class ProductViewController: UIViewController {}

let navigationController = UINavigationController()
let assembly = TFYSwiftRouterAssembly(
    navigationController: navigationController
)

extension ProductViewController {
    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<ProductRoute> {
        .init(
            rootScope: .main,
            rootRoute: ProductRoute.root,
            destinationID: "product.page"
        ) { route, _ in
            let page = ProductViewController()
            switch route {
            case .root: page.title = "商品"
            case .detail(let id): page.title = "商品 \(id)"
            }
            return page
        }
    }
}

let roots = try assembly.registerConfigurations([
    ProductViewController.routeConfiguration()
])

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

小型项目优先使用文首的单参数 `register`。当页面需要随组件自注册、声明根 Scope，或统一批量安装时，再采用这一配置方式。完整的按钮、SceneDelegate、所有权和启动错误处理见使用指南。

固定 Input/Output 的页面可把注册与调用都收紧为编译期类型：

~~~swift
struct PickerRoute: TFYSwiftRouteContract {
    typealias Input = [String]
    typealias Output = String
}

try assembly.registerTyped(PickerRoute.self) { _, context in
    PickerViewController(
        values: context.input,
        onSelect: { try? context.finish($0) },
        onCancel: { context.cancel() }
    )
}

let selected = try await assembly.router.openTyped(
    PickerRoute(),
    input: ["Swift", "UIKit", "SwiftUI"],
    presentation: .sheet()
)
~~~

`selected` 自动推导为 `String`。Demo 的“强类型 Input → Output”使用的就是这条最短链路。

## 如何保持组件解耦

~~~text
Interface：Route / Input / Output / Command / Event / Service 协议
     ↑
Implementation：页面、服务实现、Resolver、Destination Factory、Module
     ↑
App：选择模块、注入服务、创建容器、安装根地址、处理外部入口
~~~

页面使用 `TFYSwiftUIKitRouteConfiguration` 把 Route、目标标识、页面工厂和可选根 Scope 放在一起。App 汇总配置后一次事务安装，只负责打开返回的类型擦除根地址。

~~~swift
@MainActor
extension ProductViewController {
    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<ProductRoute> {
        .init(
            rootScope: "app.products",
            rootRoute: ProductRoute.root,
            destinationID: "product.page"
        ) { route, _ in
            let page = ProductViewController()
            page.title = String(describing: route)
            return page
        }
    }
}
~~~

Tab 应用直接用组件提供的 `TFYSwiftTabBarScope` 一次完成容器和 Scope 映射：

~~~swift
let tabBarController = UITabBarController()
let homeNavigation = UINavigationController()
let productNavigation = UINavigationController()

let assembly = try TFYSwiftRouterAssembly(
    tabBarController: tabBarController,
    tabs: [
        TFYSwiftTabBarScope(scope: "app.home", navigationController: homeNavigation),
        TFYSwiftTabBarScope(scope: "app.products", navigationController: productNavigation)
    ],
    initialScope: "app.home"
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

`router.open(..., scope: "app.products")` 会先选择 Product Tab，再把页面交给该 Scope 的 Navigation Driver。只切换 Tab、不打开页面时使用 `try assembly.tabBarDriver?.select("app.products")`。不同章节的注册例子是不同方案，不能在同一个 Assembly 中重复登记同一地址或 Scope。

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

Route 用于地址、去重和恢复；Input 是单次请求临时数据，不会自动写入 URL/快照。带 Input、Result 或 Session 的请求命中复用去重时会抛出 `destinationUnavailable`，避免把新交互静默丢给旧页面。

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

页面通过 `context.finish(selection)` 返回一次结果。Result 只结束通信，不隐式决定界面关闭策略；Demo 由调用方在 `openTyped` 返回后执行 Router `dismiss`，等待模态转场结束，再展示结果反馈，避免页面自关与调用方弹窗竞争。完整代码见指南和 `ClassDemo`。

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

内置 UIKit Driver 的 async 导航方法会在系统转场完成后返回，因此 Result 完成后可直接 `await dismiss`，再展示下一弹层。自定义转场与新窗口处理器仍由宿主负责定义何时算完成。

## 注册可靠性

地址、Destination、Scope、服务、恢复编码器都进行重复检测；需要覆盖时显式传 replacingExisting。UIKit Assembly 的成对注册和组件批量登记，会在失败时回滚地址表与页面表。

~~~swift
try services.performRegistrationTransaction {
    // 同步批量登记服务；抛错时恢复服务映射。
}
~~~

事务只回滚注册映射，不回滚网络请求或服务对象内部状态。注销不自动关闭已有页面，相关边界由单元测试覆盖。

## 拦截器和外部链接

拦截器提供 proceed、reject、redirect、suspend 四种决策，优先级越大越先执行。登录挂起恢复成功后重新经过拦截器，因此必须先更新登录状态。Router 有重定向和挂起次数上限。

~~~swift
let engine = TFYSwiftDeepLinkEngine(
    policy: .app(
        scheme: "tfyswift",
        universalLinkHosts: ["router.tfy.com"]
    )
)
await engine.add(AppDeepLinkParser(), priority: 100)
~~~

`AppDeepLinkParser` 表示接入方自己的 `TFYSwiftDeepLinkParser` 实现；仓库 Demo 的实现是 `TFYDemoDeepLinkParser`。引擎先验证 Scheme、HTTP/HTTPS Host、长度和凭据，然后调用 Parser。Parser 负责业务参数合法性，解析后的地址仍经过 Router。

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

恢复前先完成容器/工厂注册并关闭当前 Scope 的模态页面。框架先迁移与完整解码，再为每个受影响 Scope 创建 Driver 检查点并逐页 root/push；运行期展示失败或任务取消时会同步恢复原页面实例和 Interaction，原栈为空也能清理半恢复页面。UIKit、SwiftUI 与 Scoped Driver 已支持检查点；自定义 Driver 需实现 `TFYSwiftNavigationCheckpointing`，否则恢复会在修改 UI 前失败。空 Scope 快照不清空已有栈。Sheet、完整 Input、选中 Tab、滚动位置和拦截器业务副作用不在快照里，存储介质、账户隔离和降级由 App 决定。

恢复、迁移与失败原子回滚由 Core、UIKit 和 SwiftUI 回归测试共同覆盖。

## 诊断和测试

EventCenter 弱持有观察者，App 应持有 History。transactionStates 与 History 都是有限诊断记录，不是永久存储。手工清理不会取消正在运行的导航。
每条事件都携带 source、traceID、presentation、deduplication、destinationID 和 errorCode；metadata 的业务 values 不会自动写入事件，避免诊断日志泄漏敏感数据。

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
├─ ClassDemo/
│  ├─ App/                         只负责容器与四个 Feature Router 的组装
│  ├─ Start/                       ViewController + Model + Routes + Router
│  ├─ Playground/                  ViewController + Model + Routes + Router
│  ├─ Stack/                       ViewController + Model + Routes + Router
│  └─ Timeline/                    ViewController + Model + Routes + Router
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

阅读顺序建议 Route → Registry → Router → NavigationDriver → TabBar Driver → Interaction → 平台适配。

## 构建与验证

~~~sh
swift test

xcodebuild build-for-testing \
  -project TFYSwiftRouterKit.xcodeproj \
  -scheme TFYSwiftRouterKit \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
~~~

UI 测试位于 `TFYSwiftRouterKitUITests`，覆盖四 Tab 首屏、组件级跨 Tab、强类型结果、双向 Session 和事件时间线。运行期界面仍应在真实设备上验证。

## 常见接入问题

- 跳转到错误 Tab：确认使用 TabBar Assembly 初始化器，并且目标 Scope 已绑定到唯一 Tab；不要在业务层另改 `selectedIndex`。
- scopeUnavailable：容器未登记或没有被 App 持有。
- 注册重复：检查类型/目标标识，必要时显式替换。
- inputMissing：Deep Link/恢复没有临时模型，应按地址 ID 加载。
- 没有事件通道：需要双向通信的页面必须通过 openSession/openTypedSession 打开。
- 返回值一直等待：目标需要 finish/cancel；流程放弃时主动取消，并按业务设置超时。
- 返回结果但页面没关：Result 只结束通信，页面需独立 pop/dismiss。
- 交互请求去重报错：新 Input、Result 或 Session 不能绑定到旧页面，交互流程优先使用 none。
- 恢复失败：检查 Codable、稳定标识、版本迁移、Scope 与目标工厂。
- Testing 类型找不到：测试 Target 需要显式依赖 Testing，聚合运行时包不再导出它。

## 兼容性与许可

组件不依赖 Demo 类型、业务 URL、资源包或快照存储键。图标、主题、错误页面和业务名称由 App 决定，接入边界见[指南第 13 节](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md#13-接入检查)。

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

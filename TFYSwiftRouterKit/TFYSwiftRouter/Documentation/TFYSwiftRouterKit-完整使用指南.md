# TFYSwiftRouterKit 完整使用指南：从 0 到 1

本指南对应 **TFYSwiftRouterKit 2.0.0**，包括强类型契约、注册事务、结果超时、原生 SwiftUI 驱动、恢复迁移和测试替身。SwiftPM 版本来自 Git Tag；远端尚未发布 `2.0.0` Tag 时先使用本地依赖。

目标是让你从空项目完成第一次跳转，再逐步拆成 Home、Product、Cart、Profile 四个组件，并能处理输入、连续事件、返回值、登录、外部链接和导航恢复。

配套入口：

- 可运行 Demo：ClassDmoe 下的 Application、Features、Routes、Screens 和 Laboratory。
- [四 Tab 项目流程](TFYSwiftRouterKit-四Tab完整项目流程.md)。
- [组件源码阅读索引](#19-源码阅读索引)。
- [仓库 README](../../../README.md)。
- [2.0.0 完整变更与迁移记录](../../../CHANGELOG.md)。

## 目录

1. [准备工程和依赖](#1-准备工程和依赖)
2. [理解五个核心对象](#2-理解五个核心对象)
3. [从空项目跑通第一次跳转](#3-从空项目跑通第一次跳转)
4. [拆分组件并安装四个 Tab](#4-拆分组件并安装四个-tab)
5. [地址与完整模型输入](#5-地址与完整模型输入)
6. [单次返回值与强类型契约](#6-单次返回值与强类型契约)
7. [命令事件和最终输出](#7-命令事件和最终输出)
8. [取消超时与生命周期](#8-取消超时与生命周期)
9. [跨组件服务调用](#9-跨组件服务调用)
10. [注册替换注销和事务](#10-注册替换注销和事务)
11. [呈现回退和去重](#11-呈现回退和去重)
12. [拦截器与登录恢复](#12-拦截器与登录恢复)
13. [Deep Link 与 Universal Link](#13-deep-link-与-universal-link)
14. [UIKit 与原生 SwiftUI](#14-uikit-与原生-swiftui)
15. [持久化快照和版本迁移](#15-持久化快照和版本迁移)
16. [事件观察和诊断记录](#16-事件观察和诊断记录)
17. [测试业务导航](#17-测试业务导航)
18. [Demo 操作手册](#18-demo-操作手册)
19. [源码阅读索引](#19-源码阅读索引)
20. [错误排查与接入检查](#20-错误排查与接入检查)
21. [通用组件与 App 资源的边界](#21-通用组件与-app-资源的边界)

## 1. 准备工程和依赖

### 1.1 环境与目标

组件声明 iOS 16+、Swift 6。使用支持 Swift 6 的 Xcode。UIKit/SwiftUI 运行演示需要 iOS 模拟器或真机；在 macOS 上运行 swift test 主要验证不依赖 UI 的模块，不代表已验证 iOS 界面。

项目有两种形态：

- 仓库 Demo：组件源码直接编入 App Target，因此 Demo 文件无需 import TFYSwiftRouterCore。
- 独立业务工程：通过 SPM 或 CocoaPods 引入，必须按下面的模块规则 import。

不要同时把组件源码复制进 App，又给同一 Target 链接同一套组件包，否则可能出现重复类型或重复符号。

### 1.2 Swift Package Manager 接入

1. 打开自己的 Xcode 工程，添加本地 Package，选择本仓库根目录，也就是包含 Package.swift 的目录。
2. UIKit App 先选择 TFYSwiftRouterCore 与 TFYSwiftRouterUIKit；需要原生 SwiftUI 时再选择 TFYSwiftRouterSwiftUI。
3. 外部链接和恢复分别加入 TFYSwiftRouterDeepLink、TFYSwiftRouterRestoration。
4. 测试 Target 单独选择 TFYSwiftRouterTesting。
5. 也可以只给 App 选择聚合产品 TFYSwiftRouterKit；聚合产品不包含 Testing。

在另一个 Package 的清单中，本地接入形式如下。路径应替换为该 Package 相对于本仓库的位置：

~~~swift
dependencies: [
    .package(path: "../TFYSwiftRouterKit")
],
targets: [
    .target(
        name: "Feature",
        dependencies: [
            .product(name: "TFYSwiftRouterCore", package: "TFYSwiftRouterKit"),
            .product(name: "TFYSwiftRouterUIKit", package: "TFYSwiftRouterKit")
        ]
    )
]
~~~

远端 `2.0.0` Tag 发布后，可使用：

~~~swift
dependencies: [
    .package(
        url: "https://github.com/13662049573/TFYSwiftRouterKit.git",
        from: "2.0.0"
    )
]
~~~

在 Xcode 中添加时填写同一仓库 URL，Dependency Rule 选择 Up to Next Major Version，起始版本为 `2.0.0`。SwiftPM 从 Git Tag 解析版本，Package.swift 不声明 `version`；本地未提交的改动不会出现在远端依赖中。

### 1.3 CocoaPods 接入

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

需要验证工作区源码，或者 `2.0.0` 尚未发布到 Specs 仓库时，再使用本地路径：

Podfile 与仓库并列时，可以使用：

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

执行 pod install 后打开生成的 xcworkspace。按需加载时，可将默认 Pod 替换为 Core、UIKit、SwiftUI、DeepLink、Restoration 子规格。

CocoaPods 的模块名统一为 TFYSwiftRouterKit，不是每个子规格一个 Swift module：

~~~swift
import TFYSwiftRouterKit
~~~

### 1.4 产品选择表

| 产品/目录 | 包含能力 | 建议依赖位置 |
|---|---|---|
| TFYSwiftRouterCore / Core | Route、协议、Router、Input、Session、Service、Scope、事件 | Interface 与业务逻辑 |
| TFYSwiftRouterUIKit / UIKit | 页面工厂、导航驱动、Assembly、组件注册协议 | UIKit Implementation、App |
| TFYSwiftRouterSwiftUI / SwiftUI | View 工厂、NavigationStack、RouterHost | SwiftUI Implementation |
| TFYSwiftRouterDeepLink / DeepLink | URL 白名单、Parser、解析引擎 | App 外部入口 |
| TFYSwiftRouterRestoration / Restoration | Codable 地址、快照、迁移、恢复 | App Scene/Flow |
| TFYSwiftRouterTesting / Testing | 调用记录、结果 Provider、会话替身 | 测试 Target |
| TFYSwiftRouterKit / Umbrella | 以上运行时模块，不含 Testing | 小型 App 便捷接入 |

## 2. 理解五个核心对象

| 名称 | 职责 | 不应该放什么 |
|---|---|---|
| Route | “去哪个业务地址”，例如商品 ID | UIViewController、View、闭包、服务实例 |
| Registry / Resolver | 根据地址决定 Destination 标识 | 全局页面单例 |
| Destination Factory | 用地址和上下文创建页面 | 跨组件直接访问其他页面的私有实现 |
| Driver | 在对应导航容器中执行展示/回退 | 业务鉴权规则 |
| Router | 组织拦截、解析、去重、展示、结果和事件 | 全局 shared 状态 |

一次普通请求的主要过程：

~~~text
业务对象 → Router 创建事务 → Interceptor
                              ├─ reject：返回错误
                              ├─ redirect：换地址后重新拦截
                              ├─ suspend：等待条件后重新拦截
                              └─ proceed
                                  ↓
                              地址去重
                                  ↓
                       Registry → Destination Factory
                                  ↓
                          Scope → 平台 Driver
                                  ↓
                           展示 / 等待最终结果
~~~

Scope 是“哪个导航容器”，Presentation 是“怎么展示”，Source 是“谁发起”，Metadata 是“附加业务追踪信息”。它们不是 Route 的组成部分。

业务类尽量持有 any TFYSwiftRouting；App 组合根持有具体 Assembly 和 Router。只有需要诊断、恢复、动态注册等基础设施能力时才直接依赖具体对象。

## 3. 从空项目跑通第一次跳转

下面是可以放进 UIKit Scene 项目的最小完整流程。前提是已经添加 Core 和 UIKit 产品，并关闭旧 Storyboard 的自动根页面创建，改用 SceneDelegate 创建 UIWindow。

### 3.1 新建 FirstFlow.swift

~~~swift
import UIKit
import TFYSwiftRouterCore
import TFYSwiftRouterUIKit

// 地址必须能比较并安全跨并发边界传递。
enum FirstRoute: TFYSwiftRoute {
    case home
    case detail(id: String)
}

@MainActor
final class FirstFlow {
    let navigationController = UINavigationController()
    let assembly: TFYSwiftRouterAssembly

    init() throws {
        assembly = TFYSwiftRouterAssembly(
            navigationController: navigationController
        )
        let router = assembly.router

        // 一次登记该地址类型的 Resolver 和页面工厂。
        try assembly.register(FirstRoute.self) { [weak router] route, _ in
            switch route {
            case .home:
                let page = UIViewController()
                page.title = "第一个首页"
                page.view.backgroundColor = .systemBackground
                var config = UIButton.Configuration.filled()
                config.title = "打开商品 1001"
                let button = UIButton(configuration: config)
                button.addAction(UIAction { [weak router] _ in
                    Task { @MainActor in
                        do {
                            try await router?.open(
                                FirstRoute.detail(id: "1001"),
                                presentation: .push()
                            )
                        } catch {
                            // 正式项目可改成页面错误提示或统一日志。
                            print(error.localizedDescription)
                        }
                    }
                }, for: .touchUpInside)
                button.translatesAutoresizingMaskIntoConstraints = false
                page.view.addSubview(button)
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: page.view.centerXAnchor),
                    button.centerYAnchor.constraint(equalTo: page.view.centerYAnchor)
                ])
                return page

            case .detail(let id):
                let page = UIViewController()
                page.title = "商品 \(id)"
                page.view.backgroundColor = .systemGroupedBackground
                return page
            }
        }
    }

    func start() async throws {
        try await assembly.router.open(
            FirstRoute.home,
            presentation: .root(animated: false),
            source: .programmatic
        )
    }
}
~~~

这里弱捕获 router 是为了避免 Router → Registry → Factory → Router 的闭环。Factory 中需要使用长生命周期服务时，可以捕获独立服务；捕获回整个组合根时尤其要检查环。

### 3.2 接到 SceneDelegate

~~~swift
import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var flow: FirstFlow?
    private var startupTask: Task<Void, Never>?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        do {
            let flow = try FirstFlow()
            self.flow = flow
            window.rootViewController = flow.navigationController
            window.makeKeyAndVisible()
            startupTask = Task { @MainActor in
                do { try await flow.start() }
                catch { print("根路由安装失败：\(error)") }
            }
        } catch {
            let fallback = UIViewController()
            fallback.view.backgroundColor = .systemBackground
            fallback.title = "路由装配失败"
            window.rootViewController = fallback
            window.makeKeyAndVisible()
            print(error)
        }
    }

    deinit { startupTask?.cancel() }
}
~~~

运行后应看到“第一个首页”。点击按钮后打开“商品 1001”，系统返回按钮可返回首页。

必须强持有 flow/assembly 和 UINavigationController。UIKit Driver 对导航容器使用弱引用，不能靠 Router 保活整个窗口。

## 4. 拆分组件并安装四个 Tab

### 4.1 推荐依赖方向

~~~text
App
 ├─ HomeImplementation ── HomeInterface ── Core
 ├─ ProductImplementation ── ProductInterface ── Core
 ├─ CartImplementation ── CartInterface ── Core
 └─ ProfileImplementation ── ProfileInterface ── Core

HomeImplementation → ProductInterface、CartInterface、ProfileInterface
各 Implementation → 对应 UIKit 或 SwiftUI 适配模块
~~~

Interface 存 Route、Input、Output、Command、Event、服务协议和键；Implementation 存页面、服务实现、Resolver、工厂和 Module。App 选择实现并注入依赖。

Demo 为便于运行，源码在一个 App Target 中按目录模拟上述边界。真正独立编译时，跨 Target 使用的类型、属性、方法和初始化器需要 public，不能只给最外层类型加 public。

### 4.2 一个真正的组件接入入口

下面 ProductModule 的页面是最小占位实现，可替换成组件内私有的实际控制器：

~~~swift
import UIKit
import TFYSwiftRouterCore
import TFYSwiftRouterUIKit

public enum ProductRoute: TFYSwiftRoute, Codable {
    case root
    case detail(id: String)
}

@MainActor
public struct ProductModule: TFYSwiftUIKitComponentModule {
    public let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: "app.products",
        route: ProductRoute.root
    )

    public init() {}

    public func register(in assembly: TFYSwiftRouterAssembly) throws {
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
    }
}
~~~

一个 Route 枚举可以对应一个统一工厂，也可以由 Resolver 将不同 case 分发到多个 identifier。后一种方式必须为每个 identifier 分别登记工厂，见 Demo 的 HomeModule 与 CartModule。

### 4.3 四个容器的组装顺序

以下是组装阶段代码；HomeModule、CartModule、ProfileModule 需要按 ProductModule 的方式实现，并让 rootRegistration.scope 与下面的 Scope 一致。

~~~swift
let home = UINavigationController()
let products = UINavigationController()
let cart = UINavigationController()
let profile = UINavigationController()
let tabs = UITabBarController()
tabs.viewControllers = [home, products, cart, profile]

let assembly = TFYSwiftRouterAssembly(
    navigationController: home,
    initialScope: "app.home"
)
try assembly.register(navigationController: products, for: "app.products")
try assembly.register(navigationController: cart, for: "app.cart")
try assembly.register(navigationController: profile, for: "app.profile")

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
~~~

先注册容器，再注册组件，最后安装根路由。registerComponents 会检查本批次重复根 Scope 和未登记 Scope，并在组件登记失败时回滚地址表与页面表。它不会自动打开根页面。

### 4.4 跨 Tab 跳转有两个动作

~~~swift
tabs.selectedIndex = 1
try await assembly.router.open(
    ProductRoute.detail(id: "1001"),
    scope: "app.products",
    deduplication: .singleTop
)
~~~

Scope 只定位容器，不会替 App 选择 Tab。实际项目把上述两步封装到业务导航协议，Demo 的 TFYSwiftDemoNavigating / TFYSwiftDemoTabRouter 就是这个角色。

每个窗口可以拥有独立 Assembly，或者由 App 为不同窗口登记独立 Scope。关闭窗口之前，由拥有者取消该流程的 Session，再移除 Scope；unregister 不会自动完成业务清理。

## 5. 地址与完整模型输入

### 5.1 小地址、大模型分离

~~~swift
struct ProductInput: Sendable {
    let id: String
    let name: String
    let tags: [String]
}

// 使用第 4 节的 ProductRoute。
let input = ProductInput(id: "1001", name: "路由实践", tags: ["Swift"])
try await assembly.router.open(
    ProductRoute.detail(id: input.id),
    input: input,
    scope: "app.products"
)
~~~

Input 只要求 Sendable，不要求 Hashable 或 Codable。它不参与 Route 去重，也不会自动写入 URL 或导航快照。

在已登记的工厂里读取：

~~~swift
let model: ProductInput = try context.input()
// 或显式写类型：try context.input(as: ProductInput.self)
~~~

如果同一地址也允许从 Deep Link/恢复进入，输入可能不存在。应先判断 context.inputPayload 是否存在：有输入则验证类型，没有则根据 Route 中的 ID 加载模型。不要使用 try? 隐藏“实际传入了错误类型”的错误。

~~~swift
let model: ProductInput
if context.inputPayload != nil {
    model = try context.input()
} else {
    // 本例用地址创建占位数据；正式项目交给页面/服务异步加载。
    model = ProductInput(id: id, name: "待加载", tags: [])
}
~~~

### 5.2 地址相等性的影响

相同 Route 类型且关联值相等，才会被当作同一地址。若每次创建地址都加入随机 UUID，那么 singleTop/singleTask 不会命中。

TFYSwiftAnyRoute 只用于基础设施边界。业务 API 优先使用原始 Route；Parser、根路由注册和恢复引擎才通常需要类型擦除。

~~~swift
let erased = TFYSwiftAnyRoute(ProductRoute.detail(id: "1001"))
let restored: ProductRoute? = erased.cast(to: ProductRoute.self)
~~~

## 6. 单次返回值与强类型契约

### 6.1 固定输入输出用 RouteContract

~~~swift
struct PickerRoute: TFYSwiftRouteContract {
    typealias Input = [String]
    typealias Output = String
}
~~~

契约只约束调用点，不会取消平台工厂处的运行期验证。工厂仍需读取正确 Input，并使用正确类型完成 Result。

### 6.2 一个完整的返回值页面

~~~swift
import UIKit
import TFYSwiftRouterCore

@MainActor
final class PickerPage: UITableViewController {
    private let options: [String]
    private let result: TFYSwiftRouteResult?

    init(options: [String], result: TFYSwiftRouteResult?) {
        self.options = options
        self.result = result
        super.init(style: .insetGrouped)
        title = "请选择"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("使用 init(options:result:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in
                self?.result?.cancel()
                self?.dismiss(animated: true)
            }
        )
    }

    override func tableView(
        _ tableView: UITableView, numberOfRowsInSection section: Int
    ) -> Int { options.count }

    override func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = options[indexPath.row]
        return cell
    }

    override func tableView(
        _ tableView: UITableView, didSelectRowAt indexPath: IndexPath
    ) {
        result?.finish(with: options[indexPath.row])
        dismiss(animated: true)
    }
}
~~~

在组合根登记：

~~~swift
try assembly.register(PickerRoute.self) { _, context in
    UINavigationController(rootViewController: PickerPage(
        options: try context.input(),
        result: context.result
    ))
}
~~~

调用：

~~~swift
let selected = try await assembly.router.openTyped(
    PickerRoute(),
    input: ["Swift", "UIKit", "SwiftUI"],
    presentation: .sheet()
)
// selected 已被推导为 String。
~~~

也可用基础 API，适合一个枚举不同 case 有不同交互形式的旧代码：

~~~swift
let selected: String = try await assembly.router.open(
    PickerRoute(),
    input: ["Swift", "UIKit"],
    presentation: .sheet(),
    expecting: String.self
)
~~~

没有输入时，使用不含 input 的 open 重载。契约输入为 Void 时传 input: ()。

### 6.3 两个必须分开的操作

result.finish(with:) 只完成结果等待，不会替你 pop/dismiss。页面应根据其呈现方式关闭自己，或通过注入的业务导航接口关闭。

结果返回时 UIKit 动画可能尚未结束。若调用方马上展示 Alert 或下一个 Sheet，应等待实际转场完成。实验室使用 transitionCoordinator/完成回调处理这一点，而不是固定延时。

## 7. 命令事件和最终输出

### 7.1 定义四种通信类型

~~~swift
struct EditorInput: Sendable { let initialText: String }
struct EditorOutput: Sendable { let savedText: String }
enum EditorCommand: Sendable { case replaceText(String) }
enum EditorEvent: Sendable { case preview(String) }

struct EditorRoute: TFYSwiftSessionRouteContract {
    typealias Input = EditorInput
    typealias Output = EditorOutput
    typealias Command = EditorCommand
    typealias Event = EditorEvent
    let documentID: String
}
~~~

| 方向 | API | 用途 |
|---|---|---|
| 调用方 → 目标页，一次输入 | input / context.input | 完整初始模型 |
| 调用方 → 目标页，多次指令 | session.send / context.commands | 刷新、替换、设置选中项 |
| 目标页 → 调用方，多次事件 | context.send / session.events | 收藏、分享、预览、状态变化 |
| 目标页 → 调用方，一次结束 | context.result.finish / session.value | 最终确认结果 |

### 7.2 目标页面处理命令和事件

以下页面按 push 使用，完成后 pop；如果改成 sheet，应相应改为 dismiss：

~~~swift
@MainActor
final class EditorPage: UIViewController {
    private let context: TFYSwiftDestinationContext
    private let field = UITextField()
    private var text: String
    private var commandTask: Task<Void, Never>?

    init(input: EditorInput, context: TFYSwiftDestinationContext) {
        self.text = input.initialText
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("使用指定初始化器") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑"
        view.backgroundColor = .systemBackground
        field.text = text
        field.borderStyle = .roundedRect
        field.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            field.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "保存", primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                context.result?.finish(with: EditorOutput(savedText: field.text ?? ""))
                navigationController?.popViewController(animated: true)
            }),
            UIBarButtonItem(title: "预览", primaryAction: UIAction { [weak self] _ in
                guard let self else { return }
                do { try context.send(EditorEvent.preview(field.text ?? "")) }
                catch { print(error) }
            })
        ]

        // 捕获独立 context，并在每次收到命令时才短暂取得 self。
        commandTask = Task { @MainActor [weak self, context] in
            do {
                let commands: AsyncStream<EditorCommand> = try context.commands()
                for await command in commands {
                    guard let self else { return }
                    switch command {
                    case .replaceText(let value): field.text = value
                    }
                }
            } catch { print(error) }
        }
    }

    deinit { commandTask?.cancel() }
}

try assembly.register(EditorRoute.self) { _, context in
    EditorPage(input: try context.input(), context: context)
}
~~~

不要在进入无限 for await 之前强持有 self 再依赖 deinit 取消；这可能形成页面 → Task → 页面的循环。

### 7.3 调用方完整流程

放在 @MainActor 的业务流程方法内：

~~~swift
let session = assembly.router.openTypedSession(
    EditorRoute(documentID: "draft-1"),
    input: EditorInput(initialText: "Hello"),
    presentation: .push()
)
let observer = session.observeEvents { event in
    switch event {
    case .preview(let text): print("实时预览：\(text)")
    }
}
defer {
    observer.cancel()
    session.cancel() // 完成后的取消是幂等清理。
}
try session.send(.replaceText("由调用方更新"))
let output = try await session.value
await observer.value // 通道结束后，等已缓冲事件处理完。
print(output.savedText)
~~~

也可省略契约，显式传递类型：

~~~swift
let session = assembly.router.openSession(
    EditorRoute(documentID: "draft-1"),
    input: EditorInput(initialText: ""),
    presentation: .push(),
    commands: EditorCommand.self,
    events: EditorEvent.self,
    expecting: EditorOutput.self
)
~~~

observeEvents 与 for await session.events 二选一。AsyncStream 是单消费者通信，不是广播总线；并行迭代同一个流不能保证每个观察者都收到每个事件。

## 8. 取消超时与生命周期

### 8.1 谁负责结束什么

| 对象 | 完成/取消方式 | UI 是否自动关闭 |
|---|---|---|
| Result | finish(with:) / cancel() | 否 |
| Session | cancel() | 否 |
| 命令/事件通道 | finish()，或交互完成后自动关闭 | 否 |
| 页面导航 | back、backToRoot、dismiss、dismissAll | 由驱动修改 UI |
| 自定义呈现 | App 自定义处理器和页面关闭逻辑 | 由 App 决定 |

常规内置驱动会取消被替换、移除或关闭页面的交互；UIKit 还通过页面释放和 Sheet 关闭代理处理结果取消。自定义容器、被额外强持有的控制器、App 自己设置的 presentation delegate，需要 App 明确管理关闭时机，不能把所有业务清理都寄托于 deinit。

### 8.2 普通结果超时

timeout 的单位是秒，计时范围包含该次 open 的拦截、解析、展示和结果等待：

~~~swift
do {
    let selected: String = try await assembly.router.open(
        PickerRoute(),
        input: ["Swift", "UIKit"],
        presentation: .sheet(),
        timeout: 15,
        expecting: String.self
    )
    print(selected)
} catch TFYSwiftRouteError.timeout {
    // 按业务决定是否关闭选择器，并等待 UI 转场结束后提示。
    try await assembly.router.dismissAll()
}
~~~

此便利重载位于具体 TFYSwiftRouter 上，不属于 TFYSwiftRouting 协议。需要保持业务协议抽象时，可以由自己的 Flow 服务封装超时，或使用协议创建 Session 后调用 value(timeout:)。

### 8.3 Session 超时与主动取消

~~~swift
let output = try await session.value(timeout: 30)
session.cancel()
~~~

Session 的 timeout 从调用 value(timeout:) 开始计算。超时结束结果等待和交互通道，不会自动移除目标页面。

Task 取消采用 Swift 协作式取消。业务 Resolver、挂起恢复闭包、测试 Provider 不应使用无法结束的等待；在长操作前后检查 Task.checkCancellation()，回调桥接必须保证 continuation 最终恢复一次。

取消观察事件的 Task 不等于取消整个会话。业务对象放弃流程时，应显式 session.cancel()。

### 8.4 不要滥用 try?

取消是业务允许的分支时，可以专门捕获 .cancelled；输入类型不匹配、注册缺失等应正常暴露，不能统一吞掉。

结果句柄具有单次完成保护。错误类型的 finish 会让等待方收到 resultTypeMismatch，不能靠后续再 finish 正确类型来修复同一个结果。

## 9. 跨组件服务调用

页面跳转用 Route；购物车增删、刷新缓存等“方法调用”用服务协议。

Interface：

~~~swift
public protocol CartServicing: TFYSwiftComponentService {
    func add(productID: String) async -> Int
    func count() async -> Int
}

public enum ServiceKeys {
    public static let cart = TFYSwiftComponentServiceKey<any CartServicing>()
}
~~~

Implementation：

~~~swift
public actor CartService: CartServicing {
    private var quantity = 0
    public init() {}
    public func add(productID: String) async -> Int {
        quantity += 1
        return quantity
    }
    public func count() async -> Int { quantity }
}
~~~

App 登记，调用方解析接口：

~~~swift
let services = TFYSwiftComponentServiceRegistry()
let cartService: any CartServicing = CartService()
try services.register(cartService, for: ServiceKeys.cart)

let cart = try services.resolve(ServiceKeys.cart)
let quantity = await cart.add(productID: "1001")
~~~

服务键由协议类型与可选 namespace 共同标识。两个未指定 namespace 的 ServiceKey<any CartServicing> 指向同一槽位；同一协议需要多个实例时，使用不同 namespace，名称由 App 的账户或场景定义。具体示例见第 21 节。

服务注册表在 MainActor 操作，服务内部的并发由服务实现负责。没有全局 shared；不同账户/Scene 可以使用不同容器。

## 10. 注册替换注销和事务

### 10.1 注册表之间的关系

| 表 | 键 | 值 | 查看清单 |
|---|---|---|---|
| RouteRegistry | Route 类型 | async Resolver | registeredRouteNames |
| UIKit/SwiftUI DestinationRegistry | identifier | 页面工厂 | registeredDestinationIDs |
| ScopedNavigationDriver | Scope | 独立驱动 | registeredScopes |
| ServiceRegistry | 协议类型键 | 服务实例 | contains / resolve |
| RestorationRegistry | Route 类型 + 稳定标识 | 编解码器 | registeredIdentifiers |
| InterceptorPipeline | identifier | 拦截器 | identifiers |
| DeepLinkEngine | identifier | Parser | await parserIdentifiers |

### 10.2 重复登记默认是错误

~~~swift
try assembly.routes.register(ProductRoute.self) { route, context in
    TFYSwiftDestinationDescriptor(identifier: "product.page")
}

// 明确需要替换时使用 replacingExisting。
try assembly.routes.register(ProductRoute.self, replacingExisting: true) {
    _, _ in TFYSwiftDestinationDescriptor(identifier: "product.v2")
}
~~~

替换 Resolver 后必须确保新的目标标识已经登记。它不会修改当前已经存在的页面。

Scope 的新接口会 throws：

~~~swift
try assembly.register(
    navigationController: products,
    for: "app.products",
    replacingExisting: true
)
~~~

ScopedDriver 旧版不抛错 register 已弃用。迁移时使用带 replacingExisting 的版本并处理错误。

### 10.3 批量原子登记

~~~swift
try assembly.routes.performRegistrationTransaction {
    try assembly.destinations.performRegistrationTransaction {
        try assembly.routes.register(ProductRoute.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "product.page")
        }
        try assembly.destinations.register(
            identifier: "product.page", routeType: ProductRoute.self
        ) { _, _ in UIViewController() }
    }
}
~~~

assembly.register(Route.self, factory:) 已经把两张表组合成上述回滚过程。registerComponents 同样回滚这两张表。

服务和 SwiftUI 工厂有各自的 performRegistrationTransaction：

~~~swift
try services.performRegistrationTransaction {
    try services.register(cartService, for: ServiceKeys.cart)
    // 后续登记抛错时恢复整个映射快照。
}
~~~

事务闭包是同步的。这里的“原子”只指注册映射：不回滚已经发送的网络请求、服务对象内部变化、模块自行添加的拦截器等外部副作用，也不是数据库事务。

### 10.4 显式注销

~~~swift
assembly.routes.unregister(ProductRoute.self)
assembly.destinations.unregister(identifier: "product.page")
assembly.scopedDriver.unregister(scope: "app.products")
services.unregister(ServiceKeys.cart)
~~~

地址、工厂和 Scope 是不同的表，需要按自己的模块生命周期配套处理。注销只影响后续查找，不自动取消已有页面或会话。

## 11. 呈现回退和去重

### 11.1 呈现能力表

| Presentation | UIKit | 原生 SwiftUI |
|---|---|---|
| automatic | Push | 追加 path |
| push(animated:) | 压入导航栈 | 追加 path |
| sheet(configuration) | pageSheet，配置 detents | sheet，绑定配置 |
| fullScreen(animated:) | 全屏模态 | fullScreenCover |
| replace(animated:) | 替换栈顶 | 替换 path 最后条目或 root |
| root(animated:) | 重建根栈并清理弹层 | 重建 root、清空 path/弹层 |
| custom(identifier) | App 注册处理器 | App 注册处理器 |
| newWindow | App 注册 Scene 处理器 | App 注册窗口处理器 |

当前 SwiftUI 驱动采用状态更新，未逐项映射 Presentation 中所有 animated 标志。UIKit 的 async 导航方法通常不等待动画真正结束；需要串联多个视觉转场时由 App 等待转场完成。

### 11.2 Sheet 示例

~~~swift
try await assembly.router.open(
    PickerRoute(),
    input: ["A", "B"],
    presentation: .sheet(.init(
        detents: [.medium, .large],
        prefersGrabberVisible: true,
        allowsInteractiveDismiss: false
    )),
    expecting: String.self
)
~~~

禁止交互关闭时，页面务必提供取消/完成按钮。需要 Sheet 内独立导航栏时，工厂返回 UINavigationController(rootViewController:)。

### 11.3 导航操作

~~~swift
try await assembly.router.back(scope: "app.products")
try await assembly.router.back(count: 2, scope: "app.products")
try await assembly.router.backToRoot(scope: "app.products")
try await assembly.router.dismiss(scope: "app.products")
try await assembly.router.dismissAll(scope: "app.products")

let all = assembly.router.routes(scope: "app.products")
let restorableStack = assembly.router.navigationRoutes(scope: "app.products")
~~~

back 作用于导航栈，dismiss 作用于模态层。查询方法返回内置驱动追踪的地址，不会自动把业务绕过 Router 创建的任意页面变成路由。

### 11.4 去重

| 策略 | 行为 |
|---|---|
| none | 每次请求创建新页面 |
| singleTop | 可见顶层地址相同时忽略本次创建 |
| ignoreIfTop | singleTop 的兼容别名，新代码推荐 singleTop |
| singleTask | 尝试激活已有地址并按驱动语义移除其上的页面；未命中则新建 |

带返回值或 Session 的请求建议使用 none：复用旧页面不能给旧交互绑定新的结果等待方，命中时会抛出 destinationUnavailable。去重是否命中由原始 Route 的 Hashable 语义决定，不比较 Input。

### 11.5 自定义呈现

~~~swift
assembly.driver.registerCustomPresentation(identifier: "fade") {
    source, destination, transaction in
    destination.modalPresentationStyle = .overFullScreen
    destination.modalTransitionStyle = .crossDissolve
    await withCheckedContinuation { continuation in
        source.present(destination, animated: true) {
            continuation.resume()
        }
    }
}
try await assembly.router.open(
    ProductRoute.detail(id: "1001"),
    presentation: .custom("fade")
)
~~~

处理器应负责显示、关闭和交互取消的完整约定。自定义容器不自动获得内置导航栈恢复能力。

### 11.6 newWindow 接入约定

newWindow 是扩展点。没有注册处理器时返回 sceneUnavailable，实验室有专门按钮展示这个边界。

App 可通过 registerNewWindowPresentation 安装处理器，把 transaction.route 转成可序列化的 NSUserActivity，交给 App 自己的 Scene 激活逻辑。新 Scene 收到活动后，创建自己的 Assembly、登记模块并从地址打开页面。不要把 UIViewController 或 Result 对象跨 Scene 序列化。

需要同时完成 App 的多 Scene 配置、活动类型声明，以及目标系统/设备的支持检查。当前 Demo 不会伪造一个新 Scene；它演示未接入时的错误，自定义淡入转场则有真实处理器。

## 12. 拦截器与登录恢复

### 12.1 放行、拒绝、重定向

~~~swift
@MainActor
final class ProductGuard: TFYSwiftRouteInterceptor {
    let identifier = "product.guard"

    func intercept(
        _ transaction: TFYSwiftRouteTransaction
    ) async -> TFYSwiftRouteInterceptionResult {
        guard let route = transaction.route.cast(to: ProductRoute.self) else {
            return .proceed
        }
        if case .detail(let id) = route, id.isEmpty {
            return .reject(.invalidPayload("商品 ID 不能为空"))
        }
        return .proceed
    }
}
assembly.interceptors.add(ProductGuard(), priority: 100)
~~~

重定向示例位于拦截器内：

~~~swift
return .redirect(TFYSwiftAnyRoute(ProductRoute.detail(id: "new-id")))
~~~

重定向保持事务 ID、Scope、Source、Metadata，替换地址后重新运行拦截器。若需切换 Scope/Tab，应由 App Flow 处理，而非期待 redirect 自动改变容器。

### 12.2 挂起原请求，登录后继续

~~~swift
@MainActor
final class LoginGuard: TFYSwiftRouteInterceptor {
    let identifier = "login"
    var isLoggedIn = false
    let login: @MainActor @Sendable () async throws -> Bool

    init(login: @escaping @MainActor @Sendable () async throws -> Bool) {
        self.login = login
    }

    func intercept(
        _ transaction: TFYSwiftRouteTransaction
    ) async -> TFYSwiftRouteInterceptionResult {
        guard !isLoggedIn else { return .proceed }
        return .suspend(TFYSwiftRouteSuspension(reason: "需要登录") { [weak self] in
            guard let self else { return false }
            let accepted = try await login()
            if accepted { isLoggedIn = true }
            return accepted
        })
    }
}
~~~

真实项目应先判断“该地址是否需要登录”，不要把登录页自身也拦截。恢复返回 true 后会重新检查，因此必须先改变登录状态，否则会一直挂起直到触发上限。

~~~swift
assembly.router.maximumRedirectDepth = 8
assembly.router.maximumSuspensionDepth = 8
assembly.interceptors.remove(identifier: "login")
~~~

Demo 购物车结算和“我的订单”提供真实模拟登录弹窗。实验室提供独立的拒绝、重定向和重复挂起保护探针。App 的登录闭包在没有可用 presenter、用户取消、Task 取消时都应结束，不能留下永远不恢复的 continuation。

## 13. Deep Link 与 Universal Link

### 13.1 Parser 只做外部输入到地址的转换

~~~swift
import Foundation
import TFYSwiftRouterCore
import TFYSwiftRouterDeepLink

struct ProductParser: TFYSwiftDeepLinkParser {
    let identifier = "product.links"

    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
        let url = request.url
        let parts = url.pathComponents.filter { $0 != "/" }
        let isCustom = url.scheme?.lowercased() == "shop"
        let resource = isCustom ? url.host : parts.first
        guard resource == "product" else { return nil }
        let id = isCustom ? parts.first : parts.dropFirst().first
        guard let id, !id.isEmpty, id.count <= 64 else {
            throw TFYSwiftRouteError.invalidPayload("商品 ID 必须为 1...64 个字符")
        }
        return TFYSwiftAnyRoute(ProductRoute.detail(id: id))
    }
}

let engine = TFYSwiftDeepLinkEngine(
    policy: .app(scheme: "shop", universalLinkHosts: ["example.com"])
)
await engine.add(ProductParser(), priority: 100)
~~~

支持的例子：shop://product/1001 与 https://example.com/product/1001。

同 identifier 再 add 会替换 Parser。优先级越大越先执行；相同优先级按登记顺序。Parser 返回 nil 继续下一个，抛错则终止此次解析。

~~~swift
let names = await engine.parserIdentifiers
await engine.remove(identifier: "product.links")
~~~

### 13.2 从 URL 打开地址

单 Scope：

~~~swift
try await assembly.router.open(
    TFYSwiftDeepLinkRequest(url: url, source: .deepLink),
    using: engine,
    scope: "app.products"
)
~~~

多 Tab：先解析判断所属组件，再选 Tab，最后打开。不要根据未经验证的任意 URL 直接创建页面。

~~~swift
let request = TFYSwiftDeepLinkRequest(url: url, source: .universalLink)
let route = try await engine.route(for: request)
tabs.selectedIndex = 1
try await assembly.router.open(
    route,
    source: request.source,
    scope: "app.products",
    metadata: request.metadata,
    deduplication: .singleTop
)
~~~

### 13.3 App 入口需要覆盖冷启动和运行中

冷启动从 connectionOptions.urlContexts 或 connectionOptions.userActivities 取 URL。热启动分别处理 scene(_:openURLContexts:) 与 scene(_:continue:)。

仓库 SceneDelegate 已覆盖两种冷启动来源。AppCoordinator.start() 会先安装根路由，Deep Link 再打开目标，避免“目标页面先打开，随后根页安装又覆盖”的竞态。

自定义 Scheme 需要在 App 的 URL Types 中配置。Universal Link 还需要 App 的 Associated Domains 和对应域名服务端关联文件；Parser 白名单并不会替你完成系统关联。本仓库 router.tfy.com 是演示白名单，不代表已经为你的 Bundle ID 配置了可用关联。

### 13.4 校验边界

引擎校验 URL 总长度、Scheme 白名单、HTTP/HTTPS Host 白名单，以及禁止 user/password 凭据。业务 ID 长度、资源是否存在、权限、query 参数仍由 Parser/业务服务负责。

推送入口可以直接构造 Route，并设置 source: .pushNotification；不要求把所有内部导航先变成 URL。

## 14. UIKit 与原生 SwiftUI

### 14.1 UIKit 中托管 SwiftUI View

保持 UIKit Driver，只把某个目标工厂改为 SwiftUI：

~~~swift
import SwiftUI
try assembly.routes.register(ProductRoute.self) { _, _ in
    TFYSwiftDestinationDescriptor(identifier: "product.swiftui")
}
try assembly.destinations.registerSwiftUI(
    identifier: "product.swiftui",
    routeType: ProductRoute.self
) { route, context in
    Text("商品地址：\(String(describing: route))")
}
~~~

如果此前已登记 ProductRoute，应选择替换已有 Resolver 或采用另一地址类型，而不是直接重复登记。此方式使用 UIHostingController，导航仍由 UIKit 管理。

### 14.2 原生 NavigationStack 的最小完整例子

原生方式使用 TFYSwiftSwiftUINavigationDriver 与 TFYSwiftSwiftUIRouterHost。以下例子可独立作为 SwiftUI App 的根 View：

~~~swift
import SwiftUI
import Combine
import TFYSwiftRouterCore
import TFYSwiftRouterSwiftUI

enum NativeRoute: TFYSwiftRoute { case detail }

@MainActor
final class NativeModel: ObservableObject {
    let driver: TFYSwiftSwiftUINavigationDriver
    let router: TFYSwiftRouter
    @Published var errorMessage: String?

    init() throws {
        let driver = TFYSwiftSwiftUINavigationDriver()
        self.driver = driver
        router = TFYSwiftRouter(driver: driver)
        try router.registry.register(NativeRoute.self) { _, _ in
            TFYSwiftDestinationDescriptor(identifier: "native.detail")
        }
        try driver.destinations.register(
            identifier: "native.detail", routeType: NativeRoute.self
        ) { _, _ in
            Text("原生 SwiftUI 详情").navigationTitle("详情")
        }
    }

    func open() async {
        do { try await router.open(NativeRoute.detail) }
        catch { errorMessage = error.localizedDescription }
    }
}

@MainActor
struct NativeRoot: View {
    @StateObject private var model: NativeModel

    init(model: NativeModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        TFYSwiftSwiftUIRouterHost(driver: model.driver) {
            VStack {
                Button("打开详情") {
                    Task { await model.open() }
                }
                if let error = model.errorMessage { Text(error) }
            }
            .navigationTitle("首页")
        }
    }
}
~~~

在 App/Scene 的组装处使用 do/catch 创建 NativeModel，再传给 NativeRoot。抛错的初始化器应在 StateObject 的非抛错 autoclosure 之外执行。具体写法可直接参考 Demo 的 TFYSwiftDemoNativeRouterView.init()。

### 14.3 工厂错误不会悄悄变成成功导航

驱动在改写 path/sheet/fullScreen 前创建 View；工厂抛错时 open 向调用者抛错，路径保持原样。实验室“验证工厂错误回传”会展示路径数量 0 → 0。

需要注意：这里验证的是同步 View 工厂创建。View 内部之后启动的异步网络请求失败，不会自动变成本次 open 的错误，应由 View 的业务状态呈现。

### 14.4 状态、交互与所有权

RouterHost 的 Binding 把用户返回同步到驱动；路径移除时取消交互。替换 Sheet、替换栈顶、重建根页会结束旧交互。

工厂缓存的 AnyView 可能长期保存在驱动中。如果 View 强持有拥有该驱动的模型，应审查 model → driver → entry.content → model 的闭环。Demo 的目标页使用弱引用流程模型，工厂也弱捕获模型。

## 15. 持久化快照和版本迁移

### 15.1 只登记允许持久化的地址

第 4 节 ProductRoute 已遵守 Codable。登记时使用长期稳定的 identifier，而不是随 Swift 模块名变化的反射类型名：

~~~swift
import TFYSwiftRouterRestoration

let codecs = TFYSwiftRestorationRegistry()
try codecs.register(ProductRoute.self, identifier: "product.route")
let restoration = TFYSwiftRestorationCoordinator(
    registry: codecs,
    router: assembly.router,
    currentSchemaVersion: 1
)
~~~

Input、Command、Event、Output、页面、Result 句柄不会保存；恢复时是新的普通导航，页面根据地址 ID 重新加载数据。

### 15.2 生成、编码、存储

~~~swift
let snapshot = try restoration.makeSnapshot(
    scopes: ["app.products"],
    unrestorableRoutePolicy: .fail
)
let data = try JSONEncoder().encode(snapshot)
UserDefaults.standard.set(data, forKey: "navigation.snapshot")
~~~

UserDefaults 只用于小型演示。生产应用按数据量选择文件/数据库，并自行处理保存时机、过期、账户切换和隐私。框架不包含自动磁盘存储服务。

默认 fail：遇到未登记编解码器的地址时报错。skip：忽略该地址，可能改变页面之间的父子关系，应明确接受这个后果。

~~~swift
let partial = try restoration.makeSnapshot(
    scopes: ["app.products"],
    unrestorableRoutePolicy: .skip
)
~~~

### 15.3 恢复

~~~swift
if let data = UserDefaults.standard.data(forKey: "navigation.snapshot") {
    let snapshot = try JSONDecoder().decode(TFYSwiftNavigationSnapshot.self, from: data)
    try await restoration.restore(snapshot)
}
~~~

在恢复前先完成 Scope、Route 和 Destination 注册。恢复会运行正常拦截器，登录过期时仍可能挂起或拒绝。

恢复过程：

1. 检查版本并执行迁移。
2. 检查重复 Scope。
3. 解码所有地址；未知标识或损坏 payload 在修改导航前失败。
4. 对非空 Scope 的第一条地址执行 root(false)，之后逐条 push(false)。
5. 任意运行期路由错误会带上 Scope 和页面序号返回。

完整解码成功不代表运行期展示一定成功。驱动不可用、鉴权拒绝、工厂异常等可能导致部分页面已经恢复；当前没有整个 UI 操作的自动回滚。空 Scope 快照不清空已有栈。选中的 Tab、滚动位置、编辑草稿和弹层不在此快照中，App 需要另外保存。

### 15.4 版本迁移

~~~swift
let restorationV2 = TFYSwiftRestorationCoordinator(
    registry: codecs, router: assembly.router, currentSchemaVersion: 2
)
try restorationV2.registerMigration(fromVersion: 1) { old in
    // 本例载荷没变，只升级版本；真实变更需在这里转换标识和 payload。
    TFYSwiftNavigationSnapshot(
        schemaVersion: 2,
        createdAt: old.createdAt,
        scopes: old.scopes
    )
}
try await restorationV2.restore(oldSnapshot)
~~~

迁移结果必须严格提升版本且不能超过当前版本。缺失迁移、重复迁移登记、未来版本快照都会报错。

当 Route 的 Codable 结构真的发生变化时，保留旧 DTO，解码旧 payload 后转换为新 DTO，再构建新的描述符。不要只把 schemaVersion 改大就认为字段迁移完成。

### 15.5 Demo 的实际持久化

实验室仅持久化隔离 Scope 的 TFYSwiftDemoLabRoute。存储键为 TFYSwiftRouterKit.lab.snapshot.v2。进入 A/B 页点击“保存此导航栈”，返回实验室点击“恢复已保存快照”，可以验证重建导航栈。退出并重新进入实验室后该快照仍存在。

“v1 → v2 迁移并恢复”会构造旧版的根页 + A 地址，执行真实迁移和恢复，再显示新版本与页面数量。

## 16. 事件观察和诊断记录

### 16.1 订阅历史

~~~swift
let history = TFYSwiftRouteHistory(capacity: 200)
assembly.events.add(history)
history.onChange = {
    // 刷新自己的诊断 UI；捕获页面时使用 weak。
}
~~~

EventCenter 弱持有观察者，所以 history 必须由 Scene/Flow 等对象持有。把临时 History 直接传给 add 后不保留，它可能立即释放。

主要事件包括 created、interceptStarted、suspended、resumed、redirected、deduplicated、resolved、presentStarted、presented、completed、cancelled、failed。

普通无返回值导航在展示请求完成后 completed；结果导航的 completed 指最终值已返回。耗时从上下文创建时间计算，不等于 UIKit 动画结束或页面网络数据加载完成。

### 16.2 状态容量和手工清理

~~~swift
assembly.router.transactionStateCapacity = 500
let states = assembly.router.transactionStates

if let id = states.keys.first {
    assembly.router.removeTransactionState(id: id)
}
assembly.router.removeAllTransactionStates()
history.removeAll()
~~~

transactionStates 是有界诊断记录，不是永久事务数据库。容量回收或手动清理不会取消实际运行中的事务，也不会修改页面导航栈。

history.capacity 应保持正数。建议在初始化时决定容量；事件历史与事务状态是两套独立缓存。

### 16.3 Metadata 追踪

~~~swift
try await assembly.router.open(
    ProductRoute.detail(id: "1001"),
    source: .pushNotification,
    scope: "app.products",
    metadata: .init(
        values: ["entry": "campaign"],
        traceID: UUID().uuidString
    )
)
~~~

Metadata 保存在请求上下文，Resolver/Interceptor 可以读取。当前标准 RouteEvent 不直接包含完整 Metadata；若日志需要它，可在拦截器/Resolver 中记录，或在业务外层维护 traceID 与 transactionID 的关联。

## 17. 测试业务导航

### 17.1 基于协议注入

~~~swift
@MainActor
final class ProductFlow {
    private let router: any TFYSwiftRouting
    init(router: any TFYSwiftRouting) { self.router = router }

    func showProduct(id: String) async throws {
        try await router.open(
            ProductRoute.detail(id: id),
            presentation: .push(),
            source: .userInteraction,
            scope: "app.products",
            metadata: .empty,
            deduplication: .singleTop
        )
    }
}
~~~

### 17.2 测试 Target 单独依赖 Testing

~~~swift
import XCTest
import TFYSwiftRouterCore
import TFYSwiftRouterTesting

final class ProductFlowTests: XCTestCase {
    @MainActor
    func testProductNavigation() async throws {
        let router = TFYSwiftTestRouter()
        let flow = ProductFlow(router: router)
        try await flow.showProduct(id: "1001")

        XCTAssertEqual(router.actions, [
            .open(
                route: TFYSwiftAnyRoute(ProductRoute.detail(id: "1001")),
                presentation: .push()
            )
        ])
        XCTAssertEqual(router.invocations.last?.scope, "app.products")
        XCTAssertEqual(router.invocations.last?.deduplication, .singleTop)
    }
}
~~~

actions 用于简化动作断言；invocations 额外包含 Source、Scope、Metadata、去重和输入类型名称。当前不保存完整输入值，若需断言模型字段，请在业务 Flow 的其他依赖上验证，或使用真实驱动测试工厂收到的 context.input。

### 17.3 注入同步/异步结果

~~~swift
let mock = TFYSwiftTestRouter()
mock.provide(String.self) { "默认值" }
mock.provide(for: PickerRoute()) { "此路由专用结果" }

let value = try await mock.openTyped(
    PickerRoute(), input: ["A"], presentation: .sheet()
)
assert(value == "此路由专用结果")
~~~

只有按结果类型配置异步 Provider 时，使用 asyncResult 标签：

~~~swift
mock.provide(String.self, asyncResult: {
    try Task.checkCancellation()
    return "异步结果"
})
~~~

可以通过 mock.interaction(for:) 模拟目标会话发送事件。实验室 testingProbe 在 Provider 内获取交互，避免依赖固定次数 Task.yield。当前该查询按地址定位，同地址并发会话不应作为此替身的多实例身份测试。

### 17.4 运行仓库验证

~~~sh
swift test

xcodebuild test \
  -project TFYSwiftRouterKit.xcodeproj \
  -scheme TFYSwiftRouterKit \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -only-testing:TFYSwiftRouterKitTests \
  CODE_SIGNING_ALLOWED=NO
~~~

模拟器名称应替换为本机已安装设备。界面测试在 TFYSwiftRouterKitUITests，新增测试名都以 testLaboratory 开头，覆盖选择器返回、结果超时、注册/拦截/解析探针、快照迁移恢复、SwiftUI 工厂失败与 Sheet。

## 18. Demo 操作手册

### 18.1 启动

打开 TFYSwiftRouterKit.xcodeproj，选择 TFYSwiftRouterKit Scheme 和 iOS 模拟器，运行后看到首页、商品、购物车、我的四个 Tab。

首页第一组点击“路由能力实验室”。实验室以独立全屏导航容器打开，右上角关闭回到四 Tab。实验室的 Root/恢复不会覆盖业务 Tab。

### 18.2 业务四组件已有入口

| 入口 | 操作 | 观察 |
|---|---|---|
| 首页 → Home → Product 双向会话 | 点击收藏、分享、完成 | 命令改变商品页状态；连续事件和最终结果回到首页 |
| 首页 → Home → Cart 服务 + 路由 | 跳到购物车 | 商品通过服务加入，不依赖购物车页面类型 |
| 购物车 → 结算 | 模拟登录，选择优惠券，提交 | 挂起恢复、嵌套 Sheet 返回、订单输出 |
| 首页 → Home → Profile 跨 Tab | 打开用户页 | 选中 Profile Tab，在其 Scope 导航 |
| 首页 → Deep Link → Product Tab | 点击示例链接 | 校验/解析后选商品 Tab 并打开 |
| 首页 → Router Inspector | 查看历史 | 四个 Tab 共用事件中心，Scope 分开 |

### 18.3 实验室新增入口逐项验收

| 入口 | 操作/预期 |
|---|---|
| 强类型 Input → Output | 选 SwiftUI，看到“强类型返回成功”和选中值 |
| 强类型双向会话 | 商品页收到 updateBadge(8)，收藏/分享后完成显示事件与结果 |
| 结果等待超时（3 秒） | 不选择，选择器关闭并显示“路由已超时”；提前点击则正常返回 |
| 会话等待超时（5 秒） | 不完成，返回实验室并显示超时；提前完成可正常结束 |
| 主动取消会话 | 创建后立即 cancel，显示取消结果 |
| Push 与导航操作 | A 页可继续 Push B、Replace、Root、Back 多层、BackToRoot |
| Sheet 配置 | 展示大尺寸弹层，支持拖拽关闭 |
| FullScreen | 全屏展示目标页，使用 Dismiss 关闭 |
| 自定义淡入转场 | 真实调用 lab.fade 处理器 |
| 新窗口接入边界 | 展示未注册 Scene 处理器时的错误和接入说明 |
| singleTop 去重 | 连续打开 A 两次，根 + A 共两页 |
| singleTask 复用 | 先 A、B，再激活 A，B 被移除 |
| 检查注册清单 | 查看当前 Route、Destination、Scope 与恢复标识 |
| 通用配置与业务资源隔离 | 验证自定义 Scope、服务命名空间、非 Codable 编解码与错误码 |
| 重复注册与事务回滚 | 制造冲突，确认 Route/页面/服务/SwiftUI 工厂无残留 |
| 拦截器与循环保护 | 验证重定向、放行、拒绝和挂起上限 |
| Deep Link 优先级与安全校验 | 验证优先级、移除回退、非法 Scheme/Host/凭据被拒绝 |
| 原生 SwiftUI RouterHost | Push、Sheet、FullScreen、Root、Replace 与工厂错误 |
| UIKit 托管 SwiftUI 页面 | 通过 registerSwiftUI 生成 HostingController，在 UIKit 栈内返回 |
| 保存当前导航快照 | 写入真实 JSON 数据并显示字节数 |
| 恢复已保存快照 | 解码本地数据并重新打开对应栈 |
| v1 → v2 迁移并恢复 | 真实迁移后打开根 + A，显示 v2 |
| 不可恢复路由 skip / fail | 对比报错、排除和登记后的成功保存 |
| 查看事务历史 | 查看实验室独立历史 |
| 历史容量与清理 | 运行六次导航验证容量、按 ID 清理和全部清理 |
| 测试替身与调用记录 | 验证指定地址 Provider 优先级、元数据、事件和导航记录 |

实验室内的失败探针捕获的是预期错误；如果验证条件不满足，会显示“路由提示”，不会伪装为成功。新窗口需要 App 环境接入，表中明确展示的是能力边界，不是自动创建系统窗口。

### 18.4 从代码找到入口

- Application/TFYSwiftDemoAppCoordinator.swift：四 Scope、服务、模块、事件、拦截和外部 URL。
- Application/TFYSwiftDemoTabRouter.swift：选 Tab + 路由、业务接口注入。
- Laboratory/TFYSwiftDemoLabRoutes.swift：新增契约和探针地址。
- Laboratory/TFYSwiftDemoLabNavigationController.swift：隔离容器、页面注册、交互、快照存取。
- Laboratory/TFYSwiftDemoLabProbes.swift：可重复执行的注册、拦截、URL、恢复和测试探针。
- Laboratory/TFYSwiftDemoNativeRouterView.swift：真正的原生 SwiftUI Driver 与 Host。

以上路径均相对于 TFYSwiftRouterKit/ClassDmoe。

## 19. 源码阅读索引

组件 TFYSwiftRouter 下全部 23 个 Swift 文件均有中文职责/API 注释。推荐先读 Route → Registry → Router → Driver，再按业务需要读交互和扩展。

| 文件 | 阅读重点 |
|---|---|
| Core/TFYSwiftRoute.swift | 地址相等性、类型擦除、Scope、Source、Metadata、Context |
| Core/TFYSwiftPresentation.swift | 呈现配置、Sheet、去重 |
| Core/TFYSwiftRouteContract.swift | 编译期 Input/Output/Command/Event 关联类型 |
| Core/TFYSwiftRegistry.swift | 类型索引、Resolver、重复登记、注册快照 |
| Core/TFYSwiftTransaction.swift | 事务身份、阶段、目标描述符 |
| Core/TFYSwiftRouter.swift | 协议、各类 open、Session、拦截循环、结果、历史、超时 |
| Core/TFYSwiftInteraction.swift | 输入类型验证、AsyncStream、交互所有权、Session |
| Core/TFYSwiftNavigationDriver.swift | 平台导航协议和一次性 Result |
| Core/TFYSwiftScopedNavigationDriver.swift | 多 Scope 分发与缺失容器处理 |
| Core/TFYSwiftRootRouteRegistration.swift | 组件根地址的类型擦除 |
| Core/TFYSwiftComponentServices.swift | 协议键与实例级服务注册 |
| Core/TFYSwiftInterceptor.swift | 拦截顺序及四种决策 |
| Core/TFYSwiftObservability.swift | 弱观察者、事件字段、历史容量 |
| Core/TFYSwiftError.swift | 可比较的中文错误分类 |
| UIKit/TFYSwiftRouterAssembly.swift | 组合根及成对注册 |
| UIKit/TFYSwiftUIKitComponentModule.swift | 批量模块接入和回滚边界 |
| UIKit/TFYSwiftUIKitDestinationRegistry.swift | UIKit/HostingController 页面工厂 |
| UIKit/TFYSwiftUIKitNavigationDriver.swift | 导航栈、模态、生命周期、自定义处理器 |
| SwiftUI/TFYSwiftSwiftUINavigationDriver.swift | View 工厂、状态、缓存、Host 绑定 |
| DeepLink/TFYSwiftDeepLink.swift | actor、白名单、Parser 优先级 |
| Restoration/TFYSwiftRestoration.swift | 编解码、快照、迁移、恢复计划 |
| Testing/TFYSwiftTestRouter.swift | 动作与上下文记录、结果 Provider |
| Umbrella/TFYSwiftRouterKit.swift | SPM 运行时重导出，Testing 独立 |

## 20. 错误排查与接入检查

### 20.1 常见错误

| 错误 | 先检查 |
|---|---|
| routeNotRegistered | 是否登记了实际 Route 类型；恢复/Deep Link 是否先等根模块装配 |
| duplicateRegistration | 类型/目标 ID/Scope 是否重复；是否应显式 replacingExisting |
| destinationNotRegistered | Resolver 返回的 identifier 是否与页面工厂一致 |
| inputMissing | 是否走了没有 input 的 URL/恢复入口 |
| inputTypeMismatch | 调用方实际传入类型与 context.input 类型是否一致 |
| resultTypeMismatch | expecting / 契约 Output 与 finish(with:) 是否一致 |
| commandChannelMissing / eventChannelMissing | 是否用普通 open 打开了要求 Session 的页面 |
| interactionFinished | 流程已经结束后是否仍在发送命令/事件 |
| scopeUnavailable | Scope 是否注册，导航容器是否已经释放 |
| invalidDeepLink | 白名单、凭据、长度、Parser 与业务参数是否合法 |
| suspensionLoop | 恢复后是否没有改变登录/权限状态 |
| redirectLoop | 地址之间是否反复互相重定向 |
| destinationUnavailable | 是否把结果等待与页面复用策略混用 |
| sceneUnavailable | 是否安装窗口处理器并完成 App 多 Scene 接入 |
| restorationFailed | 稳定标识、Codable 载荷、迁移、Scope 和工厂是否就绪 |
| cancelled / timeout | 流程拥有者是否需要关闭 UI 并停止自己的任务 |

### 20.2 接入完成后的检查

- 根容器、Assembly、服务和 History 有明确拥有者，未临时创建后丢失。
- Component Interface 不依赖另一组件的 UIViewController。
- 每个 Tab 的 Scope 唯一；选择 Tab 与导航同时由 App Flow 处理。
- Route 中仅含稳定地址，临时模型通过 Input 传递。
- 结果和会话有完成、取消、超时的可结束路径。
- 自定义展示和额外强持有页面的流程，主动清理交互。
- 恢复前完成注册，并为鉴权失败/未知版本提供回到默认根页的业务降级。
- 外部链接覆盖冷启动与热启动，并且在根页面安装后处理。
- 测试 Target 显式依赖 Testing，不能假设聚合包继续重导出它。
- 诊断记录容量合理；长期日志需要自行导出，不把有限内存缓存当永久记录。

### 20.3 从 1.0.0 升级到 2.0.0

新增的 Scope 注册默认拒绝覆盖，需要 `try`；旧 `ScopedDriver.register` 已弃用。生产聚合包不再包含 Testing，测试 Target 需要显式添加 Testing 产品或子规格。`ignoreIfTop` 仍兼容，但新代码推荐 `singleTop`。强类型契约是可选增强，原有 `TFYSwiftRoute` 和 `open/openSession` 不必整体重写。

迁移前：

~~~swift
assembly.register(navigationController: secondaryNavigation, for: secondaryScope)
try await router.open(route, deduplication: .ignoreIfTop)
~~~

迁移后：

~~~swift
try assembly.register(
    navigationController: secondaryNavigation,
    for: secondaryScope
)
try await router.open(route, deduplication: .singleTop)
~~~

若测试代码原来只依赖聚合产品，需要为测试 Target 增加 `TFYSwiftRouterTesting`（SPM）或 `TFYSwiftRouterKit/Testing`（CocoaPods）。完整变更逐项记录在仓库根目录 [CHANGELOG](../../../CHANGELOG.md)。

本指南的章节示例用于逐步搭建，重复展示的“注册 ProductRoute”等片段是不同方案，不能在同一个 Assembly 上不加区分地全部重复执行。需要完整可运行的组合时，以仓库 Demo 和 Laboratory 为准。

## 21. 通用组件与 App 资源的边界

组件只提供协议、状态和适配能力，不内置商品/购物车/账户名称、图片资源、Bundle.main、UserDefaults 或固定业务 URL。示例的 lab.navigation、商品 ID、图标、提示文案和快照存储键均位于 ClassDmoe，App 可以整体替换 Demo 而不修改组件。

### 21.1 自定义默认 Scope，不必注册 main

~~~swift
let navigation = UINavigationController()
let assembly = TFYSwiftRouterAssembly(
    navigationController: navigation,
    initialScope: "workspace.navigation"
)
// 省略 scope 会使用 workspace.navigation。
try await assembly.router.open(ProductRoute.root, presentation: .root())

let api: any TFYSwiftRouting = assembly.router
try await api.open(ProductRoute.detail(id: "1001"))
try await api.back()
~~~

先按前面的模块示例登记 ProductRoute，再运行以上打开操作。直接组合驱动时传 TFYSwiftRouter(driver: driver, defaultScope: "workspace.navigation")。测试替身也支持 TFYSwiftTestRouter(defaultScope:)。

普通 open、Input/Output、openTyped、openSession/openTypedSession、超时、Deep Link 和导航回退都使用实例默认值。显式传 scope: .main 仍表示真正选择 main，不会被重写。TFYSwiftNavigationScopeID.main 保留为兼容默认常量，不是必须采用的业务名称。

已有自定义 TFYSwiftRouting 实现可以不增加属性，协议扩展会提供 .main；需要其他缺省容器时，实现 defaultScope 即可。

实验室现已使用 lab.navigation，未注册 main。它的按钮大多省略 scope，因此实际运行就验证了这一配置能力。

### 21.2 SwiftUI 错误 UI 由接入方提供

~~~swift
TFYSwiftSwiftUIRouterHost(
    driver: driver,
    errorContent: { error in
        AnyView(VStack {
            Text("当前页面无法打开")
            Text(error.localizedDescription)
        })
    }
) {
    Text("应用首页")
}
~~~

图标、颜色、按钮、产品文案、字体、语言和资源包属于 App。组件不再提供写死 exclamationmark.triangle、橙色和中文标题的错误页面。errorContent 默认是 EmptyView，保持旧调用可编译且不强加视觉设计。

正常导航的同步工厂异常仍从 try await router.open 抛出，应在业务调用点处理。errorContent 是 Host 在需要重新构建缺少缓存内容的条目时使用的兜底，不会吞掉正常 open 的错误。

组件错误枚举新增稳定 code，例如 TFYSwiftRouteError.timeout.code == "timeout"。App 可以用此码选择自己的 String Catalog/Bundle 文案；原 errorDescription 保留诊断兼容，不应当作固定产品文案使用。

### 21.3 同一服务协议登记多个实例

~~~swift
let primaryKey = TFYSwiftComponentServiceKey<any CartServicing>(
    namespace: "primary-account"
)
let guestKey = TFYSwiftComponentServiceKey<any CartServicing>(
    namespace: "guest-account"
)
let primary: any CartServicing = CartService()
let guest: any CartServicing = CartService()
try services.register(primary, for: primaryKey)
try services.register(guest, for: guestKey)

let primaryCart = try services.resolve(primaryKey)
let guestCart = try services.resolve(guestKey)
~~~

键是“协议类型 + 可选 namespace”的结构化组合，不靠拼接字符串表示身份。相同协议、相同命名空间仍进行重复检测；不同命名空间相互独立。nil 命名空间保持旧的按类型查找规则；nil 与空字符串也是不同的键。

账户名称由 App 决定。业务身份变化时，App 管理对应服务的注销和重新登记；注册表不自动解释账户语义。

### 21.4 配置 JSON 策略或完全替换编码格式

默认 Codable 路径可以注入 JSONEncoder/JSONDecoder：

~~~swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let codecs = TFYSwiftRestorationRegistry(encoder: encoder, decoder: decoder)
try codecs.register(ProductRoute.self, identifier: "product.route")
~~~

编码器与解码器应在注册前配置好，注册后不应从其他并发上下文修改这些实例。字段/日期策略要成对一致。

不想要求业务 Route 遵守 Codable，或已有自定义二进制格式时，注入闭包：

~~~swift
struct BinaryAddress: TFYSwiftRoute {
    let bytes: [UInt8]
}
try codecs.register(
    BinaryAddress.self,
    identifier: "app.binary-address",
    encode: { Data($0.bytes) },
    decode: { BinaryAddress(bytes: Array($0)) }
)
~~~

组件只保存闭包生成的 Data，不限制它是 JSON。完整 NavigationSnapshot 自身仍是 Codable；对整个快照选择文件、数据库、压缩或加密，由 App 负责。

identifier 始终由 App 提供并保持稳定。默认从 Swift 类型名派生的普通 Destination 标识只用于运行期工厂查找，不应当作长期存储协议。

### 21.5 通用性回归检查

Package 测试会验证：

- 普通协议调用、结果调用、强类型会话和回退继承配置的 Scope。
- 显式指定 Scope 能覆盖缺省配置。
- 同一类型不同服务命名空间的隔离、重复检测、注销与事务回滚。
- 自定义 JSON 日期策略，以及无需 Codable 的二进制地址往返。
- 可发布的 Swift 源码不依赖 Demo 类型、固定业务 URL、UserDefaults、Bundle.main 或内置图片加载。

HTTP/HTTPS 等协议名、错误枚举 code、Swift 类型名、Sheet 的标准尺寸是技术契约或可覆盖默认值，不属于业务资源。业务命名和视觉资源应始终在 App/Feature 实现层声明。

实验室“通用配置与业务资源隔离”会实际运行默认 Scope、命名服务、自定义编解码和稳定错误码检查。

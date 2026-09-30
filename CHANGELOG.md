# Changelog

本文件记录 TFYSwiftRouterKit 的用户可见变更。版本遵循语义化版本；SwiftPM 使用同名 Git Tag，CocoaPods 使用 `TFYSwiftRouterKit.podspec` 中的版本。

## 2.4.0 - 2026-10-01

- 同一 Router/Scope 的导航提交、去重激活与回退串行执行；异步解析后再次检查去重，并拒绝可能死锁的嵌套提交。空闲 Scope 的提交队列及时释放。
- 状态恢复增加 Scope 拥有者与平台检查点隔离，保留原交互资源直到提交；UIKit 暂停栈交互/返回手势，SwiftUI 忽略恢复中的旧路径更新，Tab 回滚避免覆盖其他导航的新选择。
- Session 最终结果支持独立多等待者；取消等待任务不结束会话，主动 cancel 或任一 value 超时结束全部等待者和通信流。
- History 修改容量时立即裁剪并归一化为至少 1。
- 修复 Testing 旧会话结束时移除同地址新会话记录的问题，并在 Provider 前后检查任务取消。
- DeepLink 和 Interceptor 在每个处理器前后检查取消，阻止迟到结果或后续业务调用。
- TabBar Assembly 在修改宿主 UI/代理前验证重复 Scope、重复容器与初始 Scope。
- SwiftUI singleTask 与 UIKit 一致，优先激活最近的匹配栈条目。
- 补充并发提交、独立结果等待、取消、初始化失败无副作用、恢复隔离和重复地址复用测试，以及更新说明。

- 删除旧能力工作台 Demo，从零重建首页、免费、加号发布、会员、我的五入口视频项目，保持每个 Feature 的 ViewController / Model / Routes / Router 结构。
- 首页按参考图片实现黑色两列海报列表、搜索栏和悬浮玻璃底栏；二级页面隐藏底栏，返回根页恢复。
- 补充搜索、详情、收藏、观看历史、模拟播放、登录续接、影评发布和会员订单；海报后台解码缓存，列表复用时校验内容身份。

### 行为与接入提醒

- 直接使用内置 Driver 检查点时，必须在 `router.withNavigationRestoration(scopes:operation:)` 上下文内创建并提交/回滚；重放使用 `source: .restoration`。使用 RestorationCoordinator 的普通接入自动满足此条件。
- 取消 Session 的等待任务只取消该订阅；放弃整个流程时显式调用 `session.cancel()`。取消和超时仍不自动关闭 UI。

### 发布关联

- GitHub [2.4.0 Release](https://github.com/13662049573/TFYSwiftRouterKit/releases/tag/2.4.0) 已发布，Tag 指向源码提交 `e40bf41`。
- SwiftPM：使用已发布的 Git Tag `2.4.0` 解析版本。
- CocoaPods：`spec.version` 为 `2.4.0`，源码与文档链接引用同一版本；2026-10-01 完成完整编译校验并发布 2.4.0，已核验 Trunk 与公开 Specs 收录。
- Demo：App 与测试 Target 的 `MARKETING_VERSION` 同为 `2.4.0`，设置页从 Bundle 读取版本。
- 发布说明与建议提交描述见 [2.4.0 发布说明](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-2.4.0更新说明.md)。

## 2.3.0 - 2026-09-21

- 路由事件新增来源、链路 ID、呈现方式、去重策略、目标 ID 与稳定错误码，诊断信息不再依赖复用的 message 字段。
- Resolver 成功后，目标 ID 会贯穿 resolved、presented、completed 和 failed 等后续事件。
- Demo 事件详情展示全部结构化诊断字段，并补充字段完整性 UI 回归断言。
- 新增事件上下文、失败错误码、History 容量与清空通知的 SwiftPM 回归测试。
- CI 改为使用真机 SDK 的 generic iOS 构建，不再使用 Simulator，并增加 Package 清单、Podspec 与上一版本公开 API 兼容性校验。

### 发布关联

- SwiftPM：发布时使用 Git Tag `2.3.0`。
- CocoaPods：`TFYSwiftRouterKit.podspec` 与源码 Tag 同为 `2.3.0`。
- Demo：Xcode 工程 `MARKETING_VERSION` 与组件版本保持为 `2.3.0`。

## 2.2.0 - 2026-09-21

- 新增单参数 `TFYSwiftRouterAssembly.register`，普通页面不再需要接收未使用的 DestinationContext。
- 新增闭包形式的 Interceptor 登记；简单登录、权限判断无需额外声明协议类型。
- Assembly 新增 `initialNavigationDriver` 与 `navigationDriver(for:)`；旧 `driver` 保留为弃用兼容别名。
- 内置 UIKit Driver 的 push、pop、replace、root、present 与 dismiss 会等待系统转场完成后返回；Demo 删除结果页关闭后的轮询等待。
- README 与完整指南改为先展示默认最短接入，RouteConfiguration、Typed、Scope、Session、恢复等能力按需展开。
- Demo 按 Start、Playground、Stack、Timeline 四套 Feature 重组，每套独立维护 ViewController、Model、Routes 与 Router。
- 修复 Replace 替换根页面后点击“完成”无法返回演练根页的问题，并加入 UI 回归测试。
- 修复双向 Session 的页面事件缺少可见反馈的问题；调用方收到事件后会立即更新状态。
- 事件列表新增可点击详情页，完整展示路由、Scope、耗时、时间、事务 ID、事件 ID 与说明，并支持选择复制。

### 发布关联

- SwiftPM：使用 Git Tag `2.2.0`，客户端可使用 `.package(url: ..., from: "2.2.0")`。
- CocoaPods：`TFYSwiftRouterKit.podspec` 与源码 Tag 同为 `2.2.0`。
- Demo：Xcode 工程 `MARKETING_VERSION` 与组件版本保持为 `2.2.0`。

## 2.1.0 - 2026-09-20

- 新增 `TFYSwiftTabBarNavigationDriver` 与 `TFYSwiftTabBarScope`；TabBar Assembly 会把 Scope 映射到真实 Tab，并在跨 Scope 展示、激活、回退和关闭前自动选择目标 Tab。
- `TFYSwiftRouterAssembly` 新增 TabBar 初始化器、`tabBarDriver` 和按 Scope 暴露的 `navigationDrivers`，宿主可统一配置 custom/newWindow，而业务层不再手动维护 `selectedIndex`。
- 旧 Demo 已整体删除并从零重建为“开始、演练、导航栈、事件”四 Tab；覆盖全部呈现方式、跨 Tab、去重、拦截、Deep Link、Typed Result、Session、超时/取消、注册事务、组件服务、导航快照与事件诊断。
- 新增 `TFYSwiftUIKitRouteConfiguration` 与批量事务安装 API；页面可在自身文件中同时声明 Route、目标标识、工厂和根 Scope 关联。Demo 已按此模型重建，AppCoordinator 不再注册或构造具体页面。
- 新增组件级 TabBar 单测和真机 UI 流程，覆盖自动选中目标 Scope、未知/重复 Scope、结果回传、Session 与事件时间线。
- 修复恢复过程中后续页面失败、任务取消或原栈为空时留下半恢复导航状态的问题；UIKit、SwiftUI 与 Scoped Driver 现在通过页面实例级检查点原子回滚。
- 自定义导航 Driver 若参与状态恢复，需要实现 `TFYSwiftNavigationCheckpointing`；存在模态页面时恢复会在修改导航栈前拒绝执行。
- Command/Event 流默认改为各保留最新 64 条，并可通过 `TFYSwiftRouteSessionBuffering` 选择上限与溢出方向或显式使用无界模式。
- 新增 `TFYSwiftTypedDestinationContext`、UIKit/SwiftUI `registerTyped` 与 Assembly 成对注册入口，使页面工厂也获得编译期 Input/Output/Command/Event 约束。
- 修复 UIKit Sheet 返回 `UINavigationController` 时生命周期观察器干扰容器子控制器、导致内容页不显示的问题，同时保留交互关闭与外部关闭的取消语义。
- 补充跨 Scope 恢复失败回滚、缓冲溢出和类型化页面注册回归测试，并加入 SwiftPM 与 iOS build-for-testing 的 CI 工作流。
- 修复 Demo 列表内容穿透半透明 NavigationBar 与 TabBar 的问题，统一使用不透明容器外观并增加回归测试。

### 发布关联

- SwiftPM：使用 Git Tag `2.1.0`，客户端可使用 `.package(url: ..., from: "2.1.0")`。
- CocoaPods：`TFYSwiftRouterKit.podspec` 与源码 Tag 同为 `2.1.0`。
- Demo：Xcode 工程 `MARKETING_VERSION` 与组件版本保持为 `2.1.0`。

## 2.0.0 - 2026-09-12

2.0.0 是通用化、可靠性和完整接入能力升级。路由运行时不再绑定 Demo 的业务名称、固定 URL、视觉资源、`Bundle.main`、`UserDefaults` 或持久化键；这些产品决策由 App/Feature 层提供。

### 新增

- 新增 `TFYSwiftRouteContract` 与 `TFYSwiftSessionRouteContract`，为 Input、Output、Command、Event 提供编译期约束及 `openTyped`/`openTypedSession` 入口。
- 新增 Result 与 Session 超时 API、主动取消及明确的交互终态处理。
- 新增原子注册事务、失败回滚、重复 Destination/Scope 检测、显式覆盖、注销和注册查询。
- 新增可配置默认 Navigation Scope；普通打开、契约、会话、超时、Deep Link 和回退使用同一实例默认值。
- 新增组件服务 Key 命名空间，同一协议可安全登记多个实例。
- 新增稳定错误 `code`，App 可映射自己的多语言文案与错误界面。
- 新增可配置 JSON 编解码器，以及不要求 Route 遵守 `Codable` 的自定义编解码闭包。
- 新增完整导航快照、Schema 迁移、恢复计划与恢复重放；导航栈查询和活跃模态查询分别提供。
- 新增 Deep Link Parser 优先级、移除和注册信息查询。
- 新增 `TFYSwiftTestRouter.Invocation` 详细记录、异步/按 Route 返回值 Provider 和 Session 交互访问。
- 新增 SwiftPM 测试 Target，并明确 macOS 主机测试与 iOS UI Adapter 的构建边界。
- 新增独立可操作的四 Tab Demo、0→1 中文指南、源码中文注释和 UI 回归用例。

### 修复

- 安装根页面、激活已存在页面或关闭子模态时，保持被模态展示的 Navigation Scope 存活。
- 修复省略 Scope 时部分便捷 API 错用固定 `.main`，现在统一采用 Router/Assembly 配置的默认 Scope。
- 移除 SwiftUI 缺省错误页中写死的图标、颜色和标题，由 App 通过 `errorContent` 提供产品 UI。
- Demo 同时处理冷启动 Universal Link 与自定义 Scheme URL。
- 解除 Result/Interaction 循环引用，并在流程结束时释放 Continuation 闭包。
- 正确关闭在 Result Continuation 绑定前已被取消的事务。
- SwiftUI Destination 工厂异常现在由 Router 抛回，不再误报展示成功。
- UIKit/SwiftUI 页面被替换、移除或释放时，一致取消对应交互。
- UIKit 活跃路由采用弱控制器跟踪，并把模态路由纳入活跃查询。
- 保留外部已有的 `UIAdaptivePresentationControllerDelegate`，不再无条件覆盖。
- Assembly 与组件模块安装改为事务流程，拒绝静默覆盖重复 Scope。
- 限制事务历史容量与同一路由的重复挂起次数，避免无界增长和挂起循环。

### 行为变更

- `TFYSwiftRouterAssembly.register(navigationController:for:)` 改为可抛错 API，重复 Scope 不再静默替换。
- 生产聚合产品 `TFYSwiftRouterKit` 不再包含 `TFYSwiftRouterTesting`；测试 Target 必须显式依赖 Testing 产品/子规格。
- `ignoreIfTop` 作为兼容别名保留，新代码推荐使用 `singleTop`。
- SwiftUI `TFYSwiftSwiftUIRouterHost` 不再提供固定产品化错误视觉；未传 `errorContent` 时使用无样式的空兜底内容。

### 从 1.0.0 迁移

Scope 注册调用需要补充 `try`：

~~~swift
try assembly.register(
    navigationController: secondaryNavigation,
    for: secondaryScope
)
~~~

测试 Target 需要单独关联 Testing：

~~~swift
// Package.swift 的 testTarget.dependencies
.product(name: "TFYSwiftRouterTesting", package: "TFYSwiftRouterKit")
~~~

~~~ruby
# Podfile 的测试 Target
pod 'TFYSwiftRouterKit/Testing', '~> 2.0'
~~~

去重策略建议改名，旧写法仍可编译：

~~~swift
try await router.open(route, deduplication: .singleTop)
~~~

SwiftUI App 应提供自己的错误内容：

~~~swift
TFYSwiftSwiftUIRouterHost(
    driver: driver,
    errorContent: { error in
        AnyView(Text(error.localizedDescription))
    }
) {
    AppRootView()
}
~~~

强类型 Contract 是可选增强，已有 `TFYSwiftRoute`、`open` 和 `openSession` 无需一次性重写。更完整的接入步骤见[从 0 到 1 完整中文指南](TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-完整使用指南.md)。

### 发布关联

- SwiftPM：创建并推送 Git Tag `2.0.0` 后，客户端可使用 `.package(url: ..., from: "2.0.0")`。
- CocoaPods：`TFYSwiftRouterKit.podspec` 的版本为 `2.0.0`，发布时应以同一个 `2.0.0` Tag 作为源码。
- 文档：根目录 README、完整指南、四 Tab 流程和 Demo 均以 2.0.0 API 为准。

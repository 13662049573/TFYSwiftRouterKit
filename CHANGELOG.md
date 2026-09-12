# Changelog

本文件记录 TFYSwiftRouterKit 的用户可见变更。版本遵循语义化版本；SwiftPM 使用同名 Git Tag，CocoaPods 使用 `TFYSwiftRouterKit.podspec` 中的版本。

## Unreleased

暂无。

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
- 新增独立可操作的路由能力实验室、四 Tab 集成流程、0→1 中文指南、源码中文注释和 UI 回归用例。

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

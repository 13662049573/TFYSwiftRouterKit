# TFYSwiftRouterKit 2.4.0 更新说明

准备日期：2026-10-01。状态：本地待提交、待发布。

2.4.0 加强并发导航、恢复隔离及取消一致性，并将旧 Demo 整体替换为五入口视频项目。继续采用 iOS 16+、Swift 6、SwiftPM / CocoaPods 按模块集成方式。

## 组件改进

- 同一 Router / Scope 的导航提交、去重激活和回退串行执行；异步解析结束后再次核对去重，拒绝可能死锁的嵌套提交，及时释放空闲提交队列。
- 状态恢复使用 Scope 拥有者与平台检查点隔离；重放失败或取消时恢复原页面实例及交互资源，避免回滚覆盖其他导航的新 Tab 选择。
- Session 支持多个独立结果等待者；取消一个等待任务只结束该订阅，主动取消会话或任一结果等待超时会结束全部等待者和通信流。
- History 修改容量后立即裁剪，容量归一化为至少 1。
- 测试替身按实例清理 Session，避免同地址旧会话结束时移除新会话；Provider、DeepLink 和 Interceptor 的调用前后核对任务取消。
- TabBar Assembly 先验证重复 Scope、重复容器及初始 Scope，再安装容器和代理；初始化失败不修改宿主 UI。
- SwiftUI singleTask 优先激活最近匹配的栈条目，与 UIKit 行为一致。

## 视频 Demo

旧示例已删除。新的首页、免费、加号、会员、我的五入口保持每个 Feature 的 ViewController / Model / Routes / Router 结构。

首页按参考图片实现黑色两列海报、搜索栏与悬浮玻璃底栏。搜索、内容详情、收藏、观看历史、选集模拟播放、登录续接、影评草稿与发布、会员模拟订单及个人中心均可操作。二级页隐藏底栏，返回根页恢复；交互返回取消时按最终栈状态恢复导航栏。

海报在后台解码并缓存，复用回调核对内容 ID。订单固定归属开通时的账号，收藏、历史、作品和会员资格按账号隔离。图片未提供的第三行完整海报区域使用占位底色。账号、订单与内容状态为进程内模拟数据，重启后重置；支付不会扣款，播放器没有真实媒体文件。

### 操作顺序

1. 首页收藏内容，在“我的 → 我的收藏”查看；选集播放后，在观看历史查看。
2. 搜索“重器”验证筛选，输入不存在的名称观察空结果。
3. 点击加号，游客登录后继续发布影评，完成后在“我的作品”查看。
4. 会员页选择套餐，游客登录后继续确认订单；模拟开通后同步会员状态。
5. 取消登录或发布后再次进入，确认不会遗留操作锁。
6. 设置退出登录，个人中心导航栈回到根页面；切换账号后查看数据隔离。
7. 外部链接使用 `tfyswift://video/comedy`，未知内容标识会被拒绝。

## 升级说明

- 使用 RestorationCoordinator 的普通接入自动进入恢复上下文。直接操作内置 Driver 检查点时，需要在 `router.withNavigationRestoration(scopes:operation:)` 中创建并提交或回滚，重放请求标记为 `source: .restoration`。
- 放弃整个 Session 时显式调用 `session.cancel()`。取消结果等待任务只取消对应订阅；通信完成、取消或超时不会自动关闭 UI。
- 内置驱动等待 UIKit 转场完成；带结果页面由调用方等待 `dismiss` 后继续业务操作。
- Session、恢复、SwiftUI、自定义呈现和新窗口等通用组件能力保留；完整接入方式见 [使用指南](TFYSwiftRouterKit-完整使用指南.md)。

## 版本关联

| 入口 | 版本 |
|---|---|
| CocoaPods Podspec | 2.4.0，源码 Tag 与文档链接自动使用此版本 |
| SwiftPM | 待创建并推送 Git Tag 2.4.0；Package.swift 只保存版本说明 |
| App 与测试 Target | MARKETING_VERSION = 2.4.0 |
| Demo 设置页 | 读取 App Bundle 的版本 |
| README / 完整指南 / CHANGELOG | 同步至 2.4.0 |

Tag 和 CocoaPods Specs 发布前，请使用本地路径集成；README 中 2.4.0 的远端依赖示例在发布后才可使用。

## 验证记录

2026-09-30 前一轮实现验证：44 项 SwiftPM 主机测试、56 项 iOS 单元测试、9 条界面流程通过；模拟器及未签名 generic iOS 设备 SDK 构建通过。2026-10-01 版本整理后的检查：

- Package 清单解析和 Podspec Ruby 语法检查通过。
- Podspec 快速校验通过；此校验不等同于独立 CocoaPods 消费工程构建。
- Podspec 版本、源码 Tag、文档链接及 6 个 Xcode 配置的版本均为 2.4.0。
- 未签名 generic iOS 设备 SDK 构建通过，构建产物版本为 2.4.0。
- 文档本地链接和差异格式检查通过。

本轮仅调整版本和说明，未重复完整界面流程测试。

这些结果不代表 GitHub CI、最低系统版本真机或远端 SwiftPM / CocoaPods 发布验证已完成，也不包含真实设备帧率测量。

## 建议 GitHub 提交说明

标题：`feat: prepare 2.4.0 with navigation reliability fixes and video demo`

说明：

- 加强同 Scope 提交串行化、恢复隔离、Session 等待者及取消边界。
- 修复测试替身 Session 清理、Tab 初始化副作用和 SwiftUI 最近匹配行为。
- 删除旧 Demo，重建五入口视频项目及二级页底栏显示策略，补齐模拟业务流程。
- 同步 Podspec、SwiftPM 版本说明、Xcode 版本和中文文档，补充回归测试。

## 后续发布状态

当前仅准备本地文件，等待用户指示提交 GitHub。尚未创建提交、Tag 或 GitHub Release，尚未推送分支及 CocoaPods Specs。后续先提交并推送代码，再创建并推送 2.4.0 Tag；GitHub Release 与 CocoaPods 发布分别处理。

// TFYSwiftPresentation.swift
// 平台无关的呈现配置。驱动解释这些意图；新窗口和自定义呈现需要 App 注册处理器。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// Sheet 的尺寸、拖拽条和交互关闭策略。
public struct TFYSwiftSheetConfiguration: Hashable, Sendable {
    /// Sheet 支持的高度档位。
    public enum Detent: String, Hashable, Sendable {
        case medium
        case large
    }

    /// 允许的 Sheet 高度档位。
    public var detents: [Detent]
    /// 是否显示 Sheet 顶部拖拽条。
    public var prefersGrabberVisible: Bool
    /// 是否允许用户通过交互手势关闭 Sheet。
    public var allowsInteractiveDismiss: Bool

    public init(
        detents: [Detent] = [.medium, .large],
        prefersGrabberVisible: Bool = true,
        allowsInteractiveDismiss: Bool = true
    ) {
        self.detents = detents
        self.prefersGrabberVisible = prefersGrabberVisible
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
    }

    public static let `default` = TFYSwiftSheetConfiguration()
}

/// 声明如何展示目标页面；automatic 在内置驱动中采用 push 语义。
public enum TFYSwiftRoutePresentation: Hashable, Sendable {
    case automatic
    case push(animated: Bool = true)
    case sheet(TFYSwiftSheetConfiguration = .default)
    case fullScreen(animated: Bool = true)
    case replace(animated: Bool = true)
    case root(animated: Bool = false)
    case newWindow
    case custom(String)
}

/// 重复导航处理方式；返回值请求发生页面复用时会报错，避免等待未创建页面的结果。
public enum TFYSwiftRouteDeduplicationPolicy: String, Hashable, Sendable {
    case none
    /// Compatibility alias of `singleTop`; prefer `singleTop` in new code.
    case ignoreIfTop
    case singleTop
    case singleTask
}

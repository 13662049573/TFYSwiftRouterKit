// TFYSwiftRouterKit.swift
// SPM 聚合入口。重导出运行时模块；测试替身需要测试 Target 单独依赖 TFYSwiftRouterTesting。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if SWIFT_PACKAGE
@_exported import TFYSwiftRouterCore
@_exported import TFYSwiftRouterDeepLink
@_exported import TFYSwiftRouterRestoration
@_exported import TFYSwiftRouterSwiftUI
@_exported import TFYSwiftRouterUIKit
#endif

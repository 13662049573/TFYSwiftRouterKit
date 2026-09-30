// swift-tools-version: 6.0
// 当前清单对应 TFYSwiftRouterKit 2.4.0。
// 准备日期：2026-10-01；本地待发布，尚未创建或推送本版本 Tag。
// 2.4.0：补强同 Scope 导航提交、恢复隔离、独立结果等待及取消边界；重建五入口视频 Demo。
// Swift Package Manager 不在清单内声明包版本，而是从 Git Tag 解析版本；发布时需创建 2.4.0 Tag。
// 完整更新与迁移说明见仓库根目录 CHANGELOG.md。
// 本版本详细说明：TFYSwiftRouterKit/TFYSwiftRouter/Documentation/TFYSwiftRouterKit-2.4.0更新说明.md。
import PackageDescription

let package = Package(
    name: "TFYSwiftRouterKit",
    platforms: [.iOS(.v16), .macOS(.v10_15)],
    products: [
        // 运行时聚合产品不包含 Testing，测试 Target 应显式依赖 TFYSwiftRouterTesting。
        .library(name: "TFYSwiftRouterKit", targets: ["TFYSwiftRouterKit"]),
        .library(name: "TFYSwiftRouterCore", targets: ["TFYSwiftRouterCore"]),
        .library(name: "TFYSwiftRouterUIKit", targets: ["TFYSwiftRouterUIKit"]),
        .library(name: "TFYSwiftRouterSwiftUI", targets: ["TFYSwiftRouterSwiftUI"]),
        .library(name: "TFYSwiftRouterDeepLink", targets: ["TFYSwiftRouterDeepLink"]),
        .library(name: "TFYSwiftRouterRestoration", targets: ["TFYSwiftRouterRestoration"]),
        .library(name: "TFYSwiftRouterTesting", targets: ["TFYSwiftRouterTesting"])
    ],
    targets: [
        .target(
            name: "TFYSwiftRouterCore",
            path: "TFYSwiftRouterKit/TFYSwiftRouter/Core"
        ),
        .target(
            name: "TFYSwiftRouterUIKit",
            dependencies: ["TFYSwiftRouterCore"],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/UIKit"
        ),
        .target(
            name: "TFYSwiftRouterSwiftUI",
            dependencies: ["TFYSwiftRouterCore"],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/SwiftUI"
        ),
        .target(
            name: "TFYSwiftRouterDeepLink",
            dependencies: ["TFYSwiftRouterCore"],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/DeepLink"
        ),
        .target(
            name: "TFYSwiftRouterRestoration",
            dependencies: ["TFYSwiftRouterCore"],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/Restoration"
        ),
        .target(
            name: "TFYSwiftRouterTesting",
            dependencies: ["TFYSwiftRouterCore"],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/Testing"
        ),
        .target(
            name: "TFYSwiftRouterKit",
            dependencies: [
                "TFYSwiftRouterCore",
                "TFYSwiftRouterUIKit",
                "TFYSwiftRouterSwiftUI",
                "TFYSwiftRouterDeepLink",
                "TFYSwiftRouterRestoration"
            ],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/Umbrella"
        ),
        .testTarget(
            name: "TFYSwiftRouterTests",
            dependencies: [
                "TFYSwiftRouterCore",
                "TFYSwiftRouterDeepLink",
                "TFYSwiftRouterRestoration",
                "TFYSwiftRouterTesting"
            ],
            path: "TFYSwiftRouterKitPackageTests"
        )
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TFYSwiftRouterKit",
    platforms: [.iOS(.v16)],
    products: [
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
                "TFYSwiftRouterRestoration",
                "TFYSwiftRouterTesting"
            ],
            path: "TFYSwiftRouterKit/TFYSwiftRouter/Umbrella"
        )
    ],
    swiftLanguageModes: [.v6]
)

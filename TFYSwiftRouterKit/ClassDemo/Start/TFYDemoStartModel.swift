import UIKit

enum TFYDemoStartAction {
    case push
    case crossTab
    case picker
    case session
    case deepLink
    case swiftUI
    case timeline
}

struct TFYDemoStartItem {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: UIColor
    let accessibilityID: String
    let action: TFYDemoStartAction
}

struct TFYDemoStartSection {
    let title: String
    let footer: String?
    let items: [TFYDemoStartItem]
}

struct TFYDemoStartModel {
    let sections: [TFYDemoStartSection] = [
        .init(title: "默认路径", footer: "Route → register → open；复杂能力只在需要时出现。", items: [
            .init(title: "1. 打开详情", subtitle: "最简单的 Route 与 Push", symbol: "1.circle.fill", tint: .systemIndigo, accessibilityID: "demo.start.push", action: .push),
            .init(title: "2. 自动跨 Tab", subtitle: "Scope 自动选择目标导航容器", symbol: "2.circle.fill", tint: .systemTeal, accessibilityID: "demo.start.crossTab", action: .crossTab),
            .init(title: "3. 等待页面结果", subtitle: "Typed Input / Output", symbol: "3.circle.fill", tint: .systemOrange, accessibilityID: "demo.start.picker", action: .picker),
            .init(title: "4. 查看事件", subtitle: "观察完整事务生命周期", symbol: "4.circle.fill", tint: .systemPink, accessibilityID: "demo.start.timeline", action: .timeline)
        ]),
        .init(title: "按需能力", footer: nil, items: [
            .init(title: "双向 Session", subtitle: "Command、Event 与最终 Output", symbol: "arrow.left.arrow.right.circle.fill", tint: .systemPurple, accessibilityID: "demo.start.session", action: .session),
            .init(title: "Deep Link", subtitle: "URL 白名单、Parser 与目标 Scope", symbol: "link.circle.fill", tint: .systemBlue, accessibilityID: "demo.start.deeplink", action: .deepLink),
            .init(title: "SwiftUI 页面", subtitle: "UIKit Router 打开 UIHostingController", symbol: "swift", tint: .systemOrange, accessibilityID: "demo.start.swiftui", action: .swiftUI)
        ])
    ]
}

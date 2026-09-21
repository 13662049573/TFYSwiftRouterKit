import UIKit

enum TFYDemoPlaygroundAction {
    case push, sheet, fullScreen, replace, root, custom, newWindow
    case singleTop, singleTask, interceptor
    case timeout, cancel, registration, service, restoration
    case back, backToRoot, dismiss, dismissAll
}

struct TFYDemoPlaygroundItem {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: UIColor
    let accessibilityID: String
    let action: TFYDemoPlaygroundAction
}

struct TFYDemoPlaygroundSection {
    let title: String
    let footer: String?
    let items: [TFYDemoPlaygroundItem]
}

struct TFYDemoPlaygroundModel {
    let sections: [TFYDemoPlaygroundSection] = [
        .init(title: "呈现方式", footer: "内置 UIKit Driver 会等待真实系统转场完成。", items: [
            item("Automatic / Push", "标准导航栈推进", "arrow.right.circle.fill", .systemBlue, "demo.playground.push", .push),
            item("Sheet", "Detent、Grabber 与交互关闭", "rectangle.bottomhalf.inset.filled", .systemTeal, "demo.playground.sheet", .sheet),
            item("Full Screen", "全屏模态与生命周期", "rectangle.inset.filled", .systemIndigo, "demo.playground.fullscreen", .fullScreen),
            item("Replace", "替换栈顶并结束旧交互", "rectangle.2.swap", .systemOrange, "demo.playground.replace", .replace),
            item("Root", "重建当前 Scope 根页面", "arrow.up.to.line.circle.fill", .systemGreen, "demo.playground.root", .root),
            item("Custom", "宿主注册的翻转转场", "wand.and.stars", .systemPurple, "demo.playground.custom", .custom),
            item("New Window", "宿主 Window / Scene 扩展点", "macwindow.badge.plus", .systemPink, "demo.playground.window", .newWindow)
        ]),
        .init(title: "策略", footer: nil, items: [
            item("Single Top", "重复地址不继续堆叠", "square.on.square", .systemCyan, "demo.playground.singletop", .singleTop),
            item("Single Task", "回到栈内已有地址", "arrow.uturn.backward.square.fill", .systemTeal, "demo.playground.singletask", .singleTask),
            item("Interceptor Redirect", "legacy Route 被闭包拦截器替换", "arrow.triangle.turn.up.right.circle.fill", .systemOrange, "demo.playground.interceptor", .interceptor)
        ]),
        .init(title: "可靠性与组合", footer: nil, items: [
            item("结果超时", "超时结束 Session 并关闭页面", "timer", .systemOrange, "demo.playground.timeout", .timeout),
            item("主动取消", "取消 Result、Command 与 Event", "stop.circle.fill", .systemRed, "demo.playground.cancel", .cancel),
            item("注册事务", "重复注册触发完整回滚", "arrow.counterclockwise.circle.fill", .systemIndigo, "demo.playground.registration", .registration),
            item("组件服务", "命名空间注册、解析与注销", "shippingbox.fill", .systemBrown, "demo.playground.service", .service),
            item("导航快照", "编码并原子恢复四个 Scope", "externaldrive.fill.badge.checkmark", .systemGreen, "demo.playground.restoration", .restoration)
        ]),
        .init(title: "导航控制", footer: nil, items: [
            item("返回一层", "操作当前 Scope", "chevron.backward.circle.fill", .systemGray, "demo.playground.back", .back),
            item("返回根路由", "清理根页之后的页面", "arrow.uturn.backward.circle.fill", .systemGray, "demo.playground.backRoot", .backToRoot),
            item("关闭模态", "关闭当前 Scope 顶层模态", "xmark.circle.fill", .systemRed, "demo.playground.dismiss", .dismiss),
            item("关闭全部模态", "结束完整模态层级", "xmark.rectangle.stack.fill", .systemRed, "demo.playground.dismissAll", .dismissAll)
        ])
    ]
}

private func item(
    _ title: String,
    _ subtitle: String,
    _ symbol: String,
    _ tint: UIColor,
    _ accessibilityID: String,
    _ action: TFYDemoPlaygroundAction
) -> TFYDemoPlaygroundItem {
    .init(title: title, subtitle: subtitle, symbol: symbol, tint: tint, accessibilityID: accessibilityID, action: action)
}

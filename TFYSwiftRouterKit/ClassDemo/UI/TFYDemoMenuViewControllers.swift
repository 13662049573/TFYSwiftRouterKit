import UIKit

struct TFYDemoMenuItem {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: UIColor
    let accessibilityID: String
    let action: TFYDemoAction
}

struct TFYDemoMenuSection {
    let title: String
    let footer: String?
    let items: [TFYDemoMenuItem]
}

class TFYDemoMenuViewController: UITableViewController {
    private let introTitle: String
    private let introText: String
    private let accent: UIColor
    private let sections: [TFYDemoMenuSection]
    private let onAction: (TFYDemoAction) -> Void

    init(
        title: String,
        introTitle: String,
        introText: String,
        accent: UIColor,
        sections: [TFYDemoMenuSection],
        onAction: @escaping (TFYDemoAction) -> Void
    ) {
        self.introTitle = introTitle
        self.introText = introText
        self.accent = accent
        self.sections = sections
        self.onAction = onAction
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "menu")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 82
        tableView.contentInset.bottom = 24
        tableView.sectionHeaderTopPadding = 18
        tableView.tableHeaderView = makeHeader()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "menu", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.title
        content.secondaryText = item.subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 2
        content.image = UIImage(systemName: item.symbol)
        content.imageProperties.tintColor = item.tint
        content.imageProperties.maximumSize = CGSize(width: 28, height: 28)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = item.accessibilityID
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onAction(sections[indexPath.section].items[indexPath.row].action)
    }

    private func makeHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 178))
        let band = UIView()
        band.translatesAutoresizingMaskIntoConstraints = false
        band.backgroundColor = accent
        band.layer.cornerRadius = 8

        let mark = UIImageView(image: UIImage(systemName: "point.3.filled.connected.trianglepath.dotted"))
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.tintColor = .white
        mark.preferredSymbolConfiguration = .init(pointSize: 28, weight: .semibold)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        titleLabel.textColor = .white
        titleLabel.text = introTitle
        titleLabel.numberOfLines = 2

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        subtitleLabel.text = introText
        subtitleLabel.numberOfLines = 3

        container.addSubview(band)
        band.addSubview(mark)
        band.addSubview(titleLabel)
        band.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            band.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            band.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            band.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            band.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            mark.leadingAnchor.constraint(equalTo: band.leadingAnchor, constant: 20),
            mark.topAnchor.constraint(equalTo: band.topAnchor, constant: 20),
            mark.widthAnchor.constraint(equalToConstant: 34),
            mark.heightAnchor.constraint(equalToConstant: 34),
            titleLabel.leadingAnchor.constraint(equalTo: mark.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: band.trailingAnchor, constant: -18),
            titleLabel.centerYAnchor.constraint(equalTo: mark.centerYAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: band.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: band.trailingAnchor, constant: -20),
            subtitleLabel.topAnchor.constraint(equalTo: mark.bottomAnchor, constant: 16)
        ])
        return container
    }
}

final class TFYDemoStartViewController: TFYDemoMenuViewController {
    static func routeConfiguration(
        onAction: @escaping (TFYDemoAction) -> Void
    ) -> TFYSwiftUIKitRouteConfiguration<TFYDemoStartRoute> {
        .init(
            rootScope: TFYDemoTab.start.scope,
            rootRoute: TFYDemoStartRoute(),
            destinationID: "demo.root.start"
        ) { _, _ in
            TFYDemoStartViewController(
                title: TFYDemoTab.start.title,
                introTitle: "TFYSwiftRouterKit",
                introText: "从 Route 配置开始，体验跨 Tab、结果返回、双向会话与事件追踪。",
                accent: .systemIndigo,
                sections: startSections,
                onAction: onAction
            )
        }
    }

    private static let startSections: [TFYDemoMenuSection] = [
        .init(title: "从 0 到 1", footer: "页面只声明 RouteConfiguration；调用方始终只打开 Route。", items: [
            item("1. 打开详情", "Route → Resolver → Destination → Push", "1.circle.fill", .systemIndigo, "demo.start.push", .push),
            item("2. 自动跨 Tab", "指定 scope 后由 TabBar Driver 选中目标容器", "2.circle.fill", .systemTeal, "demo.start.crossTab", .crossTab),
            item("3. 等待页面结果", "强类型 Input/Output 与取消生命周期", "3.circle.fill", .systemOrange, "demo.start.picker", .picker),
            item("4. 查看事件", "核对 created、resolved、presented、completed", "4.circle.fill", .systemPink, "demo.start.timeline", .showTimeline)
        ]),
        .init(title: "进阶通信", footer: nil, items: [
            item("双向会话", "Command、Event 与最终 Output 在同一 Session 中流转", "arrow.left.arrow.right.circle.fill", .systemPurple, "demo.start.session", .session),
            item("Deep Link", "白名单、Parser、去重与目标 Scope", "link.circle.fill", .systemBlue, "demo.start.deeplink", .deepLink),
            item("SwiftUI 页面", "RouteConfiguration 返回 UIHostingController", "swift", .systemOrange, "demo.start.swiftui", .swiftUI)
        ])
    ]
}

final class TFYDemoPlaygroundViewController: TFYDemoMenuViewController {
    static func routeConfiguration(
        onAction: @escaping (TFYDemoAction) -> Void
    ) -> TFYSwiftUIKitRouteConfiguration<TFYDemoPlaygroundRoute> {
        .init(
            rootScope: TFYDemoTab.playground.scope,
            rootRoute: TFYDemoPlaygroundRoute(),
            destinationID: "demo.root.playground"
        ) { _, _ in
            TFYDemoPlaygroundViewController(
                title: TFYDemoTab.playground.title,
                introTitle: "Router Playground",
                introText: "全部入口调用公开 API；完成后可在导航栈和事件页核对真实状态。",
                accent: .systemTeal,
                sections: playgroundSections,
                onAction: onAction
            )
        }
    }

    private static let playgroundSections: [TFYDemoMenuSection] = [
        .init(title: "呈现方式", footer: "replace 后可从目标页恢复当前 Tab 根 Route。", items: [
            item("Automatic / Push", "标准导航栈推进", "arrow.right.circle.fill", .systemBlue, "demo.playground.push", .push),
            item("Sheet", "Detent、Grabber 与交互关闭", "rectangle.bottomhalf.inset.filled", .systemTeal, "demo.playground.sheet", .sheet),
            item("Full Screen", "全屏模态与外部关闭监听", "rectangle.inset.filled", .systemIndigo, "demo.playground.fullscreen", .fullScreen),
            item("Replace", "替换栈顶并结束旧交互", "rectangle.2.swap", .systemOrange, "demo.playground.replace", .replace),
            item("Root", "用根 Route 重建当前 Scope", "arrow.up.to.line.circle.fill", .systemGreen, "demo.playground.root", .root),
            item("Custom", "宿主注册自定义转场", "wand.and.stars", .systemPurple, "demo.playground.custom", .custom),
            item("New Window", "宿主 Window/Scene 回调", "macwindow.badge.plus", .systemPink, "demo.playground.window", .newWindow)
        ]),
        .init(title: "策略与入口", footer: nil, items: [
            item("Single Top", "重复地址激活栈顶页面", "square.on.square", .systemCyan, "demo.playground.singletop", .singleTop),
            item("Single Task", "回到已有地址并移除其后页面", "arrow.uturn.backward.square.fill", .systemTeal, "demo.playground.singletask", .singleTask),
            item("Interceptor Redirect", "legacy Route 在解析前被替换", "arrow.triangle.turn.up.right.circle.fill", .systemOrange, "demo.playground.interceptor", .interceptor),
            item("Deep Link", "外部 URL 自动切换目标 Tab", "link", .systemBlue, "demo.playground.deeplink", .deepLink)
        ]),
        .init(title: "可靠性与组合", footer: nil, items: [
            item("结果超时", "超时结束等待与页面交互", "timer", .systemOrange, "demo.playground.timeout", .timeout),
            item("主动取消", "取消 Result、Command 与 Event", "stop.circle.fill", .systemRed, "demo.playground.cancel", .cancel),
            item("注册事务", "重复注册触发完整回滚", "arrow.counterclockwise.circle.fill", .systemIndigo, "demo.playground.registration", .registration),
            item("组件服务", "命名空间注册、解析与注销", "shippingbox.fill", .systemBrown, "demo.playground.service", .service),
            item("导航快照", "编码并原子恢复四个 Scope", "externaldrive.fill.badge.checkmark", .systemGreen, "demo.playground.restoration", .restoration)
        ]),
        .init(title: "通信与栈", footer: nil, items: [
            item("强类型结果", "Input 与 Output 由 Contract 推导", "checkmark.message.fill", .systemGreen, "demo.playground.picker", .picker),
            item("双向 Session", "完整会话生命周期", "arrow.left.arrow.right", .systemPurple, "demo.playground.session", .session),
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
    _ action: TFYDemoAction
) -> TFYDemoMenuItem {
    .init(title: title, subtitle: subtitle, symbol: symbol, tint: tint, accessibilityID: accessibilityID, action: action)
}

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

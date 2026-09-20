import UIKit

final class TFYDemoStackViewController: UITableViewController {
    private let routes: (TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute]
    private let onSelectTab: (TFYDemoTab) -> Void
    private let onAction: (TFYDemoAction) -> Void

    init(
        routes: @escaping (TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute],
        onSelectTab: @escaping (TFYDemoTab) -> Void,
        onAction: @escaping (TFYDemoAction) -> Void
    ) {
        self.routes = routes
        self.onSelectTab = onSelectTab
        self.onAction = onAction
        super.init(style: .insetGrouped)
        title = TFYDemoTab.stack.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func routeConfiguration(
        routes: @escaping (TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute],
        onSelectTab: @escaping (TFYDemoTab) -> Void,
        onAction: @escaping (TFYDemoAction) -> Void
    ) -> TFYSwiftUIKitRouteConfiguration<TFYDemoStackRoute> {
        .init(
            rootScope: TFYDemoTab.stack.scope,
            rootRoute: TFYDemoStackRoute(),
            destinationID: "demo.root.stack"
        ) { _, _ in
            TFYDemoStackViewController(routes: routes, onSelectTab: onSelectTab, onAction: onAction)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "stack")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            primaryAction: UIAction { [weak self] _ in self?.tableView.reloadData() }
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "刷新导航栈"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.backward"),
            menu: UIMenu(children: [
                UIAction(title: "返回一层", image: UIImage(systemName: "chevron.backward")) { [weak self] _ in
                    self?.onAction(.back)
                },
                UIAction(title: "返回根路由", image: UIImage(systemName: "arrow.up.to.line")) { [weak self] _ in
                    self?.onAction(.backToRoot)
                },
                UIAction(title: "关闭全部模态", image: UIImage(systemName: "xmark.rectangle.stack")) { [weak self] _ in
                    self?.onAction(.dismissAll)
                }
            ])
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = "导航栈操作"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        TFYDemoTab.allCases.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Scope 与可恢复栈"
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "点击 Scope 会通过组件级 TabBar Driver 切换对应容器。"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tab = TFYDemoTab.allCases[indexPath.row]
        let stack = routes(tab.scope)
        let cell = tableView.dequeueReusableCell(withIdentifier: "stack", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = tab.title
        content.secondaryText = stack.isEmpty ? "空栈" : stack.map(\.typeName).joined(separator: "  →  ")
        content.secondaryTextProperties.numberOfLines = 2
        content.image = UIImage(systemName: tab.symbol)
        content.imageProperties.tintColor = [.systemIndigo, .systemTeal, .systemOrange, .systemPink][indexPath.row]
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "demo.stack.\(tab.rawValue)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectTab(TFYDemoTab.allCases[indexPath.row])
    }
}

final class TFYDemoTimelineViewController: UITableViewController {
    private let history: TFYSwiftRouteHistory

    init(history: TFYSwiftRouteHistory) {
        self.history = history
        super.init(style: .plain)
        title = TFYDemoTab.timeline.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func routeConfiguration(
        history: TFYSwiftRouteHistory
    ) -> TFYSwiftUIKitRouteConfiguration<TFYDemoTimelineRoute> {
        .init(
            rootScope: TFYDemoTab.timeline.scope,
            rootRoute: TFYDemoTimelineRoute(),
            destinationID: "demo.root.timeline"
        ) { _, _ in
            TFYDemoTimelineViewController(history: history)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "event")
        tableView.rowHeight = 74
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            primaryAction: UIAction { [weak self] _ in self?.history.removeAll() }
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "清空路由事件"
        history.onChange = { [weak self] in self?.tableView.reloadData() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        history.events.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let event = history.events.reversed()[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "event", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.text = event.name.rawValue
        content.secondaryText = "\(event.scope.rawValue) · \(event.routeName) · \(String(format: "%.1f", event.elapsedMilliseconds)) ms"
        content.secondaryTextProperties.numberOfLines = 2
        content.image = UIImage(systemName: symbol(for: event.name))
        content.imageProperties.tintColor = color(for: event.name)
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        cell.accessibilityIdentifier = "demo.timeline.event.\(indexPath.row)"
        return cell
    }

    private func symbol(for name: TFYSwiftRouteEventName) -> String {
        switch name {
        case .completed, .presented: "checkmark.circle.fill"
        case .failed, .cancelled: "exclamationmark.triangle.fill"
        case .redirected, .deduplicated: "arrow.triangle.turn.up.right.circle.fill"
        default: "circle.dotted"
        }
    }

    private func color(for name: TFYSwiftRouteEventName) -> UIColor {
        switch name {
        case .completed, .presented: .systemGreen
        case .failed, .cancelled: .systemRed
        case .redirected, .deduplicated: .systemOrange
        default: .systemBlue
        }
    }
}

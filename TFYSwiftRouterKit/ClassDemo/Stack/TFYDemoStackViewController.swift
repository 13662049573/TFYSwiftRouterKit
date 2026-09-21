import UIKit

final class TFYDemoStackViewController: UITableViewController {
    private let loadModel: () -> TFYDemoStackModel
    private let onSelect: (TFYDemoTab) -> Void
    private var model = TFYDemoStackModel(snapshots: [])

    init(
        loadModel: @escaping () -> TFYDemoStackModel,
        onSelect: @escaping (TFYDemoTab) -> Void
    ) {
        self.loadModel = loadModel
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = TFYDemoTab.stack.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            primaryAction: UIAction { [weak self] _ in self?.reload() }
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "刷新导航栈"
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        model.snapshots.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Scope 与可恢复导航栈"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "点击一项会通过 TabBar Driver 选择对应 Scope。"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let snapshot = model.snapshots[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = snapshot.tab.title
        cell.detailTextLabel?.text = snapshot.routeNames.isEmpty
            ? "空栈"
            : snapshot.routeNames.joined(separator: "  →  ")
        cell.detailTextLabel?.numberOfLines = 2
        cell.imageView?.image = UIImage(systemName: snapshot.tab.symbol)
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "demo.stack.\(snapshot.tab.rawValue)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect(model.snapshots[indexPath.row].tab)
    }

    private func reload() {
        model = loadModel()
        tableView.reloadData()
    }
}

import UIKit

final class TFYSwiftDemoInspectorViewController: UITableViewController {
    private let history: TFYSwiftRouteHistory

    init(history: TFYSwiftRouteHistory) {
        self.history = history
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Route Inspector"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "清空",
            style: .plain,
            target: self,
            action: #selector(clear)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        history.events.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let event = history.events.reversed()[indexPath.row]
        cell.textLabel?.text = event.name.rawValue
        cell.detailTextLabel?.text = "\(event.routeName.components(separatedBy: ".").last ?? event.routeName) · \(String(format: "%.1f", event.elapsedMilliseconds)) ms\(event.message.map { " · \($0)" } ?? "")"
        cell.detailTextLabel?.numberOfLines = 2
        return cell
    }

    @objc private func clear() {
        history.removeAll()
        tableView.reloadData()
    }
}

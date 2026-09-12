import UIKit

final class TFYSwiftDemoSelectorViewController: UITableViewController {
    private let values = ["类型安全", "模块解耦", "异步结果", "Deep Link"]
    private let routeResult: TFYSwiftRouteResult?

    init(result: TFYSwiftRouteResult?) {
        routeResult = result
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择一个能力"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { values.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = values[indexPath.row]
        cell.detailTextLabel?.text = "点击后通过 async/await 返回 String"
        cell.accessoryType = .checkmark
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        routeResult?.finish(with: values[indexPath.row])
        dismiss(animated: true)
    }

    @objc private func cancel() {
        routeResult?.cancel()
        dismiss(animated: true)
    }
}

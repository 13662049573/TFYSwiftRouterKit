import UIKit

final class TFYSwiftDemoValuePickerViewController: UITableViewController {
    private let values: [String]
    private let routeResult: TFYSwiftRouteResult?

    init(title: String, values: [String], result: TFYSwiftRouteResult?) {
        self.values = values
        routeResult = result
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        cell.detailTextLabel?.text = "点击后通过强类型 RouteResult 返回"
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

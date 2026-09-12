import UIKit

class TFYSwiftDemoMenuViewController: UITableViewController {
    struct Action {
        let title: String
        let detail: String
        let symbol: String
        let run: @MainActor () async throws -> Void
    }

    private var sections: [(title: String, actions: [Action])] = []

    init(title: String) {
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSections(_ sections: [(title: String, actions: [Action])]) {
        self.sections = sections
        if isViewLoaded { tableView.reloadData() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .always
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].actions.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = sections[indexPath.section].actions[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = action.title
        content.secondaryText = action.detail
        content.image = UIImage(systemName: action.symbol)
        content.secondaryTextProperties.color = .secondaryLabel
        content.imageProperties.tintColor = view.tintColor
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "demo-action-\(action.title)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let operation = sections[indexPath.section].actions[indexPath.row].run
        Task { @MainActor [weak self] in
            do { try await operation() }
            catch TFYSwiftRouteError.cancelled { return }
            catch { self?.show(error) }
        }
    }

    func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func show(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showMessage(title: "路由提示", message: message)
    }
}

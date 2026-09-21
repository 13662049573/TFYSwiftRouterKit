import UIKit

final class TFYDemoPlaygroundViewController: UITableViewController, TFYDemoWindowCloseHandling {
    private enum Mode { case menu, detail, session }

    private let mode: Mode
    private let model: TFYDemoPlaygroundModel?
    private let detail: (title: String, message: String)?
    private let onAction: ((TFYDemoPlaygroundAction) -> Void)?
    private let onRestoreRoot: (() -> Void)?
    private let sessionContext: TFYSwiftTypedDestinationContext<TFYDemoPlaygroundSessionRoute>?
    private let statusLabel = UILabel()
    private var commandTask: Task<Void, Never>?
    var onClose: (() -> Void)?

    init(model: TFYDemoPlaygroundModel, onAction: @escaping (TFYDemoPlaygroundAction) -> Void) {
        mode = .menu
        self.model = model
        detail = nil
        self.onAction = onAction
        onRestoreRoot = nil
        sessionContext = nil
        super.init(style: .insetGrouped)
        title = TFYDemoTab.playground.title
    }

    init(title: String, message: String, onRestoreRoot: (() -> Void)? = nil) {
        mode = .detail
        model = nil
        detail = (title, message)
        onAction = nil
        self.onRestoreRoot = onRestoreRoot
        sessionContext = nil
        super.init(style: .insetGrouped)
        self.title = title
    }

    init(sessionContext: TFYSwiftTypedDestinationContext<TFYDemoPlaygroundSessionRoute>) {
        mode = .session
        model = nil
        detail = nil
        onAction = nil
        onRestoreRoot = nil
        self.sessionContext = sessionContext
        super.init(style: .insetGrouped)
        title = sessionContext.input.name
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { commandTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        switch mode {
        case .menu: tableView.tableHeaderView = makeHeader()
        case .detail: break
        case .session: configureSessionHeader()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        mode == .menu ? model?.sections.count ?? 0 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .menu: model?.sections[section].items.count ?? 0
        case .detail: onRestoreRoot == nil ? 2 : 3
        case .session: 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch mode {
        case .menu: model?.sections[section].title
        case .detail: "Route Destination"
        case .session: "等待超时或调用方取消"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        mode == .menu ? model?.sections[section].footer : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch mode {
        case .menu:
            let item = model!.sections[indexPath.section].items[indexPath.row]
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = item.subtitle
            cell.detailTextLabel?.numberOfLines = 2
            cell.imageView?.image = UIImage(systemName: item.symbol)
            cell.imageView?.tintColor = item.tint
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = item.accessibilityID
            return cell
        case .detail:
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.textLabel?.text = detail?.title
                cell.detailTextLabel?.text = detail?.message
                cell.detailTextLabel?.numberOfLines = 0
                cell.selectionStyle = .none
                return cell
            }
            if indexPath.row == 1 {
                return buttonCell(title: "完成", identifier: "demo.destination.done", filled: true) { [weak self] in
                    self?.close()
                }
            }
            return buttonCell(title: "恢复当前 Tab 根路由", identifier: "demo.destination.restoreRoot") { [weak self] in
                self?.onRestoreRoot?()
            }
        case .session:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.textLabel?.text = "Session 生命周期进行中"
            cell.detailTextLabel?.text = "Router 会统一结束 Result、Command 与 Event。"
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard mode == .menu, let action = model?.sections[indexPath.section].items[indexPath.row].action else { return }
        onAction?(action)
    }

    private func close() {
        if let onClose { onClose(); return }
        if let onRestoreRoot { onRestoreRoot(); return }
        if presentingViewController != nil || navigationController?.presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func configureSessionHeader() {
        statusLabel.frame = CGRect(x: 0, y: 0, width: 1, height: 92)
        statusLabel.text = "等待调用方结束交互"
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        tableView.tableHeaderView = statusLabel
        commandTask = Task { @MainActor [weak self] in
            guard let self, let stream = try? sessionContext?.commands() else { return }
            for await command in stream {
                guard !Task.isCancelled else { return }
                if case .updateStatus(let text) = command { statusLabel.text = text }
            }
        }
    }

    private func makeHeader() -> UIView {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height: 116))
        label.text = "Router Playground\n呈现、策略、可靠性与恢复"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .title2)
        label.textColor = .systemTeal
        return label
    }

    private func buttonCell(
        title: String,
        identifier: String,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        let configuration: UIButton.Configuration = filled ? .filled() : .tinted()
        let button = UIButton(configuration: configuration, primaryAction: UIAction(title: title) { _ in action() })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = identifier
        cell.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return cell
    }
}

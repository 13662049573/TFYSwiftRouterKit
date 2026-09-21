import SwiftUI
import UIKit

final class TFYDemoStartViewController: UITableViewController {
    private enum Mode { case menu, picker, session }

    private let mode: Mode
    private let model: TFYDemoStartModel?
    private let onAction: ((TFYDemoStartAction) -> Void)?
    private let pickerContext: TFYSwiftTypedDestinationContext<TFYDemoStartPickerRoute>?
    private let sessionContext: TFYSwiftTypedDestinationContext<TFYDemoStartSessionRoute>?
    private let statusLabel = UILabel()
    private var commandTask: Task<Void, Never>?

    init(model: TFYDemoStartModel, onAction: @escaping (TFYDemoStartAction) -> Void) {
        mode = .menu
        self.model = model
        self.onAction = onAction
        pickerContext = nil
        sessionContext = nil
        super.init(style: .insetGrouped)
        title = TFYDemoTab.start.title
    }

    init(pickerContext: TFYSwiftTypedDestinationContext<TFYDemoStartPickerRoute>) {
        mode = .picker
        model = nil
        onAction = nil
        self.pickerContext = pickerContext
        sessionContext = nil
        super.init(style: .insetGrouped)
        title = pickerContext.input.title
    }

    init(sessionContext: TFYSwiftTypedDestinationContext<TFYDemoStartSessionRoute>) {
        mode = .session
        model = nil
        onAction = nil
        pickerContext = nil
        self.sessionContext = sessionContext
        super.init(style: .insetGrouped)
        title = "双向 Session"
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
        case .menu: tableView.tableHeaderView = makeMenuHeader()
        case .picker: break
        case .session: configureSessionHeader()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        mode == .menu ? model?.sections.count ?? 0 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .menu: model?.sections[section].items.count ?? 0
        case .picker: pickerContext?.input.options.count ?? 0
        case .session: 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch mode {
        case .menu: model?.sections[section].title
        case .picker: "选择后通过 context.finish 返回"
        case .session: "页面向调用方发送事件并完成会话"
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
        case .picker:
            let option = pickerContext!.input.options[indexPath.row]
            return buttonCell(title: option, identifier: "demo.picker.option.\(indexPath.row)") { [weak self] in
                try? self?.pickerContext?.finish(option)
            }
        case .session:
            if indexPath.row == 0 {
                return buttonCell(title: "发送页面事件", identifier: "demo.session.event") { [weak self] in
                    guard let self else { return }
                    statusLabel.text = "页面事件已发送，等待调用方确认"
                    try? sessionContext?.send(.tapped("demo.session.event"))
                }
            }
            return buttonCell(title: "完成会话", identifier: "demo.session.finish", filled: true) { [weak self] in
                try? self?.sessionContext?.finish(.init(summary: "会话已完成"))
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard mode == .menu, let action = model?.sections[indexPath.section].items[indexPath.row].action else { return }
        onAction?(action)
    }

    private func configureSessionHeader() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 128))
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.text = "你好，\(sessionContext?.input.name ?? "")"
        titleLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "等待调用方命令"
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        container.addSubview(titleLabel)
        container.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])
        tableView.tableHeaderView = container
        commandTask = Task { @MainActor [weak self] in
            guard let self, let stream = try? sessionContext?.commands() else { return }
            for await command in stream {
                guard !Task.isCancelled else { return }
                if case .updateStatus(let text) = command { statusLabel.text = text }
            }
        }
    }

    private func makeMenuHeader() -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 132))
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.text = "TFYSwiftRouterKit"
        titleLabel.textColor = .white
        let detailLabel = UILabel()
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.text = "默认路径简单，复杂能力按需出现"
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemIndigo
        card.layer.cornerRadius = 12
        container.addSubview(card)
        card.addSubview(titleLabel)
        card.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12)
        ])
        return container
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

struct TFYDemoStartSwiftUIView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift").font(.system(size: 56, weight: .semibold)).foregroundStyle(.orange)
            Text("SwiftUI Destination").font(.title.bold())
            Text("同一个 UIKit Router 可以按需打开 UIHostingController。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

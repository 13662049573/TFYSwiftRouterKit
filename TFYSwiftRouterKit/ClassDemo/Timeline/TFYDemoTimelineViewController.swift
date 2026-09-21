import UIKit

final class TFYDemoTimelineViewController: UITableViewController {
    private let loadModel: () -> TFYDemoTimelineModel
    private let onClear: () -> Void
    private var model = TFYDemoTimelineModel(rows: [])

    init(
        loadModel: @escaping () -> TFYDemoTimelineModel,
        onClear: @escaping () -> Void
    ) {
        self.loadModel = loadModel
        self.onClear = onClear
        super.init(style: .plain)
        title = TFYDemoTab.timeline.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 74
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            primaryAction: UIAction { [weak self] _ in self?.onClear() }
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "清空路由事件"
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        model.rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = model.rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = row.name
        cell.detailTextLabel?.text = row.detail
        cell.detailTextLabel?.numberOfLines = 2
        cell.imageView?.image = UIImage(systemName: row.symbol)
        cell.imageView?.tintColor = row.color
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = row.accessibilityID
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = model.rows[indexPath.row]
        navigationController?.pushViewController(
            TFYDemoTimelineDetailViewController(row: row),
            animated: true
        )
    }

    func reload() {
        model = loadModel()
        tableView.reloadData()
    }
}

private final class TFYDemoTimelineDetailViewController: UIViewController {
    private let row: TFYDemoTimelineRow

    init(row: TFYDemoTimelineRow) {
        self.row = row
        super.init(nibName: nil, bundle: nil)
        title = "事件详情"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.text = row.fullDetail
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        textView.accessibilityIdentifier = "demo.timeline.detail"
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}

import UIKit

final class TFYSwiftDemoInteractiveProductViewController: UIViewController {
    private let product: TFYSwiftDemoProduct
    private let context: TFYSwiftDestinationContext
    private let statusLabel = UILabel()
    private var favoriteCount = 0
    private var commandTask: Task<Void, Never>?

    init(product: TFYSwiftDemoProduct, context: TFYSwiftDestinationContext) {
        self.product = product
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "商品详情 / 路由会话"
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.text = product.name

        let modelLabel = UILabel()
        modelLabel.font = .preferredFont(forTextStyle: .body)
        modelLabel.numberOfLines = 0
        modelLabel.textColor = .secondaryLabel
        modelLabel.text = "完整模型输入\nid: \(product.id)\nprice: \(product.price)\ntags: \(product.tags.joined(separator: ", "))"

        statusLabel.font = .preferredFont(forTextStyle: .callout)
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .systemBlue
        statusLabel.text = context.interaction?.commands == nil
            ? "普通模型路由：本次未创建双向命令通道"
            : "等待上游组件发送命令…"
        statusLabel.accessibilityIdentifier = "interactive-status"

        let favorite = button(title: "点击回调：收藏", action: #selector(favoriteTapped))
        let share = button(title: "点击回调：分享", action: #selector(shareTapped))
        let finish = button(title: "完成并返回结果", action: #selector(finishTapped))
        finish.configuration?.baseBackgroundColor = .systemGreen
        finish.configuration?.baseForegroundColor = .white

        let stack = UIStackView(arrangedSubviews: [titleLabel, modelLabel, statusLabel, favorite, share, finish])
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(28, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28)
        ])

        if context.interaction?.commands != nil { observeCommands() }
    }

    deinit { commandTask?.cancel() }

    private func button(title: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .medium
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func observeCommands() {
        commandTask = Task { @MainActor [weak self, context] in
            do {
                let commands: AsyncStream<TFYSwiftDemoProductCommand> = try context.commands()
                for await command in commands {
                    guard let self else { return }
                    switch command {
                    case .refresh:
                        statusLabel.text = "✅ 收到上游命令：refresh；页面方法已触发"
                    case .updateBadge(let value):
                        statusLabel.text = "✅ 收到上游命令：updateBadge(\(value))"
                    }
                }
            } catch {
                self?.statusLabel.text = "命令通道错误：\(error.localizedDescription)"
            }
        }
    }

    @objc private func favoriteTapped() {
        favoriteCount += 1
        try? context.send(TFYSwiftDemoProductEvent.favoriteTapped(productID: product.id))
        statusLabel.text = "已向调用组件连续回调收藏事件 × \(favoriteCount)"
    }

    @objc private func shareTapped() {
        try? context.send(TFYSwiftDemoProductEvent.shareTapped(productID: product.id))
        statusLabel.text = "已向调用组件回调分享事件"
    }

    @objc private func finishTapped() {
        context.result?.finish(with: TFYSwiftDemoProductOutput(
            productID: product.id,
            favoriteCount: favoriteCount,
            didConfirm: true
        ))
        navigationController?.popViewController(animated: true)
    }
}

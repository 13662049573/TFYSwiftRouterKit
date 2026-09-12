import UIKit

final class TFYSwiftDemoDetailViewController: UIViewController {
    private let heading: String
    private let message: String
    private let color: UIColor

    init(heading: String, message: String, color: UIColor) {
        self.heading = heading
        self.message = message
        self.color = color
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = heading
        view.backgroundColor = .systemBackground

        let symbol = UIImageView(image: UIImage(systemName: "point.3.connected.trianglepath.dotted"))
        symbol.tintColor = color
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 58, weight: .semibold)
        symbol.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = heading
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "关闭模态页面"
        buttonConfiguration.image = UIImage(systemName: "xmark")
        buttonConfiguration.imagePadding = 8
        let closeButton = UIButton(configuration: buttonConfiguration)
        closeButton.isHidden = navigationController != nil
        closeButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [symbol, titleLabel, messageLabel, closeButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }
}

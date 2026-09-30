import UIKit

enum TFYDemoTheme {
    static let background = UIColor.black
    static let surface = UIColor(white: 0.10, alpha: 1)
    static let secondary = UIColor(white: 0.66, alpha: 1)
    static let green = UIColor(red: 0.20, green: 0.91, blue: 0.37, alpha: 1)
    static let mint = UIColor(red: 0.36, green: 0.96, blue: 0.71, alpha: 1)
    static let gold = UIColor(red: 1, green: 0.80, blue: 0.48, alpha: 1)

    @MainActor static func label(
        _ text: String, size: CGFloat = 16, weight: UIFont.Weight = .regular, color: UIColor = .white
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    @MainActor static func button(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> UIButton {
        var config: UIButton.Configuration = primary ? .filled() : .plain()
        config.title = title
        config.baseBackgroundColor = green
        config.baseForegroundColor = primary ? .black : .white
        config.cornerStyle = .capsule
        config.contentInsets = .init(top: 14, leading: 20, bottom: 14, trailing: 20)
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }
}

/// 通用业务页面；刷新由可见页面按需执行，不订阅隐藏页的全量事件。
class TFYDemoViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TFYDemoTheme.background
        view.tintColor = TFYDemoTheme.green
    }

    func installStack(_ stack: UIStackView, inset: CGFloat = 20) {
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: inset),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -inset),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -110),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -inset * 2),
        ])
    }

    func showMessage(_ title: String, message: String = "") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

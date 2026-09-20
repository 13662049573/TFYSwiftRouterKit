import SwiftUI
import UIKit

@MainActor
protocol TFYDemoCloseHandling: AnyObject {
    var onClose: (() -> Void)? { get set }
}

final class TFYDemoDetailViewController: UIViewController, TFYDemoCloseHandling {
    private let route: TFYDemoDetailRoute
    var onClose: (() -> Void)?
    var onRestoreRoot: (() -> Void)?

    init(route: TFYDemoDetailRoute) {
        self.route = route
        super.init(nibName: nil, bundle: nil)
        title = route.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func routeConfiguration(
        onRestoreRoot: @escaping (TFYSwiftNavigationScopeID) -> Void
    ) -> TFYSwiftUIKitRouteConfiguration<TFYDemoDetailRoute> {
        .init(destinationID: "demo.detail") { route, context in
            let controller = TFYDemoDetailViewController(route: route)
            if case .replace = context.presentation {
                let scope = context.routeContext.scope
                controller.onRestoreRoot = { onRestoreRoot(scope) }
            }
            return controller
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "arrow.triangle.branch"))
        icon.tintColor = .systemIndigo
        icon.preferredSymbolConfiguration = .init(pointSize: 50, weight: .medium)
        icon.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        titleLabel.text = route.title
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textColor = .secondaryLabel
        messageLabel.text = route.message
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        let metadata = UILabel()
        metadata.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        metadata.textColor = .secondaryLabel
        metadata.textAlignment = .center
        metadata.numberOfLines = 0
        metadata.text = "RouteConfiguration 创建页面\nNavigationDriver 负责展示"

        let closeButton = UIButton(configuration: .filled(), primaryAction: UIAction(title: "完成") { [weak self] _ in
            self?.close()
        })
        closeButton.accessibilityIdentifier = "demo.destination.done"

        var arranged: [UIView] = [icon, titleLabel, messageLabel, metadata, closeButton]
        if onRestoreRoot != nil {
            let rootButton = UIButton(configuration: .bordered(), primaryAction: UIAction(title: "恢复当前 Tab 根路由") { [weak self] _ in
                self?.onRestoreRoot?()
            })
            rootButton.accessibilityIdentifier = "demo.destination.restoreRoot"
            arranged.append(rootButton)
        }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 18
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 70),
            stack.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    private func close() {
        if let onClose { onClose(); return }
        if presentingViewController != nil || navigationController?.presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}

final class TFYDemoPickerViewController: UIViewController {
    private let context: TFYSwiftTypedDestinationContext<TFYDemoPickerRoute>

    init(context: TFYSwiftTypedDestinationContext<TFYDemoPickerRoute>) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
        title = context.input.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<TFYDemoPickerRoute> {
        .init(destinationID: "demo.picker", typedFactory: { _, context in
            TFYDemoPickerViewController(context: context)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        titleLabel.text = context.input.title
        titleLabel.numberOfLines = 0

        let buttons = context.input.options.enumerated().map { index, option in
            var configuration = UIButton.Configuration.tinted()
            configuration.title = option
            configuration.image = UIImage(systemName: "checkmark.circle")
            configuration.imagePadding = 10
            let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
                try? self?.context.finish(option)
            })
            button.accessibilityIdentifier = "demo.picker.option.\(index)"
            return button
        }
        let stack = UIStackView(arrangedSubviews: [titleLabel] + buttons)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }
}

final class TFYDemoSessionViewController: UIViewController {
    private let context: TFYSwiftTypedDestinationContext<TFYDemoSessionRoute>
    private let statusLabel = UILabel()
    private var commandTask: Task<Void, Never>?

    init(context: TFYSwiftTypedDestinationContext<TFYDemoSessionRoute>) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
        title = "双向 Session"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { commandTask?.cancel() }

    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<TFYDemoSessionRoute> {
        .init(destinationID: "demo.session", typedFactory: { _, context in
            TFYDemoSessionViewController(context: context)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        titleLabel.text = "你好，\(context.input.name)"
        titleLabel.textAlignment = .center

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "等待调用方命令"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let eventButton = UIButton(configuration: .tinted(), primaryAction: UIAction(title: "发送页面事件") { [weak self] _ in
            try? self?.context.send(.tapped("demo.session.event"))
        })
        eventButton.accessibilityIdentifier = "demo.session.event"

        let finishButton = UIButton(configuration: .filled(), primaryAction: UIAction(title: "完成会话") { [weak self] _ in
            try? self?.context.finish(.init(summary: "会话已完成"))
        })
        finishButton.accessibilityIdentifier = "demo.session.finish"

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, eventButton, finishButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 18
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])

        commandTask = Task { @MainActor [weak self] in
            guard let self, let stream = try? context.commands() else { return }
            for await command in stream {
                guard !Task.isCancelled else { return }
                if case .updateStatus(let text) = command { statusLabel.text = text }
            }
        }
    }
}

struct TFYDemoSwiftUIView: View {
    static func routeConfiguration() -> TFYSwiftUIKitRouteConfiguration<TFYDemoSwiftUIRoute> {
        .init(destinationID: "demo.swiftui") { _, _ in
            UIHostingController(rootView: TFYDemoSwiftUIView())
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "swift")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.orange)
            Text("SwiftUI Destination")
                .font(.title.bold())
            Text("同一份 RouteConfiguration 可以把 UIKit Router 与 UIHostingController 关联起来。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

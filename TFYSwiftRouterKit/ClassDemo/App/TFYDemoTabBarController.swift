import UIKit

enum TFYDemoTab: String, CaseIterable, Sendable {
    case home, free, publish, member, profile
    var scope: TFYSwiftNavigationScopeID { .init("video.\(rawValue)") }
    var title: String {
        switch self {
        case .home: "首页"
        case .free: "免费"
        case .publish: "发布"
        case .member: "会员"
        case .profile: "我的"
        }
    }
}

final class TFYDemoTabBarController: UITabBarController, UINavigationControllerDelegate {
    let floatingBar = TFYDemoFloatingTabBar()
    var onSelect: ((TFYDemoTab) -> Void)?
    override var selectedIndex: Int { didSet { if isViewLoaded { refreshBar() } } }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark
        if #available(iOS 18.0, *) { setTabBarHidden(true, animated: false) }
        tabBar.isHidden = true
        floatingBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(floatingBar)
        NSLayoutConstraint.activate([
            floatingBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            floatingBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            floatingBar.heightAnchor.constraint(equalToConstant: 58),
            floatingBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -2),
        ])
        floatingBar.onSelect = { [weak self] in self?.onSelect?($0) }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBar.isHidden = true
        view.bringSubviewToFront(floatingBar)
    }
    func refreshBar() {
        guard isViewLoaded, TFYDemoTab.allCases.indices.contains(selectedIndex) else { return }
        floatingBar.select(TFYDemoTab.allCases[selectedIndex])
        guard let nav = selectedViewController as? UINavigationController else { return }
        let visible = nav.visibleViewController === nav.viewControllers.first && nav.presentedViewController == nil
        floatingBar.isUserInteractionEnabled = visible
        floatingBar.isHidden = !visible
        floatingBar.alpha = visible ? 1 : 0
    }
    func navigationController(
        _ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool
    ) {
        let root = navigationController.viewControllers.first === viewController
        navigationController.setNavigationBarHidden(root, animated: animated)
        guard navigationController === selectedViewController else { return }
        floatingBar.isHidden = false
        floatingBar.isUserInteractionEnabled = root
        if animated, let coordinator = navigationController.transitionCoordinator {
            coordinator.animate(
                alongsideTransition: { [weak self] _ in self?.floatingBar.alpha = root ? 1 : 0 },
                completion: { [weak self] _ in self?.refreshBar() })
        } else {
            floatingBar.alpha = root ? 1 : 0
            floatingBar.isHidden = !root
        }
    }
    func navigationController(
        _ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool
    ) {
        navigationController.setNavigationBarHidden(
            navigationController.viewControllers.first === viewController, animated: false)
        refreshBar()
    }
}

final class TFYDemoFloatingTabBar: UIView {
    var onSelect: ((TFYDemoTab) -> Void)?
    private var buttons: [TFYDemoTab: UIButton] = [:]
    init() {
        super.init(frame: .zero)
        accessibilityIdentifier = "video.tabbar"
        layer.cornerRadius = 29
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = TFYDemoTheme.mint.withAlphaComponent(0.28).cgColor
        layer.shadowOpacity = 0.32
        layer.shadowRadius = 12
        layer.shadowOffset = .init(width: 0, height: 4)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.clipsToBounds = true
        blur.layer.cornerRadius = 29
        addSubview(blur)
        let stack = UIStackView()
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for tab in TFYDemoTab.allCases {
            let button = UIButton(type: .system)
            button.accessibilityIdentifier = "video.tab.\(tab.rawValue)"
            button.accessibilityLabel = tab.title
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            button.setTitle(tab == .publish ? "" : tab.title, for: .normal)
            button.layer.cornerRadius = 27
            if tab == .publish {
                let plus = TFYDemoPlusView()
                plus.isUserInteractionEnabled = false
                plus.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(plus)
                NSLayoutConstraint.activate([
                    plus.widthAnchor.constraint(equalToConstant: 36), plus.heightAnchor.constraint(equalToConstant: 36),
                    plus.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    plus.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                ])
            }
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(tab) }, for: .touchUpInside)
            buttons[tab] = button
            stack.addArrangedSubview(button)
        }
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor), blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
        select(.home)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 29).cgPath
    }
    func select(_ tab: TFYDemoTab) {
        for (item, button) in buttons {
            button.setTitleColor(item == tab ? TFYDemoTheme.green : .white.withAlphaComponent(0.88), for: .normal)
            button.backgroundColor = item == tab ? .white.withAlphaComponent(0.12) : .clear
            button.accessibilityTraits = item == tab ? [.button, .selected] : .button
        }
    }
}

private final class TFYDemoPlusView: UIView {
    private let gradient = CAGradientLayer()
    private let circle = CAShapeLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [TFYDemoTheme.green.cgColor, TFYDemoTheme.green.cgColor, UIColor.systemBlue.cgColor]
        gradient.locations = [0, 0.65, 1]
        gradient.mask = circle
        circle.fillColor = UIColor.clear.cgColor
        circle.strokeColor = UIColor.white.cgColor
        circle.lineWidth = 4
        layer.addSublayer(gradient)
        let label = TFYDemoTheme.label("+", size: 37, weight: .light, color: TFYDemoTheme.green)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        circle.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).cgPath
    }
}

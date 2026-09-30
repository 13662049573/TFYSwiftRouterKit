import UIKit

final class TFYDemoProfileViewController: TFYDemoViewController {
    var onLogin: (() -> Void)?
    var onMember: (() -> Void)?
    var onRoute: ((TFYDemoProfileRoute) -> Void)?
    var onHistory: (() -> Void)?
    private let state: TFYDemoAppState
    private let accountLabel = TFYDemoTheme.label("", size: 26, weight: .bold)
    private let summary = TFYDemoTheme.label("", size: 14, color: TFYDemoTheme.secondary)
    private var loginButton: UIButton!
    init(state: TFYDemoAppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "video.profile"
        let avatar = TFYDemoTheme.label("◉", size: 65, color: TFYDemoTheme.green)
        loginButton = TFYDemoTheme.button("登录 / 注册", primary: true) { [weak self] in self?.onLogin?() }
        loginButton.accessibilityIdentifier = "video.profile.login"
        let vip = TFYDemoTheme.button("VIP 会员   ·   解锁更多精彩") { [weak self] in self?.onMember?() }
        vip.backgroundColor = UIColor(red: 0.2, green: 0.16, blue: 0.09, alpha: 1)
        vip.layer.cornerRadius = 15
        let stack = UIStackView(arrangedSubviews: [avatar, accountLabel, summary, loginButton, vip])
        for (name, route) in [("我的收藏", TFYDemoProfileRoute.collections), ("我的作品", .posts), ("设置", .settings)] {
            let button = TFYDemoTheme.button("\(name)  ›") { [weak self] in self?.onRoute?(route) }
            button.accessibilityIdentifier = "video.profile.\(route)"
            stack.addArrangedSubview(button)
        }
        stack.addArrangedSubview(TFYDemoTheme.button("观看历史  ›") { [weak self] in self?.onHistory?() })
        installStack(stack)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshState()
    }
    func refreshState() {
        guard isViewLoaded else { return }
        accountLabel.text = state.account ?? "欢迎来到光影"
        summary.text =
            "收藏 \(state.collections[state.accountKey, default: []].count)    ·    作品 \(state.posts[state.accountKey, default: []].count)    ·    \(state.isMember ? "VIP会员" : "普通用户")"
        loginButton.isHidden = state.account != nil
    }
}

final class TFYDemoLoginViewController: TFYDemoViewController {
    var onFinish: ((String) -> Void)?
    var onCancel: (() -> Void)?
    private let reason: String
    private let field = UITextField()
    init(reason: String) {
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "登录光影"
        navigationItem.leftBarButtonItem = .init(
            title: "取消", primaryAction: UIAction { [weak self] _ in self?.onCancel?() })
        field.placeholder = "请输入昵称"
        field.text = "光影体验官"
        field.font = .systemFont(ofSize: 18)
        field.backgroundColor = TFYDemoTheme.surface
        field.textColor = .white
        field.heightAnchor.constraint(equalToConstant: 52).isActive = true
        field.accessibilityIdentifier = "video.login.account"
        let submit = TFYDemoTheme.button("同意并登录", primary: true) { [weak self] in
            guard let self else { return }
            let text = self.field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                self.showMessage("请输入昵称")
                return
            }
            self.view.endEditing(true)
            self.onFinish?(text)
        }
        submit.accessibilityIdentifier = "video.login.submit"
        installStack(
            UIStackView(arrangedSubviews: [
                TFYDemoTheme.label("发现好故事", size: 32, weight: .bold),
                TFYDemoTheme.label(reason, color: TFYDemoTheme.secondary), field, submit,
                TFYDemoTheme.label("本地模拟登录，无需手机号或验证码。", size: 13, color: TFYDemoTheme.secondary),
            ]))
    }
}

final class TFYDemoSettingsViewController: TFYDemoViewController {
    var onLogout: (() -> Void)?
    private let state: TFYDemoAppState
    init(state: TFYDemoAppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        let notifications = UISwitch()
        notifications.isOn = true
        let row = UIStackView(arrangedSubviews: [TFYDemoTheme.label("接收内容推荐"), notifications])
        let clear = TFYDemoTheme.button("清除观看历史") { [weak self] in
            guard let self else { return }
            self.state.history[self.state.accountKey] = []
            self.showMessage("观看历史已清除")
        }
        let logout = TFYDemoTheme.button("退出登录") { [weak self] in self?.onLogout?() }
        logout.accessibilityIdentifier = "video.logout"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
        installStack(
            UIStackView(arrangedSubviews: [
                row, clear, logout, TFYDemoTheme.label("光影 Demo \(version) · 本地演示环境", size: 13, color: TFYDemoTheme.secondary),
            ]))
    }
}

extension TFYDemoProfileViewController: TFYDemoStateRefreshing {}

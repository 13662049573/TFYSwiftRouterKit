import UIKit

final class TFYDemoMemberViewController: TFYDemoViewController {
    let state: TFYDemoAppState
    var onBuy: ((TFYDemoMembershipPlan) -> Void)?
    private let status = TFYDemoTheme.label("", size: 30, weight: .bold, color: TFYDemoTheme.gold)
    init(state: TFYDemoAppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "video.member"
        let stack = UIStackView(arrangedSubviews: [
            TFYDemoTheme.label("光影 VIP", size: 18, weight: .semibold, color: TFYDemoTheme.gold), status,
            TFYDemoTheme.label("好故事，值得每一刻", size: 16, color: TFYDemoTheme.secondary),
        ])
        let model = TFYDemoMemberModel()
        for plan in model.plans {
            let card = TFYDemoTheme.button("\(plan.name)   ¥\(plan.price) / \(plan.duration)") { [weak self] in
                self?.onBuy?(plan)
            }
            card.backgroundColor = UIColor(red: 0.18, green: 0.15, blue: 0.10, alpha: 1)
            card.layer.cornerRadius = 16
            card.layer.borderColor = TFYDemoTheme.gold.withAlphaComponent(0.5).cgColor
            card.layer.borderWidth = 1
            card.tintColor = TFYDemoTheme.gold
            card.accessibilityIdentifier = "video.plan.\(plan.price)"
            stack.addArrangedSubview(card)
        }
        stack.addArrangedSubview(TFYDemoTheme.label("专属权益", size: 22, weight: .bold))
        for benefit in model.benefits {
            stack.addArrangedSubview(TFYDemoTheme.label("✦  \(benefit)", size: 17, color: TFYDemoTheme.gold))
        }
        stack.addArrangedSubview(
            TFYDemoTheme.label("本地项目演示：套餐及订单为模拟数据，确认开通不会产生真实扣款。", size: 13, color: TFYDemoTheme.secondary))
        installStack(stack)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshState()
    }
    func refreshState() {
        guard isViewLoaded else { return }
        status.text = state.isMember ? "会员已开通" : "开启你的精彩时光"
    }
}

final class TFYDemoCheckoutViewController: TFYDemoViewController {
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    private let plan: TFYDemoMembershipPlan
    private let account: String
    init(plan: TFYDemoMembershipPlan, account: String) {
        self.plan = plan
        self.account = account
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "确认开通"
        navigationItem.leftBarButtonItem = .init(
            title: "取消", primaryAction: UIAction { [weak self] _ in self?.onCancel?() })
        let pay = TFYDemoTheme.button("确认开通（模拟支付）", primary: true) { [weak self] in self?.onFinish?() }
        pay.accessibilityIdentifier = "video.buy.confirm"
        installStack(
            UIStackView(arrangedSubviews: [
                TFYDemoTheme.label(plan.name, size: 30, weight: .bold, color: TFYDemoTheme.gold),
                TFYDemoTheme.label("¥\(plan.price)", size: 42, weight: .bold),
                TFYDemoTheme.label("开通账号：\(account)\n有效期：\(plan.duration)", size: 16, color: TFYDemoTheme.secondary),
                TFYDemoTheme.label("订单归属当前账号。此处仅模拟订单完成，不会扣款。", size: 14, color: TFYDemoTheme.secondary), pay,
            ]))
    }
}

extension TFYDemoMemberViewController: TFYDemoStateRefreshing {}

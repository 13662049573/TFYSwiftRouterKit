import UIKit

final class TFYSwiftDemoCheckoutViewController: UIViewController {
    private let snapshot: TFYSwiftDemoCartSnapshot
    private let context: TFYSwiftDestinationContext
    private let router: TFYSwiftRouter
    private let couponLabel = UILabel()
    private var selectedCoupon: String?

    init(
        snapshot: TFYSwiftDemoCartSnapshot,
        context: TFYSwiftDestinationContext,
        router: TFYSwiftRouter
    ) {
        self.snapshot = snapshot
        self.context = context
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "确认订单"
        view.backgroundColor = .systemBackground

        let summary = UILabel()
        summary.font = .preferredFont(forTextStyle: .title2)
        summary.numberOfLines = 0
        summary.text = "来自 CartInput 的完整模型\n商品种类：\(snapshot.lines.count)\n商品数量：\(snapshot.totalQuantity)"

        couponLabel.font = .preferredFont(forTextStyle: .body)
        couponLabel.textColor = .secondaryLabel
        couponLabel.text = "优惠券：未选择"

        let couponButton = makeButton(title: "Sheet 路由选择优惠券", color: .systemBlue) { [weak self] in
            self?.selectCoupon()
        }
        let confirmButton = makeButton(title: "提交订单并回调 Cart", color: .systemGreen) { [weak self] in
            self?.confirm()
        }

        let stack = UIStackView(arrangedSubviews: [summary, couponLabel, couponButton, confirmButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32)
        ])
    }

    private func makeButton(title: String, color: UIColor, action: @escaping @MainActor () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func selectCoupon() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let coupon: String = try await router.open(
                    TFYSwiftDemoCartRoute.couponPicker,
                    presentation: .sheet(),
                    scope: context.routeContext.scope,
                    expecting: String.self
                )
                selectedCoupon = coupon
                couponLabel.text = "优惠券：\(coupon)"
            } catch TFYSwiftRouteError.cancelled {
                couponLabel.text = "优惠券：已取消"
            } catch {
                show(error)
            }
        }
    }

    private func confirm() {
        context.result?.finish(with: TFYSwiftDemoCheckoutOutput(
            orderID: "ORDER-\(Int(Date().timeIntervalSince1970))",
            coupon: selectedCoupon
        ))
        navigationController?.popViewController(animated: true)
    }

    private func show(_ error: Error) {
        let alert = UIAlertController(title: "结算失败", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

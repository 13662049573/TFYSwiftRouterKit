import UIKit

/// CartImplementation root. Cart data comes from a protocol service registered by the app root.
final class TFYSwiftDemoCartViewController: TFYSwiftDemoMenuViewController {
    private let navigator: any TFYSwiftDemoNavigating
    private let services: TFYSwiftComponentServiceRegistry
    private var snapshot = TFYSwiftDemoCartSnapshot(lines: [])

    init(navigator: any TFYSwiftDemoNavigating, services: TFYSwiftComponentServiceRegistry) {
        self.navigator = navigator
        self.services = services
        super.init(title: "购物车组件")
        rebuildActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { @MainActor [weak self] in await self?.reloadCart() }
    }

    private func reloadCart() async {
        do {
            let cart = try services.resolve(TFYSwiftDemoComponentKeys.cart)
            snapshot = await cart.snapshot()
            navigationController?.tabBarItem.badgeValue = snapshot.totalQuantity == 0 ? nil : "\(snapshot.totalQuantity)"
            rebuildActions()
        } catch {
            showMessage(title: "CartService 错误", message: error.localizedDescription)
        }
    }

    private func rebuildActions() {
        let lineActions = snapshot.lines.map { line in
            Action(
                title: line.name,
                detail: "\(line.productID) · 数量 \(line.quantity)",
                symbol: "cart.fill"
            ) { [weak self] in
                try await self?.navigator.open(
                    TFYSwiftDemoProductRoute.detail(id: line.productID),
                    input: TFYSwiftDemoCatalog.product(id: line.productID),
                    in: .products,
                    presentation: .push()
                )
            }
        }
        let displayedLines = lineActions.isEmpty ? [
            Action(
                title: "购物车为空",
                detail: "先去商品组件添加商品",
                symbol: "cart"
            ) { [weak self] in try await self?.navigator.select(.products, popToRoot: false) }
        ] : lineActions

        setSections([
            ("Cart 状态（Service Protocol）", displayedLines),
            ("Cart 自有路由流程", [
                Action(
                    title: "结算：Input → 嵌套路由 → Output",
                    detail: "传 CartSnapshot，Sheet 选券，最终回调订单号",
                    symbol: "creditcard"
                ) { [weak self] in
                    guard let self else { return }
                    var current = snapshot
                    if current.lines.isEmpty {
                        let cart = try services.resolve(TFYSwiftDemoComponentKeys.cart)
                        current = try await cart.add(TFYSwiftDemoCatalog.product(id: "SKU-1001"))
                    }
                    let output: TFYSwiftDemoCheckoutOutput = try await navigator.open(
                        TFYSwiftDemoCartRoute.checkout,
                        input: current,
                        in: .cart,
                        presentation: .push(),
                        expecting: TFYSwiftDemoCheckoutOutput.self
                    )
                    showMessage(
                        title: "Checkout 回调到 Cart",
                        message: "orderID = \(output.orderID)\ncoupon = \(output.coupon ?? "无")"
                    )
                    await reloadCart()
                },
                Action(
                    title: "清空购物车",
                    detail: "调用 CartInterface.clear，不触发页面路由",
                    symbol: "trash"
                ) { [weak self] in
                    guard let self else { return }
                    let cart = try services.resolve(TFYSwiftDemoComponentKeys.cart)
                    await cart.clear()
                    await reloadCart()
                }
            ]),
            ("Cart 跨组件", [
                Action(
                    title: "继续选购",
                    detail: "切换 Product Tab，保留 Cart 当前导航栈",
                    symbol: "arrow.right.square"
                ) { [weak self] in try await self?.navigator.select(.products, popToRoot: false) },
                Action(
                    title: "查看我的订单",
                    detail: "切换 Profile Scope，并经过 AuthenticationInterceptor",
                    symbol: "list.bullet.rectangle"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoProfileRoute.orders,
                        in: .profile,
                        presentation: .push()
                    )
                }
            ])
        ])
    }
}

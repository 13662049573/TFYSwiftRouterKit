import UIKit

/// ProductImplementation root. Its navigation flow is isolated in `demo.products` Scope.
final class TFYSwiftDemoProductsViewController: TFYSwiftDemoMenuViewController {
    private let navigator: any TFYSwiftDemoNavigating
    private let productFlow: TFYSwiftDemoProductFlow
    private let services: TFYSwiftComponentServiceRegistry
    private var callbackLog: [String] = []

    init(
        navigator: any TFYSwiftDemoNavigating,
        productFlow: TFYSwiftDemoProductFlow,
        services: TFYSwiftComponentServiceRegistry
    ) {
        self.navigator = navigator
        self.productFlow = productFlow
        self.services = services
        super.init(title: "商品组件")
        rebuildActions()
    }

    private func rebuildActions() {
        let productActions = TFYSwiftDemoCatalog.products.map { product in
            Action(
                title: product.name,
                detail: "\(product.id) · ¥\(product.price) · 完整 Session",
                symbol: "shippingbox"
            ) { [weak self] in
                guard let self else { return }
                callbackLog.removeAll()
                let output = try await productFlow.open(product, returnTo: .products) { [weak self] event in
                    switch event {
                    case .favoriteTapped: self?.callbackLog.append("favoriteTapped")
                    case .shareTapped: self?.callbackLog.append("shareTapped")
                    }
                }
                showMessage(
                    title: "商品页最终结果",
                    message: "confirmed = \(output.didConfirm)\nevents = \(callbackLog.joined(separator: ", "))"
                )
            }
        }

        setSections([
            ("Product 自有路由流程", productActions + [
                Action(
                    title: "商品评价（同 Tab Push）",
                    detail: "ProductRoute.reviews；保持其他三个 Tab 栈不变",
                    symbol: "text.bubble"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoProductRoute.reviews(productID: "SKU-2026"),
                        in: .products,
                        presentation: .push()
                    )
                }
            ]),
            ("Product 跨组件", [
                Action(
                    title: "加入购物车并切换 Cart",
                    detail: "调用 CartInterface 服务后切换 Tab；不引用 CartViewController",
                    symbol: "cart.badge.plus"
                ) { [weak self] in
                    guard let self else { return }
                    let cart = try services.resolve(TFYSwiftDemoComponentKeys.cart)
                    let snapshot = try await cart.add(TFYSwiftDemoCatalog.product(id: "SKU-3008"))
                    tabBarItem.badgeValue = nil
                    try await navigator.select(.cart, popToRoot: false)
                    tabBarController?.viewControllers?[TFYSwiftDemoTab.cart.rawValue].tabBarItem.badgeValue = "\(snapshot.totalQuantity)"
                },
                Action(
                    title: "查看商品作者资料",
                    detail: "ProductRoute 调用方切换到 Profile Scope",
                    symbol: "person.text.rectangle"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoProfileRoute.user(id: "AUTHOR-7"),
                        in: .profile,
                        presentation: .push()
                    )
                }
            ])
        ])
    }
}

import UIKit

/// ProfileImplementation root with protected routes, sheet result, and cross-tab navigation.
final class TFYSwiftDemoProfileViewController: TFYSwiftDemoMenuViewController {
    private let navigator: any TFYSwiftDemoNavigating
    private let productFlow: TFYSwiftDemoProductFlow
    private var selectedTheme = "跟随系统"

    init(navigator: any TFYSwiftDemoNavigating, productFlow: TFYSwiftDemoProductFlow) {
        self.navigator = navigator
        self.productFlow = productFlow
        super.init(title: "我的组件")
        rebuildActions()
    }

    private func rebuildActions() {
        setSections([
            ("Profile 自有路由流程", [
                Action(
                    title: "受保护的订单页面",
                    detail: "未登录时 suspend，模拟登录后恢复同一 transaction",
                    symbol: "lock.shield"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoProfileRoute.orders,
                        in: .profile,
                        presentation: .push()
                    )
                },
                Action(
                    title: "设置 Sheet",
                    detail: "Presentation 与 ProfileRoute 分离",
                    symbol: "gearshape"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoProfileRoute.settings,
                        in: .profile,
                        presentation: .sheet()
                    )
                },
                Action(
                    title: "选择主题并返回值",
                    detail: "当前：\(selectedTheme)；Sheet → String 回调 → 刷新 Profile",
                    symbol: "circle.lefthalf.filled"
                ) { [weak self] in
                    guard let self else { return }
                    let theme: String = try await navigator.open(
                        TFYSwiftDemoProfileRoute.themePicker,
                        input: (),
                        in: .profile,
                        presentation: .sheet(),
                        expecting: String.self
                    )
                    selectedTheme = theme
                    rebuildActions()
                    showMessage(title: "Profile 收到回调", message: "主题已选择：\(theme)")
                }
            ]),
            ("Profile 跨组件", [
                Action(
                    title: "查看推荐商品",
                    detail: "Profile → Product，包含模型传值与 Session 回调",
                    symbol: "gift"
                ) { [weak self] in
                    guard let self else { return }
                    let output = try await productFlow.open(
                        TFYSwiftDemoCatalog.product(id: "SKU-3008"),
                        returnTo: .profile
                    ) { _ in }
                    showMessage(title: "Product 返回 Profile", message: "favoriteCount = \(output.favoriteCount)")
                },
                Action(
                    title: "切换到购物车",
                    detail: "只依赖 Tab 导航协议，不引用 Cart 页面实现",
                    symbol: "cart"
                ) { [weak self] in try await self?.navigator.select(.cart, popToRoot: false) }
            ])
        ])
    }
}

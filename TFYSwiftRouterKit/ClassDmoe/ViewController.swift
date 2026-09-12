import UIKit

/// HomeImplementation. It only knows navigation/service contracts and never references Product,
/// Cart, or Profile view controller implementations.
final class TFYSwiftDemoHomeViewController: TFYSwiftDemoMenuViewController {
    private let navigator: any TFYSwiftDemoNavigating
    private let productFlow: TFYSwiftDemoProductFlow
    private let services: TFYSwiftComponentServiceRegistry
    private let deepLinkHandler: @MainActor (URL) async throws -> Void
    private var callbackLog: [String] = []

    init(
        navigator: any TFYSwiftDemoNavigating,
        productFlow: TFYSwiftDemoProductFlow,
        services: TFYSwiftComponentServiceRegistry,
        deepLinkHandler: @escaping @MainActor (URL) async throws -> Void
    ) {
        self.navigator = navigator
        self.productFlow = productFlow
        self.services = services
        self.deepLinkHandler = deepLinkHandler
        super.init(title: "组件路由首页")
        rebuildActions()
    }

    private func rebuildActions() {
        setSections([
            ("新增能力完整演示", [
                Action(
                    title: "路由能力实验室",
                    detail: "强类型契约、超时取消、注册回滚、恢复迁移、SwiftUI、测试替身",
                    symbol: "testtube.2"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoHomeRoute.laboratory,
                        in: .home,
                        presentation: .fullScreen()
                    )
                }
            ]),
            ("完整跨组件流程", [
                Action(
                    title: "Home → Product 双向会话",
                    detail: "切换商品 Tab，传完整模型、方法命令、连续点击回调和最终结果",
                    symbol: "arrow.left.arrow.right.circle"
                ) { [weak self] in
                    guard let self else { return }
                    callbackLog.removeAll()
                    let product = TFYSwiftDemoCatalog.product(id: "SKU-2026")
                    let output = try await productFlow.open(product, returnTo: .home) { [weak self] event in
                        switch event {
                        case .favoriteTapped(let id): self?.callbackLog.append("收藏(\(id))")
                        case .shareTapped(let id): self?.callbackLog.append("分享(\(id))")
                        }
                    }
                    showMessage(
                        title: "Product 回调到 Home",
                        message: "最终结果：\(output.productID)，收藏 \(output.favoriteCount) 次\n连续事件：\(callbackLog.joined(separator: "、"))"
                    )
                },
                Action(
                    title: "Home → Cart 服务 + 路由",
                    detail: "先调用 CartInterface.add，再切换 Cart Scope 展示数据",
                    symbol: "cart.badge.plus"
                ) { [weak self] in
                    guard let self else { return }
                    let cart = try services.resolve(TFYSwiftDemoComponentKeys.cart)
                    _ = try await cart.add(TFYSwiftDemoCatalog.product(id: "SKU-1001"))
                    try await navigator.select(.cart, popToRoot: false)
                },
                Action(
                    title: "Home → Profile 跨 Tab",
                    detail: "调用方只声明 ProfileRoute.user，不持有目标页面",
                    symbol: "person.crop.circle.badge.checkmark"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoProfileRoute.user(id: "TFY-1024"),
                        in: .profile,
                        presentation: .push()
                    )
                }
            ]),
            ("外部入口与可观测性", [
                Action(
                    title: "Deep Link → Product Tab",
                    detail: "tfyswift://product/DEEP-88 经过校验、解析、选 Tab 和路由注册表",
                    symbol: "link"
                ) { [weak self] in
                    guard let url = URL(string: "tfyswift://product/DEEP-88") else { return }
                    try await self?.deepLinkHandler(url)
                },
                Action(
                    title: "查看 Router Inspector",
                    detail: "所有 Tab 共用 transaction 观测，导航栈按 Scope 隔离",
                    symbol: "waveform.path.ecg.rectangle"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoHomeRoute.inspector,
                        in: .home,
                        presentation: .push()
                    )
                },
                Action(
                    title: "查看注册与解耦说明",
                    detail: "Feature Interface / Implementation / App Composition Root",
                    symbol: "point.3.connected.trianglepath.dotted"
                ) { [weak self] in
                    try await self?.navigator.open(
                        TFYSwiftDemoHomeRoute.architecture,
                        in: .home,
                        presentation: .push()
                    )
                }
            ])
        ])
    }
}

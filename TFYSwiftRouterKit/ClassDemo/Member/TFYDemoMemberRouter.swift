import UIKit

@MainActor
final class TFYDemoMemberRouter {
    private unowned let app: TFYDemoAppCoordinator
    init(app: TFYDemoAppCoordinator) { self.app = app }
    func make() -> UIViewController {
        let page = TFYDemoMemberViewController(state: app.state)
        page.onBuy = { [weak self] in self?.app.buy($0) }
        return page
    }
    func makeCheckout(_ context: TFYSwiftTypedDestinationContext<TFYDemoBuyRoute>) -> UIViewController {
        let account = app.state.accountKey
        let page = TFYDemoCheckoutViewController(plan: context.input, account: account)
        page.onFinish = { try? context.finish(.init(id: UUID().uuidString, account: account, plan: context.input)) }
        page.onCancel = { context.cancel() }
        return UINavigationController(rootViewController: page)
    }
}

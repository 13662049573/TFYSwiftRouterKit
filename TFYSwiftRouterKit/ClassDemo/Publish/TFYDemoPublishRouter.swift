import UIKit

@MainActor
final class TFYDemoPublishRouter {
    private unowned let app: TFYDemoAppCoordinator
    init(app: TFYDemoAppCoordinator) { self.app = app }
    func make(_ context: TFYSwiftTypedDestinationContext<TFYDemoPublishRoute>) -> UIViewController {
        let page = TFYDemoPublishViewController(draft: context.input)
        page.onSave = { [weak self] in self?.app.state.draft = $0 }
        page.onFinish = { try? context.finish($0) }
        page.onCancel = { context.cancel() }
        return UINavigationController(rootViewController: page)
    }
}

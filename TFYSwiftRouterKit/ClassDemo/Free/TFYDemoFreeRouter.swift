import UIKit

@MainActor
final class TFYDemoFreeRouter {
    private unowned let app: TFYDemoAppCoordinator
    init(app: TFYDemoAppCoordinator) { self.app = app }
    func make() -> UIViewController {
        let page = TFYDemoFreeViewController(state: app.state)
        page.onVideo = { [weak self] in self?.app.home.open(.detail($0.id), scope: TFYDemoTab.free.scope) }
        return page
    }
}

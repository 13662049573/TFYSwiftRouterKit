import UIKit

@MainActor
final class TFYDemoProfileRouter {
    private unowned let app: TFYDemoAppCoordinator
    init(app: TFYDemoAppCoordinator) { self.app = app }
    func make(_ route: TFYDemoProfileRoute) -> UIViewController {
        switch route {
        case .root:
            let page = TFYDemoProfileViewController(state: app.state)
            page.onLogin = { [weak self] in self?.app.login() }
            page.onMember = { [weak self] in self?.app.select(.member) }
            page.onRoute = { [weak self] in self?.app.open($0, scope: TFYDemoTab.profile.scope) }
            page.onHistory = { [weak self] in self?.app.home.open(.history, scope: TFYDemoTab.profile.scope) }
            return page
        case .collections:
            let page = TFYDemoLibraryViewController(
                state: app.state, title: "我的收藏", videos: TFYDemoProfileModel(state: app.state).collectedVideos)
            page.onVideo = { [weak self] in self?.app.home.open(.detail($0.id), scope: TFYDemoTab.profile.scope) }
            return page
        case .posts:
            let posts = TFYDemoProfileModel(state: app.state).posts
            return TFYDemoTextListViewController(title: "我的作品", rows: posts.map { ($0.title, $0.body) })
        case .settings:
            let page = TFYDemoSettingsViewController(state: app.state)
            page.onLogout = { [weak self] in self?.app.logout() }
            return page
        }
    }
    func makeLogin(_ context: TFYSwiftTypedDestinationContext<TFYDemoLoginRoute>) -> UIViewController {
        let page = TFYDemoLoginViewController(reason: context.input)
        page.onFinish = { try? context.finish($0) }
        page.onCancel = { context.cancel() }
        return UINavigationController(rootViewController: page)
    }
}

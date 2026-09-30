import UIKit

@MainActor
final class TFYDemoHomeRouter {
    private unowned let app: TFYDemoAppCoordinator
    init(app: TFYDemoAppCoordinator) { self.app = app }
    func open(_ route: TFYDemoHomeRoute, scope: TFYSwiftNavigationScopeID = TFYDemoTab.home.scope) {
        app.open(route, scope: scope)
    }
    func make(_ route: TFYDemoHomeRoute, scope: TFYSwiftNavigationScopeID) throws -> UIViewController {
        switch route {
        case .root:
            let page = TFYDemoHomeViewController(state: app.state)
            page.onVideo = { [weak self] in self?.open(.detail($0.id)) }
            page.onSearch = { [weak self] in self?.open(.search) }
            page.onHistory = { [weak self] in self?.open(.history) }
            page.onInbox = { [weak self] in self?.open(.inbox) }
            return page
        case .search:
            let page = TFYDemoSearchViewController(state: app.state)
            page.onVideo = { [weak self] in self?.open(.detail($0.id), scope: scope) }
            return page
        case .detail(let id):
            guard let video = app.state.video(id) else { throw TFYSwiftRouteError.destinationUnavailable("视频不存在") }
            let page = TFYDemoVideoDetailViewController(state: app.state, video: video)
            page.onPlay = { [weak self] episode in self?.open(.player(id, episode: episode), scope: scope) }
            page.onMember = { [weak self] in self?.app.select(.member) }
            return page
        case .player(let id, let episode):
            guard let video = app.state.video(id) else { throw TFYSwiftRouteError.destinationUnavailable("视频不存在") }
            let page = TFYDemoPlayerViewController(video: video, episode: episode)
            app.state.recordPlayback(id)
            page.onClose = { [weak self] in self?.app.dismiss(scope) }
            return page
        case .history:
            let ids = app.state.history[app.state.accountKey, default: []]
            let page = TFYDemoLibraryViewController(
                state: app.state, title: "观看历史", videos: ids.compactMap { app.state.video($0) })
            page.onVideo = { [weak self] in self?.open(.detail($0.id), scope: scope) }
            return page
        case .inbox:
            return TFYDemoTextListViewController(
                title: "消息中心", rows: [("欢迎来到光影", "发现好故事，记录每一次喜欢。"), ("限时免费片单", "本周精选内容已更新，前往免费专区观看。")])
        }
    }
}

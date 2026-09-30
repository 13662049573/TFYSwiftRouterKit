import Foundation

struct TFYDemoFreeModel {
    let state: TFYDemoAppState
    @MainActor func videos(category: Int) -> [TFYDemoVideo] {
        let name = ["全部", "电视剧", "电影", "综艺"][category]
        return state.videos.filter { !$0.vip && (category == 0 || $0.category == name) }
    }
}

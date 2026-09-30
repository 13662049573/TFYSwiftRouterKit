import Foundation

struct TFYDemoProfileModel {
    let state: TFYDemoAppState
    @MainActor var collectedVideos: [TFYDemoVideo] { state.videos.filter { state.isCollected($0.id) } }
    @MainActor var posts: [TFYDemoPost] { state.posts[state.accountKey, default: []] }
}

import Foundation

struct TFYDemoHomeModel {
    let state: TFYDemoAppState
    @MainActor func search(_ text: String) -> [TFYDemoVideo] {
        text.isEmpty
            ? state.videos
            : state.videos.filter {
                $0.title.localizedCaseInsensitiveContains(text) || $0.tags.contains { $0.contains(text) }
            }
    }
}

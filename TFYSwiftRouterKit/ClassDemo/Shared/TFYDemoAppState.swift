import Foundation

struct TFYDemoVideo: Hashable, Sendable {
    let id: String
    let title: String
    let category: String
    let update: String
    let badge: String
    let tags: [String]
    let vip: Bool
    let posterIndex: Int
    let synopsis: String
    var episodeCount: Int {
        switch id {
        case "crime": 24
        case "weapon": 5
        case "jade", "comedy": 18
        case "summer": 36
        default: 1
        }
    }
    static let samples: [Self] = [
        .init(
            id: "comedy", title: "喜剧之王单口季第3季", category: "综艺", update: "08–18期", badge: "独播", tags: ["观察式喜剧 笑是生活的解药"],
            vip: false, posterIndex: 0, synopsis: "新一季喜剧舞台开场，用生活里的小事讲出属于自己的故事。"),
        .init(
            id: "know", title: "抓特务", category: "电影", update: "8.6", badge: "VIP", tags: ["近1月上新", "电影热播榜No.3"],
            vip: true, posterIndex: 1, synopsis: "两代人的命运在一条街巷交汇，平凡生活背后，是一场漫长的追寻。"),
        .init(
            id: "crime", title: "低智商犯罪", category: "电视剧", update: "24集全", badge: "", tags: ["热度破10000", "田曦薇"],
            vip: false, posterIndex: 2, synopsis: "一桩离奇案件把几位性格迥异的人卷入其中，笑料与悬念接连发生。"),
        .init(
            id: "weapon", title: "重器", category: "电视剧", update: "免费看5集", badge: "限免中", tags: ["电视剧热播榜No.5", "黄景瑜"],
            vip: false, posterIndex: 3, synopsis: "青年工程师在理想与现实之间，守护信念，携手突破关键技术的重重难关。"),
        .init(
            id: "jade", title: "长安纪事", category: "电视剧", update: "更新至18集", badge: "独播", tags: ["古装新剧", "今日更新"],
            vip: false, posterIndex: 4, synopsis: "长安城里，一段关于勇气、成长与相遇的故事正在展开。"),
        .init(
            id: "summer", title: "盛夏的约定", category: "电视剧", update: "36集全", badge: "独播", tags: ["青春", "高分好剧"], vip: true,
            posterIndex: 5, synopsis: "一群年轻人重逢于盛夏，找回那些未曾说出口的心愿。"),
    ]
}

struct TFYDemoMembershipPlan: Hashable, Sendable {
    let name: String
    let price: Int
    let duration: String
    static let samples: [Self] = [
        .init(name: "连续包月", price: 19, duration: "30天"),
        .init(name: "季度会员", price: 58, duration: "90天"),
        .init(name: "年度会员", price: 198, duration: "365天"),
    ]
}
struct TFYDemoMembershipOrder: Sendable {
    let id: String
    let account: String
    let plan: TFYDemoMembershipPlan
}
struct TFYDemoPost: Sendable {
    let title: String
    let body: String
}

@MainActor
final class TFYDemoAppState {
    let videos = TFYDemoVideo.samples
    var account: String?
    var memberAccounts: Set<String> = []
    var collections: [String: Set<String>] = [:]
    var history: [String: [String]] = [:]
    var posts: [String: [TFYDemoPost]] = [:]
    var orders: [TFYDemoMembershipOrder] = []
    var draft = ""
    var lastSearch = ""
    var accountKey: String { account ?? "guest" }
    var isMember: Bool { account.map { memberAccounts.contains($0) } ?? false }
    func video(_ id: String) -> TFYDemoVideo? { videos.first { $0.id == id } }
    func isCollected(_ id: String) -> Bool { collections[accountKey, default: []].contains(id) }
    func toggleCollection(_ id: String) {
        if !collections[accountKey, default: []].insert(id).inserted { collections[accountKey]?.remove(id) }
    }
    func recordPlayback(_ id: String) {
        history[accountKey, default: []].removeAll { $0 == id }
        history[accountKey, default: []].insert(id, at: 0)
    }
}

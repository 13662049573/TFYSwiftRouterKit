import UIKit

final class TFYDemoSearchViewController: TFYDemoFeedViewController, UISearchBarDelegate {
    private let searchBar = UISearchBar()
    override var header: UIView {
        searchBar.placeholder = "搜索剧名、演员或榜单"
        searchBar.searchBarStyle = .minimal
        searchBar.searchTextField.accessibilityIdentifier = "video.search.input"
        searchBar.delegate = self
        return searchBar
    }
    override func viewDidLoad() {
        videos = state.videos
        super.viewDidLoad()
        title = "搜索"
        collection.keyboardDismissMode = .onDrag
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        state.lastSearch = searchText
        videos = TFYDemoHomeModel(state: state).search(searchText)
        collection.reloadData()
        if videos.isEmpty {
            let empty = TFYDemoTheme.label("没有找到相关内容\n换个关键词试试", size: 16, color: TFYDemoTheme.secondary)
            empty.textAlignment = .center
            collection.backgroundView = empty
        } else {
            collection.backgroundView = nil
        }
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
}

final class TFYDemoLibraryViewController: TFYDemoFeedViewController {
    private let heading: String
    init(state: TFYDemoAppState, title: String, videos: [TFYDemoVideo]) {
        heading = title
        super.init(state: state)
        self.videos = videos
        self.title = title
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override var header: UIView {
        TFYDemoTheme.label(
            videos.isEmpty ? "这里还没有内容，去发现好故事吧" : "共 \(videos.count) 部内容", size: 15, color: TFYDemoTheme.secondary)
    }
}

final class TFYDemoTextListViewController: TFYDemoViewController {
    private let rows: [(String, String)]
    init(title: String, rows: [(String, String)]) {
        self.rows = rows
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        let stack = UIStackView()
        if rows.isEmpty {
            stack.addArrangedSubview(TFYDemoTheme.label("还没有作品，点击首页的加号发布第一篇影评。", color: TFYDemoTheme.secondary))
        }
        for (heading, body) in rows {
            let card = UIStackView(arrangedSubviews: [
                TFYDemoTheme.label(heading, size: 20, weight: .semibold),
                TFYDemoTheme.label(body, size: 15, color: TFYDemoTheme.secondary),
            ])
            card.axis = .vertical
            card.spacing = 12
            card.backgroundColor = TFYDemoTheme.surface
            card.layer.cornerRadius = 12
            card.isLayoutMarginsRelativeArrangement = true
            card.layoutMargins = .init(top: 18, left: 16, bottom: 18, right: 16)
            stack.addArrangedSubview(card)
        }
        installStack(stack)
    }
}

final class TFYDemoVideoDetailViewController: TFYDemoViewController {
    var onPlay: ((Int) -> Void)?
    var onMember: (() -> Void)?
    private let state: TFYDemoAppState
    private let video: TFYDemoVideo
    private let collect = UIButton(type: .system)
    private var play: UIButton!
    init(state: TFYDemoAppState, video: TFYDemoVideo) {
        self.state = state
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "内容详情"
        view.accessibilityIdentifier = "video.detail"
        let poster = UIImageView()
        poster.contentMode = .scaleAspectFit
        poster.clipsToBounds = true
        poster.heightAnchor.constraint(equalToConstant: 270).isActive = true
        TFYDemoPosterStore.shared.load(video.posterIndex) { [weak poster] in poster?.image = $0 }
        let info = TFYDemoTheme.label(
            "\(video.category) · \(video.update)\n\(video.tags.joined(separator: " · "))", size: 14,
            color: TFYDemoTheme.secondary)
        play = TFYDemoTheme.button("立即播放", primary: true) { [weak self] in self?.beginPlayback() }
        play.accessibilityIdentifier = "video.play"
        collect.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }
                self.state.toggleCollection(self.video.id)
                self.refreshState()
            }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [
            poster, TFYDemoTheme.label(video.title, size: 26, weight: .bold), info, play, collect,
            TFYDemoTheme.label("剧情简介", size: 20, weight: .bold),
            TFYDemoTheme.label(video.synopsis, size: 16, color: TFYDemoTheme.secondary),
        ])
        stack.addArrangedSubview(TFYDemoTheme.label("选集", size: 20, weight: .bold))
        for start in stride(from: 1, through: video.episodeCount, by: 6) {
            let row = UIStackView()
            row.spacing = 8
            row.distribution = .fillEqually
            for episode in start..<start + 6 {
                if episode <= video.episodeCount {
                    let button = TFYDemoTheme.button("\(episode)") { [weak self] in
                        self?.beginPlayback(episode: episode)
                    }
                    button.configuration?.contentInsets = .init(top: 12, leading: 0, bottom: 12, trailing: 0)
                    button.accessibilityIdentifier = "video.episode.\(episode)"
                    row.addArrangedSubview(button)
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            stack.addArrangedSubview(row)
        }
        installStack(stack)
        refreshState()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshState()
    }
    func refreshState() {
        guard isViewLoaded else { return }
        collect.setTitle(state.isCollected(video.id) ? "✓ 已收藏" : "+ 收藏", for: .normal)
        collect.tintColor = TFYDemoTheme.green
        play.configuration?.title = video.vip && !state.isMember ? "开通会员观看" : "立即播放"
    }
    private func beginPlayback(episode: Int = 1) {
        if video.vip && !state.isMember { onMember?() } else { onPlay?(episode) }
    }
}
extension TFYDemoVideoDetailViewController: TFYDemoStateRefreshing {}

/// 无媒体文件时用可操作的播放器状态模拟播放，不将海报冒充真实视频。
final class TFYDemoPlayerViewController: TFYDemoViewController {
    var onClose: (() -> Void)?
    private let video: TFYDemoVideo
    private let episode: Int
    private var timer: Timer?
    private var elapsed = 0
    private var playing = true
    private let duration = 180
    private let progress = UISlider()
    private let time = TFYDemoTheme.label("00:00 / 03:00", size: 14, color: TFYDemoTheme.secondary)
    private var toggle: UIButton!
    init(video: TFYDemoVideo, episode: Int) {
        self.video = video
        self.episode = episode
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "video.player"
        let close = TFYDemoTheme.button("关闭播放") { [weak self] in self?.onClose?() }
        close.accessibilityIdentifier = "video.player.close"
        let image = UIImageView()
        image.contentMode = .scaleAspectFit
        image.heightAnchor.constraint(equalToConstant: 310).isActive = true
        TFYDemoPosterStore.shared.load(video.posterIndex) { [weak image] in image?.image = $0 }
        progress.maximumValue = Float(duration)
        progress.accessibilityIdentifier = "video.player.progress"
        progress.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }
                self.elapsed = Int(self.progress.value)
                self.updateProgress()
            }, for: .valueChanged)
        toggle = TFYDemoTheme.button("暂停", primary: true) { [weak self] in
            guard let self else { return }
            if self.elapsed == self.duration { self.elapsed = 0 }
            self.playing.toggle()
            self.toggle.configuration?.title = self.playing ? "暂停" : "继续播放"
        }
        toggle.accessibilityIdentifier = "video.player.toggle"
        installStack(
            UIStackView(arrangedSubviews: [
                close, image, TFYDemoTheme.label(video.title, size: 24, weight: .bold),
                TFYDemoTheme.label("第\(episode)集 · 本地播放演示", size: 14, color: TFYDemoTheme.green), progress, time,
                toggle,
            ]))
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard timer == nil else { return }
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] ticker in
            guard self != nil else {
                ticker.invalidate()
                return
            }
            MainActor.assumeIsolated {
                guard let self, self.playing else { return }
                self.elapsed = min(self.elapsed + 1, self.duration)
                self.updateProgress()
                if self.elapsed == self.duration {
                    self.playing = false
                    self.toggle.configuration?.title = "重新播放"
                }
            }
        }
        timer = ticker
        RunLoop.main.add(ticker, forMode: .common)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    private func updateProgress() {
        progress.value = Float(elapsed)
        time.text = String(format: "%02d:%02d / 03:00", elapsed / 60, elapsed % 60)
    }
}

import UIKit

/// 两列可复用列表。海报解码在后台完成，复用时校验内容身份。
class TFYDemoFeedViewController: TFYDemoViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let state: TFYDemoAppState
    var videos: [TFYDemoVideo] = []
    var onVideo: ((TFYDemoVideo) -> Void)?
    let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    var header: UIView { UIView() }
    var headerHeight: CGFloat { 38 }

    init(state: TFYDemoAppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        let top = header
        top.translatesAutoresizingMaskIntoConstraints = false
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.backgroundColor = .black
        collection.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        collection.contentInsetAdjustmentBehavior = .never
        collection.dataSource = self
        collection.delegate = self
        collection.register(TFYDemoVideoCell.self, forCellWithReuseIdentifier: "video")
        collection.accessibilityIdentifier = "video.feed"
        view.addSubview(top)
        view.addSubview(collection)
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 25),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            top.heightAnchor.constraint(equalToConstant: headerHeight),
            collection.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collection.reloadData()
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { videos.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "video", for: indexPath) as! TFYDemoVideoCell
        let video = videos[indexPath.item]
        cell.configure(video, collected: state.isCollected(video.id))
        cell.onCollect = { [weak self, weak cell] in
            guard let self else { return }
            self.state.toggleCollection(video.id)
            cell?.setCollected(self.state.isCollected(video.id))
        }
        cell.onMenu = { [weak self] in self?.showMenu(video, at: cell) }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onVideo?(videos[indexPath.item])
    }
    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 24) / 2)
        return .init(width: width, height: width * 4 / 3 + 58)
    }
    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSectionAt section: Int
    ) -> UIEdgeInsets { .init(top: 0, left: 8, bottom: 0, right: 8) }
    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat { 16 }
    func collectionView(
        _ collectionView: UICollectionView, layout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat { 8 }
    private func showMenu(_ video: TFYDemoVideo, at cell: UIView?) {
        let sheet = UIAlertController(title: video.title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(
            UIAlertAction(title: state.isCollected(video.id) ? "取消收藏" : "收藏", style: .default) { [weak self] _ in
                self?.state.toggleCollection(video.id)
                self?.collection.reloadData()
            })
        sheet.addAction(
            UIAlertAction(title: "不感兴趣", style: .destructive) { [weak self] _ in
                self?.videos.removeAll { $0.id == video.id }
                self?.collection.reloadData()
            })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        sheet.popoverPresentationController?.sourceView = cell ?? view
        sheet.popoverPresentationController?.sourceRect = cell?.bounds ?? .zero
        present(sheet, animated: true)
    }
}

final class TFYDemoVideoCell: UICollectionViewCell {
    private let poster = UIView()
    private let image = UIImageView()
    private let titleLabel = TFYDemoTheme.label("", size: 16, weight: .medium)
    private let tagStack = UIStackView()
    private let collect = UIButton(type: .system)
    private let menu = UIButton(type: .system)
    private var imageHeight: NSLayoutConstraint!
    private var representedID: String?
    var onCollect: (() -> Void)?
    var onMenu: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        poster.backgroundColor = UIColor(red: 0.08, green: 0.18, blue: 0.18, alpha: 1)
        poster.layer.cornerRadius = 6
        poster.clipsToBounds = true
        image.contentMode = .scaleToFill
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.85
        tagStack.spacing = 4
        tagStack.alignment = .center
        collect.tintColor = .white
        collect.backgroundColor = .clear
        collect.layer.cornerRadius = 3
        collect.setImage(nil, for: .normal)
        collect.addAction(UIAction { [weak self] _ in self?.onCollect?() }, for: .touchUpInside)
        menu.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menu.transform = .init(rotationAngle: .pi / 2)
        menu.tintColor = UIColor(white: 0.4, alpha: 1)
        menu.addAction(UIAction { [weak self] _ in self?.onMenu?() }, for: .touchUpInside)
        [poster, titleLabel, tagStack, menu].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        [image, collect].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            poster.addSubview($0)
        }
        imageHeight = image.heightAnchor.constraint(equalTo: poster.heightAnchor)
        NSLayoutConstraint.activate([
            poster.topAnchor.constraint(equalTo: contentView.topAnchor),
            poster.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            poster.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            poster.heightAnchor.constraint(equalTo: poster.widthAnchor, multiplier: 4 / 3),
            image.topAnchor.constraint(equalTo: poster.topAnchor),
            image.leadingAnchor.constraint(equalTo: poster.leadingAnchor),
            image.trailingAnchor.constraint(equalTo: poster.trailingAnchor), imageHeight,
            collect.topAnchor.constraint(equalTo: poster.topAnchor, constant: 2),
            collect.leadingAnchor.constraint(equalTo: poster.leadingAnchor, constant: 2),
            collect.widthAnchor.constraint(equalToConstant: 26), collect.heightAnchor.constraint(equalToConstant: 27),
            titleLabel.topAnchor.constraint(equalTo: poster.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            tagStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            tagStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            tagStack.trailingAnchor.constraint(lessThanOrEqualTo: menu.leadingAnchor, constant: -2),
            tagStack.heightAnchor.constraint(equalToConstant: 20),
            menu.widthAnchor.constraint(equalToConstant: 18), menu.heightAnchor.constraint(equalToConstant: 22),
            menu.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            menu.centerYAnchor.constraint(equalTo: tagStack.centerYAnchor),
        ])
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func prepareForReuse() {
        super.prepareForReuse()
        representedID = nil
        image.image = nil
        onCollect = nil
        onMenu = nil
    }
    func configure(_ video: TFYDemoVideo, collected: Bool) {
        representedID = video.id
        accessibilityIdentifier = "video.card.\(video.id)"
        titleLabel.text = video.title
        collect.accessibilityIdentifier = "video.collect.\(video.id)"
        setCollected(collected)
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, tag) in video.tags.enumerated() {
            let color: UIColor =
                tag.contains("热度")
                ? .systemRed : (tag.contains("榜") || tag.contains("上新") ? .systemOrange : TFYDemoTheme.secondary)
            let label = TFYDemoTheme.label(" \(tag) ", size: 12, color: color)
            label.numberOfLines = 1
            label.backgroundColor = UIColor(white: 0.11, alpha: 1)
            label.layer.cornerRadius = 3
            label.clipsToBounds = true
            label.setContentCompressionResistancePriority(.init(Float(750 - index)), for: .horizontal)
            tagStack.addArrangedSubview(label)
        }
        imageHeight.isActive = false
        // 图片只提供第三行海报顶部，按原比例显示；下方以原生色块补全。
        imageHeight =
            video.posterIndex < 4
            ? image.heightAnchor.constraint(equalTo: poster.heightAnchor)
            : image.heightAnchor.constraint(equalTo: poster.widthAnchor, multiplier: 44 / 204)
        imageHeight.isActive = true
        TFYDemoPosterStore.shared.load(video.posterIndex) { [weak self] result in
            guard let self, self.representedID == video.id else { return }
            self.image.image = result
        }
    }
    func setCollected(_ selected: Bool) {
        collect.setImage(selected ? UIImage(systemName: "checkmark") : nil, for: .normal)
        collect.backgroundColor = selected ? UIColor(white: 0.05, alpha: 0.9) : .clear
        collect.tintColor = selected ? TFYDemoTheme.green : .white
        collect.accessibilityLabel = selected ? "取消收藏" : "收藏"
    }
}

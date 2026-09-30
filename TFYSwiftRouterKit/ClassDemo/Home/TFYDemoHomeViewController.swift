import UIKit

final class TFYDemoHomeViewController: TFYDemoFeedViewController {
    var onSearch: (() -> Void)?
    var onHistory: (() -> Void)?
    var onInbox: (() -> Void)?
    override func viewDidLoad() {
        videos = state.videos
        super.viewDidLoad()
        view.accessibilityIdentifier = "video.home"
    }
    override var header: UIView {
        let row = UIStackView()
        row.spacing = 10
        row.alignment = .center
        let weather = TFYDemoTheme.label("晴 29°", size: 14, weight: .medium)
        weather.textAlignment = .center
        weather.textColor = UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 1)
        weather.layer.shadowColor = UIColor.cyan.cgColor
        weather.layer.shadowOpacity = 0.7
        weather.layer.shadowRadius = 10
        weather.widthAnchor.constraint(equalToConstant: 60).isActive = true
        row.addArrangedSubview(weather)
        let search = UIButton(type: .system)
        search.accessibilityIdentifier = "video.search"
        search.backgroundColor = UIColor(white: 0.16, alpha: 1)
        search.layer.cornerRadius = 19
        search.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let ai = UIView()
        let arrow = UIImageView(image: UIImage(systemName: "arrow.clockwise"))
        arrow.tintColor = TFYDemoTheme.green
        let aiLabel = TFYDemoTheme.label("AI", size: 8, weight: .semibold, color: TFYDemoTheme.green)
        [arrow, aiLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            ai.addSubview($0)
        }
        NSLayoutConstraint.activate([
            ai.widthAnchor.constraint(equalToConstant: 25), ai.heightAnchor.constraint(equalToConstant: 25),
            arrow.leadingAnchor.constraint(equalTo: ai.leadingAnchor),
            arrow.bottomAnchor.constraint(equalTo: ai.bottomAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 22), arrow.heightAnchor.constraint(equalToConstant: 22),
            aiLabel.topAnchor.constraint(equalTo: ai.topAnchor),
            aiLabel.trailingAnchor.constraint(equalTo: ai.trailingAnchor),
        ])
        let searchRow = UIStackView(arrangedSubviews: [
            TFYDemoTheme.label("深渊无间 (佳片殿堂)", size: 16, color: TFYDemoTheme.secondary),
            TFYDemoTheme.label("限免", size: 11, color: TFYDemoTheme.green),
            UIView(),
            ai,
        ])
        searchRow.arrangedSubviews.compactMap { $0 as? UILabel }.forEach {
            $0.numberOfLines = 1
            $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        }
        searchRow.arrangedSubviews.first?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        searchRow.spacing = 4
        searchRow.alignment = .center
        searchRow.isUserInteractionEnabled = false
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        search.addSubview(searchRow)
        NSLayoutConstraint.activate([
            searchRow.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            searchRow.leadingAnchor.constraint(equalTo: search.leadingAnchor, constant: 18),
            searchRow.trailingAnchor.constraint(equalTo: search.trailingAnchor, constant: -10),
            search.heightAnchor.constraint(equalToConstant: 38),
        ])
        search.addAction(UIAction { [weak self] _ in self?.onSearch?() }, for: .touchUpInside)
        row.addArrangedSubview(search)
        for (symbol, id, action) in [("clock", "history", onHistory), ("text.bubble", "inbox", onInbox)] {
            let button = UIButton(type: .system)
            button.setImage(
                UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 21)), for: .normal
            )
            button.tintColor = UIColor(white: 0.7, alpha: 1)
            button.accessibilityIdentifier = "video.\(id)"
            button.accessibilityLabel = id == "history" ? "观看历史" : "消息中心"
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            button.addAction(UIAction { _ in action?() }, for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        return row
    }
}

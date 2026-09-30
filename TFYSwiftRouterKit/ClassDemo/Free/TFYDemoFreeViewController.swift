import UIKit

final class TFYDemoFreeViewController: TFYDemoFeedViewController {
    private let categories = UISegmentedControl(items: ["全部", "电视剧", "电影", "综艺"])
    override var headerHeight: CGFloat { 85 }
    override var header: UIView {
        let row = UIStackView(arrangedSubviews: [TFYDemoTheme.label("免费专区", size: 28, weight: .bold), categories])
        row.axis = .vertical
        row.spacing = 12
        categories.selectedSegmentIndex = 0
        categories.selectedSegmentTintColor = TFYDemoTheme.green
        categories.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        categories.addAction(UIAction { [weak self] _ in self?.filter() }, for: .valueChanged)
        return row
    }
    override func viewDidLoad() {
        videos = TFYDemoFreeModel(state: state).videos(category: 0)
        super.viewDidLoad()
        view.accessibilityIdentifier = "video.free"
    }
    private func filter() {
        videos = TFYDemoFreeModel(state: state).videos(category: categories.selectedSegmentIndex)
        collection.reloadData()
    }
}

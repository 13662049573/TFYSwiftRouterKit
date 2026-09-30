import UIKit

final class TFYDemoPublishViewController: TFYDemoViewController {
    var onSave: ((String) -> Void)?
    var onFinish: ((TFYDemoPost) -> Void)?
    var onCancel: (() -> Void)?
    private let titleField = UITextField()
    private let bodyField = UITextView()
    private let draft: String
    init(draft: String) {
        self.draft = draft
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "发布影评"
        let publishItem = UIBarButtonItem(title: "发布", primaryAction: UIAction { [weak self] _ in self?.submit() })
        publishItem.accessibilityIdentifier = "video.post.submit"
        navigationItem.rightBarButtonItem = publishItem
        navigationItem.leftBarButtonItem = .init(
            title: "取消", primaryAction: UIAction { [weak self] _ in self?.onCancel?() })
        titleField.placeholder = "给你的影评起个标题"
        titleField.textColor = .white
        titleField.backgroundColor = TFYDemoTheme.surface
        titleField.layer.cornerRadius = 10
        titleField.font = .systemFont(ofSize: 18, weight: .medium)
        titleField.accessibilityIdentifier = "video.post.title"
        titleField.heightAnchor.constraint(equalToConstant: 56).isActive = true
        titleField.leftView = UIView(frame: .init(x: 0, y: 0, width: 12, height: 1))
        titleField.leftViewMode = .always
        bodyField.text = draft
        bodyField.font = .systemFont(ofSize: 16)
        bodyField.textColor = .white
        bodyField.backgroundColor = TFYDemoTheme.surface
        bodyField.layer.cornerRadius = 12
        bodyField.textContainerInset = .init(top: 16, left: 12, bottom: 16, right: 12)
        bodyField.accessibilityIdentifier = "video.post.body"
        bodyField.heightAnchor.constraint(equalToConstant: 230).isActive = true
        let save = TFYDemoTheme.button("保存草稿") { [weak self] in
            guard let self else { return }
            self.onSave?(self.bodyField.text)
            self.view.endEditing(true)
            self.showMessage("草稿已保存")
        }
        let submit = TFYDemoTheme.button("发布", primary: true) { [weak self] in self?.submit() }
        submit.accessibilityIdentifier = "video.post.submit.bottom"
        installStack(
            UIStackView(arrangedSubviews: [
                TFYDemoTheme.label("聊聊你刚看过的好故事", size: 22, weight: .bold), titleField, bodyField,
                TFYDemoTheme.label("# 今日观影  # 推荐好剧", size: 14, color: TFYDemoTheme.green), save, submit,
            ]))
    }
    private func submit() {
        let model = TFYDemoPublishModel(title: titleField.text ?? "", body: bodyField.text)
        guard model.canPublish else {
            showMessage("请填写标题和正文")
            return
        }
        view.endEditing(true)
        onFinish?(.init(title: model.title, body: model.body))
    }
}

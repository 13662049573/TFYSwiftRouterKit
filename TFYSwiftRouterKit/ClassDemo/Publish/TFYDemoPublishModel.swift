import Foundation

struct TFYDemoPublishModel {
    var title = ""
    var body = ""
    var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

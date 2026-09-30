import Foundation

enum TFYDemoHomeRoute: TFYSwiftRoute, Codable {
    case root, search, history, inbox
    case detail(String)
    case player(String, episode: Int)
}

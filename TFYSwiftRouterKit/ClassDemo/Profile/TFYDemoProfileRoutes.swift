import Foundation

enum TFYDemoProfileRoute: TFYSwiftRoute, Codable { case root, collections, posts, settings }
struct TFYDemoLoginRoute: TFYSwiftRouteContract {
    typealias Input = String
    typealias Output = String
}

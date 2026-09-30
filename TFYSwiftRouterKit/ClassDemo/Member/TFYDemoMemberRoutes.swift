import Foundation

enum TFYDemoMemberRoute: TFYSwiftRoute, Codable { case root }
struct TFYDemoBuyRoute: TFYSwiftRouteContract {
    typealias Input = TFYDemoMembershipPlan
    typealias Output = TFYDemoMembershipOrder
}

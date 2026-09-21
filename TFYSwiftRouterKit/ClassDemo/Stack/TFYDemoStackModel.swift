import Foundation

struct TFYDemoStackSnapshot {
    let tab: TFYDemoTab
    let routeNames: [String]
}

struct TFYDemoStackModel {
    let snapshots: [TFYDemoStackSnapshot]
}

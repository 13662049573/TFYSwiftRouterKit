import UIKit

@MainActor
final class TFYDemoTimelineRouter: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYDemoTab.timeline.scope,
        route: TFYDemoTimelineRoute.root
    )

    private let history: TFYSwiftRouteHistory

    init(history: TFYSwiftRouteHistory) {
        self.history = history
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.register(TFYDemoTimelineRoute.self) { [weak self] _ in
            guard let self else { throw TFYSwiftRouteError.destinationUnavailable("Timeline Router released") }
            let controller = TFYDemoTimelineViewController(
                loadModel: { [weak self] in self?.makeModel() ?? .init(rows: []) },
                onClear: { [weak self] in self?.history.removeAll() }
            )
            history.onChange = { [weak controller] in controller?.reload() }
            return controller
        }
    }

    static func registerRestorableRoutes(in registry: TFYSwiftRestorationRegistry) throws {
        try registry.register(TFYDemoTimelineRoute.self, identifier: "demo.timeline.v2")
    }

    private func makeModel() -> TFYDemoTimelineModel {
        let dateFormatter = ISO8601DateFormatter()
        return .init(rows: history.events.reversed().enumerated().map { index, event in
            .init(
                name: event.name.rawValue,
                detail: "\(event.scope.rawValue) · \(event.routeName) · \(String(format: "%.1f", event.elapsedMilliseconds)) ms",
                fullDetail: [
                    "事件：\(event.name.rawValue)",
                    "路由：\(event.routeName)",
                    "Scope：\(event.scope.rawValue)",
                    "耗时：\(String(format: "%.1f", event.elapsedMilliseconds)) ms",
                    "时间：\(dateFormatter.string(from: event.timestamp))",
                    "事务 ID：\(event.transactionID.uuidString)",
                    "事件 ID：\(event.id.uuidString)",
                    "说明：\(event.message ?? "无")"
                ].joined(separator: "\n\n"),
                symbol: symbol(for: event.name),
                color: color(for: event.name),
                accessibilityID: "demo.timeline.event.\(index)"
            )
        })
    }

    private func symbol(for name: TFYSwiftRouteEventName) -> String {
        switch name {
        case .completed, .presented: "checkmark.circle.fill"
        case .failed, .cancelled: "exclamationmark.triangle.fill"
        case .redirected, .deduplicated: "arrow.triangle.turn.up.right.circle.fill"
        default: "circle.dotted"
        }
    }

    private func color(for name: TFYSwiftRouteEventName) -> UIColor {
        switch name {
        case .completed, .presented: .systemGreen
        case .failed, .cancelled: .systemRed
        case .redirected, .deduplicated: .systemOrange
        default: .systemBlue
        }
    }
}

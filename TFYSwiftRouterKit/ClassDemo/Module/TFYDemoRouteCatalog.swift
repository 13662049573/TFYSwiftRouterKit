import UIKit

@MainActor
enum TFYDemoRouteCatalog {
    static func configurations(
        history: TFYSwiftRouteHistory,
        routes: @escaping (TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute],
        onAction: @escaping (TFYDemoAction) -> Void,
        onSelectTab: @escaping (TFYDemoTab) -> Void,
        onRestoreRoot: @escaping (TFYSwiftNavigationScopeID) -> Void
    ) -> [any TFYSwiftUIKitRouteConfiguring] {
        [
            TFYDemoStartViewController.routeConfiguration(onAction: onAction),
            TFYDemoPlaygroundViewController.routeConfiguration(onAction: onAction),
            TFYDemoStackViewController.routeConfiguration(
                routes: routes,
                onSelectTab: onSelectTab,
                onAction: onAction
            ),
            TFYDemoTimelineViewController.routeConfiguration(history: history),
            TFYDemoDetailViewController.routeConfiguration(onRestoreRoot: onRestoreRoot),
            TFYDemoPickerViewController.routeConfiguration(),
            TFYDemoSessionViewController.routeConfiguration(),
            TFYDemoSwiftUIView.routeConfiguration(),
            TFYSwiftUIKitRouteConfiguration<TFYDemoLegacyRoute>(
                destinationID: "demo.legacy"
            ) { _, _ in
                throw TFYSwiftRouteError.destinationUnavailable("Legacy Route should be redirected")
            }
        ]
    }
}

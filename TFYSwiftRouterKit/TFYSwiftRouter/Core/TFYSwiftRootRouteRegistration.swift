import Foundation

/// A type-erased root route address for one independent navigation container.
/// Feature implementations publish this value; app shells never need the concrete root screen.
public struct TFYSwiftRootRouteRegistration: Sendable {
    public let scope: TFYSwiftNavigationScopeID
    public let route: TFYSwiftAnyRoute

    public init<R: TFYSwiftRoute>(scope: TFYSwiftNavigationScopeID, route: R) {
        self.scope = scope
        self.route = TFYSwiftAnyRoute(route)
    }
}

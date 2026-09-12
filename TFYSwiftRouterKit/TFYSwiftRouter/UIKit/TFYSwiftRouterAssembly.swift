import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// Composition root that wires the UI-free router core to the UIKit/SwiftUI adapter.
@MainActor
public final class TFYSwiftRouterAssembly {
    public let routes: TFYSwiftRouteRegistry
    public let destinations: TFYSwiftUIKitDestinationRegistry
    public let driver: TFYSwiftUIKitNavigationDriver
    public let scopedDriver: TFYSwiftScopedNavigationDriver
    public let interceptors: TFYSwiftInterceptorPipeline
    public let events: TFYSwiftRouteEventCenter
    public let router: TFYSwiftRouter

    public init(
        navigationController: UINavigationController,
        initialScope: TFYSwiftNavigationScopeID = .main
    ) {
        routes = TFYSwiftRouteRegistry()
        destinations = TFYSwiftUIKitDestinationRegistry()
        driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: destinations
        )
        scopedDriver = TFYSwiftScopedNavigationDriver()
        scopedDriver.register(driver, for: initialScope)
        interceptors = TFYSwiftInterceptorPipeline()
        events = TFYSwiftRouteEventCenter()
        router = TFYSwiftRouter(
            registry: routes,
            interceptors: interceptors,
            events: events,
            driver: scopedDriver
        )
    }

    /// Adds an independent tab or flow stack while sharing route and destination registrations.
    @discardableResult
    public func register(
        navigationController: UINavigationController,
        for scope: TFYSwiftNavigationScopeID
    ) -> TFYSwiftUIKitNavigationDriver {
        let driver = TFYSwiftUIKitNavigationDriver(
            navigationController: navigationController,
            destinations: destinations
        )
        scopedDriver.register(driver, for: scope)
        return driver
    }

    public func register<R: TFYSwiftRoute>(
        _ routeType: R.Type,
        destinationID: String = String(reflecting: R.self),
        resolver: (@MainActor (R, TFYSwiftRouteContext) async throws -> TFYSwiftDestinationDescriptor)? = nil,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> UIViewController
    ) throws {
        try routes.register(routeType) { route, context in
            if let resolver { return try await resolver(route, context) }
            return TFYSwiftDestinationDescriptor(identifier: destinationID)
        }
        try destinations.register(identifier: destinationID, routeType: routeType, factory: factory)
    }
}

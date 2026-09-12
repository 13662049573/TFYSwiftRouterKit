import SwiftUI
import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
public final class TFYSwiftUIKitDestinationRegistry {
    public typealias Factory = @MainActor (TFYSwiftAnyRoute, TFYSwiftDestinationContext) throws -> UIViewController
    private var factories: [String: Factory] = [:]

    public init() {}

    public func register<R: TFYSwiftRoute>(
        identifier: String,
        routeType: R.Type,
        replacingExisting: Bool = false,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> UIViewController
    ) throws {
        if factories[identifier] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateRegistration(identifier)
        }
        factories[identifier] = { route, context in
            guard let typedRoute = route.cast(to: routeType) else {
                throw TFYSwiftRouteError.invalidPayload("页面工厂收到错误的 Route 类型")
            }
            return try factory(typedRoute, context)
        }
    }

    public func registerSwiftUI<R: TFYSwiftRoute, Content: View>(
        identifier: String,
        routeType: R.Type,
        replacingExisting: Bool = false,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> Content
    ) throws {
        try register(
            identifier: identifier,
            routeType: routeType,
            replacingExisting: replacingExisting
        ) { route, context in
            UIHostingController(rootView: try factory(route, context))
        }
    }

    public func makeViewController(
        identifier: String,
        route: TFYSwiftAnyRoute,
        context: TFYSwiftDestinationContext
    ) throws -> UIViewController {
        guard let factory = factories[identifier] else {
            throw TFYSwiftRouteError.destinationNotRegistered(identifier)
        }
        return try factory(route, context)
    }

    public var registeredDestinationIDs: [String] { factories.keys.sorted() }
}

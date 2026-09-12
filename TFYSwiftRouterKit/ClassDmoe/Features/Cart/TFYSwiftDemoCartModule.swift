import UIKit

/// CartImplementation owns Cart root, checkout and coupon destinations.
@MainActor
struct TFYSwiftDemoCartModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYSwiftDemoTab.cart.scope,
        route: TFYSwiftDemoCartRoute.root
    )

    private let navigator: any TFYSwiftDemoNavigating
    private let services: TFYSwiftComponentServiceRegistry

    init(navigator: any TFYSwiftDemoNavigating, services: TFYSwiftComponentServiceRegistry) {
        self.navigator = navigator
        self.services = services
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.routes.register(TFYSwiftDemoCartRoute.self) { route, _ in
            switch route {
            case .root: TFYSwiftDestinationDescriptor(identifier: "cart.root")
            case .summary: TFYSwiftDestinationDescriptor(identifier: "cart.summary")
            case .checkout: TFYSwiftDestinationDescriptor(identifier: "cart.checkout")
            case .couponPicker: TFYSwiftDestinationDescriptor(identifier: "cart.coupon-picker")
            }
        }
        try assembly.destinations.register(
            identifier: "cart.root",
            routeType: TFYSwiftDemoCartRoute.self
        ) { [navigator, services] _, _ in
            TFYSwiftDemoCartViewController(navigator: navigator, services: services)
        }
        try assembly.destinations.register(
            identifier: "cart.summary",
            routeType: TFYSwiftDemoCartRoute.self
        ) { _, _ in
            TFYSwiftDemoDetailViewController(
                heading: "购物车路由已定位",
                message: "外部链接或其他组件已切换到 Cart Scope，并通过 Router 打开目标。",
                color: .systemGreen
            )
        }
        try assembly.destinations.register(
            identifier: "cart.checkout",
            routeType: TFYSwiftDemoCartRoute.self
        ) { _, context in
            let snapshot: TFYSwiftDemoCartSnapshot = try context.input()
            return TFYSwiftDemoCheckoutViewController(
                snapshot: snapshot,
                context: context,
                router: assembly.router
            )
        }
        try assembly.destinations.register(
            identifier: "cart.coupon-picker",
            routeType: TFYSwiftDemoCartRoute.self
        ) { _, context in
            UINavigationController(rootViewController: TFYSwiftDemoValuePickerViewController(
                title: "选择优惠券",
                values: ["ROUTER-10", "SWIFT-20", "COMPONENT-30"],
                result: context.result
            ))
        }
    }
}

import UIKit

/// ProductImplementation owns every Product destination factory, including its Tab root.
@MainActor
struct TFYSwiftDemoProductModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYSwiftDemoTab.products.scope,
        route: TFYSwiftDemoProductRoute.root
    )

    private let navigator: any TFYSwiftDemoNavigating
    private let productFlow: TFYSwiftDemoProductFlow
    private let services: TFYSwiftComponentServiceRegistry

    init(
        navigator: any TFYSwiftDemoNavigating,
        productFlow: TFYSwiftDemoProductFlow,
        services: TFYSwiftComponentServiceRegistry
    ) {
        self.navigator = navigator
        self.productFlow = productFlow
        self.services = services
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.routes.register(TFYSwiftDemoProductRoute.self) { route, _ in
            switch route {
            case .root: TFYSwiftDestinationDescriptor(identifier: "product.root")
            case .detail: TFYSwiftDestinationDescriptor(identifier: "product.detail")
            case .reviews: TFYSwiftDestinationDescriptor(identifier: "product.reviews")
            }
        }
        try assembly.destinations.register(
            identifier: "product.root",
            routeType: TFYSwiftDemoProductRoute.self
        ) { [navigator, productFlow, services] _, _ in
            TFYSwiftDemoProductsViewController(
                navigator: navigator,
                productFlow: productFlow,
                services: services
            )
        }
        try assembly.destinations.register(
            identifier: "product.detail",
            routeType: TFYSwiftDemoProductRoute.self
        ) { route, context in
            guard case .detail(let id) = route else {
                throw TFYSwiftRouteError.invalidPayload("ProductRoute 与 detail 页面不匹配")
            }
            let product = (try? context.input(as: TFYSwiftDemoProduct.self)) ?? TFYSwiftDemoCatalog.product(id: id)
            guard product.id == id else {
                throw TFYSwiftRouteError.invalidPayload("Route ID 与 ProductInput 不一致")
            }
            return TFYSwiftDemoInteractiveProductViewController(product: product, context: context)
        }
        try assembly.destinations.register(
            identifier: "product.reviews",
            routeType: TFYSwiftDemoProductRoute.self
        ) { route, _ in
            guard case .reviews(let id) = route else {
                throw TFYSwiftRouteError.invalidPayload("ProductRoute 与 reviews 页面不匹配")
            }
            return TFYSwiftDemoDetailViewController(
                heading: "商品评价",
                message: "productID = \(id)\n同一 Product Scope 内继续 Push，其他 Tab 的栈完全不受影响。",
                color: .systemOrange
            )
        }
    }
}

import Foundation

enum TFYSwiftDemoCatalog {
    static let products = [
        TFYSwiftDemoProduct(id: "SKU-1001", name: "Swift 路由实践", price: 99, tags: ["Route", "Core"]),
        TFYSwiftDemoProduct(id: "SKU-2026", name: "组件化架构", price: 199, tags: ["Session", "Scope"]),
        TFYSwiftDemoProduct(id: "SKU-3008", name: "跨组件通信", price: 299, tags: ["Service", "Callback"])
    ]

    static func product(id: String) -> TFYSwiftDemoProduct {
        products.first { $0.id == id } ?? TFYSwiftDemoProduct(
            id: id,
            name: "Deep Link 商品",
            price: 88,
            tags: ["External Input"]
        )
    }
}

/// Product flow hides session creation from source screens and exposes only the feature contract.
@MainActor
final class TFYSwiftDemoProductFlow {
    private let navigator: any TFYSwiftDemoNavigating

    init(navigator: any TFYSwiftDemoNavigating) { self.navigator = navigator }

    func open(
        _ product: TFYSwiftDemoProduct,
        returnTo sourceTab: TFYSwiftDemoTab,
        onEvent: @escaping @MainActor @Sendable (TFYSwiftDemoProductEvent) -> Void
    ) async throws -> TFYSwiftDemoProductOutput {
        let session = navigator.openSession(
            TFYSwiftDemoProductRoute.detail(id: product.id),
            input: product,
            in: .products,
            presentation: .push(),
            commands: TFYSwiftDemoProductCommand.self,
            events: TFYSwiftDemoProductEvent.self,
            expecting: TFYSwiftDemoProductOutput.self
        )
        let eventTask = session.observeEvents(onEvent)
        try session.send(.refresh)
        try session.send(.updateBadge(3))
        do {
            let output = try await session.value
            await eventTask.value
            try await navigator.select(sourceTab, popToRoot: false)
            return output
        } catch {
            try? await navigator.select(sourceTab, popToRoot: false)
            throw error
        }
    }
}

/// The application chooses implementation modules here. AppCoordinator receives type-erased
/// module registrars and never imports or initializes feature view controllers.
@MainActor
enum TFYSwiftDemoFeatureModules {
    static func makeModules(
        navigator: any TFYSwiftDemoNavigating,
        productFlow: TFYSwiftDemoProductFlow,
        services: TFYSwiftComponentServiceRegistry,
        history: TFYSwiftRouteHistory,
        deepLinkHandler: @escaping @MainActor (URL) async throws -> Void
    ) -> [any TFYSwiftUIKitComponentModule] {
        [
            TFYSwiftDemoHomeModule(
                navigator: navigator,
                productFlow: productFlow,
                services: services,
                history: history,
                deepLinkHandler: deepLinkHandler
            ),
            TFYSwiftDemoProductModule(
                navigator: navigator,
                productFlow: productFlow,
                services: services
            ),
            TFYSwiftDemoCartModule(navigator: navigator, services: services),
            TFYSwiftDemoProfileModule(navigator: navigator, productFlow: productFlow)
        ]
    }
}

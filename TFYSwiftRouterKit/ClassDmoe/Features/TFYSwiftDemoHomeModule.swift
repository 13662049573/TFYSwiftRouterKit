import UIKit

/// HomeImplementation's only integration entry. The app shell knows this registrar, not Home VC.
@MainActor
struct TFYSwiftDemoHomeModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYSwiftDemoTab.home.scope,
        route: TFYSwiftDemoHomeRoute.root
    )

    private let navigator: any TFYSwiftDemoNavigating
    private let productFlow: TFYSwiftDemoProductFlow
    private let services: TFYSwiftComponentServiceRegistry
    private let history: TFYSwiftRouteHistory
    private let deepLinkHandler: @MainActor (URL) async throws -> Void

    init(
        navigator: any TFYSwiftDemoNavigating,
        productFlow: TFYSwiftDemoProductFlow,
        services: TFYSwiftComponentServiceRegistry,
        history: TFYSwiftRouteHistory,
        deepLinkHandler: @escaping @MainActor (URL) async throws -> Void
    ) {
        self.navigator = navigator
        self.productFlow = productFlow
        self.services = services
        self.history = history
        self.deepLinkHandler = deepLinkHandler
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.destinations.register(
            identifier: "home.laboratory",
            routeType: TFYSwiftDemoHomeRoute.self
        ) { _, _ in try TFYSwiftDemoLabNavigationController(laboratory: ()) }
        try assembly.routes.register(TFYSwiftDemoHomeRoute.self) { route, _ in
            switch route {
            case .root: TFYSwiftDestinationDescriptor(identifier: "home.root")
            case .architecture: TFYSwiftDestinationDescriptor(identifier: "home.architecture")
            case .inspector: TFYSwiftDestinationDescriptor(identifier: "home.inspector")
            case .laboratory: TFYSwiftDestinationDescriptor(identifier: "home.laboratory")
            }
        }
        try assembly.destinations.register(
            identifier: "home.root",
            routeType: TFYSwiftDemoHomeRoute.self
        ) { [navigator, productFlow, services, deepLinkHandler] _, _ in
            TFYSwiftDemoHomeViewController(
                navigator: navigator,
                productFlow: productFlow,
                services: services,
                deepLinkHandler: deepLinkHandler
            )
        }
        try assembly.destinations.register(
            identifier: "home.architecture",
            routeType: TFYSwiftDemoHomeRoute.self
        ) { _, _ in
            TFYSwiftDemoDetailViewController(
                heading: "四组件路由架构",
                message: "每个 Tab 拥有独立 Scope 和 UINavigationController。\n\nFeature 只声明 Route/Input/Command/Event/Output；App Shell 只安装组件注册地址。",
                color: .systemBlue
            )
        }
        try assembly.destinations.register(
            identifier: "home.inspector",
            routeType: TFYSwiftDemoHomeRoute.self
        ) { [history] _, _ in
            TFYSwiftDemoInspectorViewController(history: history)
        }
    }
}

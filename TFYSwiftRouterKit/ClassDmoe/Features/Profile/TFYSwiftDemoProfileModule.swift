import UIKit

/// ProfileImplementation exposes only a registrar and a typed root route address.
@MainActor
struct TFYSwiftDemoProfileModule: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYSwiftDemoTab.profile.scope,
        route: TFYSwiftDemoProfileRoute.root
    )

    private let navigator: any TFYSwiftDemoNavigating
    private let productFlow: TFYSwiftDemoProductFlow

    init(navigator: any TFYSwiftDemoNavigating, productFlow: TFYSwiftDemoProductFlow) {
        self.navigator = navigator
        self.productFlow = productFlow
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.routes.register(TFYSwiftDemoProfileRoute.self) { route, _ in
            switch route {
            case .root: TFYSwiftDestinationDescriptor(identifier: "profile.root")
            case .user: TFYSwiftDestinationDescriptor(identifier: "profile.user")
            case .orders: TFYSwiftDestinationDescriptor(identifier: "profile.orders")
            case .settings: TFYSwiftDestinationDescriptor(identifier: "profile.settings")
            case .themePicker: TFYSwiftDestinationDescriptor(identifier: "profile.theme-picker")
            }
        }
        try assembly.destinations.register(
            identifier: "profile.root",
            routeType: TFYSwiftDemoProfileRoute.self
        ) { [navigator, productFlow] _, _ in
            TFYSwiftDemoProfileViewController(navigator: navigator, productFlow: productFlow)
        }
        try assembly.destinations.register(
            identifier: "profile.user",
            routeType: TFYSwiftDemoProfileRoute.self
        ) { route, _ in
            guard case .user(let id) = route else {
                throw TFYSwiftRouteError.invalidPayload("ProfileRoute 与 user 页面不匹配")
            }
            return TFYSwiftDemoDetailViewController(
                heading: "用户资料",
                message: "userID = \(id)\n该页面可由首页、商品页或 Deep Link 跨组件到达。",
                color: .systemPurple
            )
        }
        try assembly.destinations.register(
            identifier: "profile.orders",
            routeType: TFYSwiftDemoProfileRoute.self
        ) { _, _ in
            TFYSwiftDemoDetailViewController(
                heading: "我的订单",
                message: "AuthenticationInterceptor 已恢复并继续了原始 Profile Route。",
                color: .systemIndigo
            )
        }
        try assembly.destinations.register(
            identifier: "profile.settings",
            routeType: TFYSwiftDemoProfileRoute.self
        ) { _, _ in
            TFYSwiftDemoDetailViewController(
                heading: "设置",
                message: "Profile 组件通过 sheet 展示自己的目标页面。",
                color: .systemGray
            )
        }
        try assembly.destinations.register(
            identifier: "profile.theme-picker",
            routeType: TFYSwiftDemoProfileRoute.self
        ) { _, context in
            UINavigationController(rootViewController: TFYSwiftDemoValuePickerViewController(
                title: "选择主题",
                values: ["跟随系统", "浅色", "深色"],
                result: context.result
            ))
        }
    }
}

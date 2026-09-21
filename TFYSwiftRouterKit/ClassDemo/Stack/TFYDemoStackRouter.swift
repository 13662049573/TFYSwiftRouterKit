import UIKit

@MainActor
final class TFYDemoStackRouter: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYDemoTab.stack.scope,
        route: TFYDemoStackRoute.root
    )

    private let assembly: TFYSwiftRouterAssembly
    private let showMessage: @MainActor (String, String) -> Void

    init(
        assembly: TFYSwiftRouterAssembly,
        showMessage: @escaping @MainActor (String, String) -> Void
    ) {
        self.assembly = assembly
        self.showMessage = showMessage
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.register(TFYDemoStackRoute.self) { [weak self] _ in
            guard let self else { throw TFYSwiftRouteError.destinationUnavailable("Stack Router released") }
            return TFYDemoStackViewController(
                loadModel: { [weak self] in self?.makeModel() ?? .init(snapshots: []) },
                onSelect: { [weak self] tab in self?.select(tab) }
            )
        }
    }

    static func registerRestorableRoutes(in registry: TFYSwiftRestorationRegistry) throws {
        try registry.register(TFYDemoStackRoute.self, identifier: "demo.stack.v2")
    }

    private func makeModel() -> TFYDemoStackModel {
        .init(snapshots: TFYDemoTab.allCases.map { tab in
            .init(
                tab: tab,
                routeNames: assembly.router.navigationRoutes(scope: tab.scope).map(\.typeName)
            )
        })
    }

    private func select(_ tab: TFYDemoTab) {
        do { try assembly.tabBarDriver?.select(tab.scope) }
        catch { showMessage("Scope 切换失败", error.localizedDescription) }
    }
}

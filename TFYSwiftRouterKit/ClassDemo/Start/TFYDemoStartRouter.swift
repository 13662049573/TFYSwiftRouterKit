import SwiftUI
import UIKit

@MainActor
final class TFYDemoStartRouter: TFYSwiftUIKitComponentModule {
    let rootRegistration = TFYSwiftRootRouteRegistration(
        scope: TFYDemoTab.start.scope,
        route: TFYDemoStartRoute.root
    )

    private let assembly: TFYSwiftRouterAssembly
    private let deepLinks = TFYSwiftDeepLinkEngine(policy: .app(scheme: "tfyrouter"))
    private let showMessage: @MainActor (String, String) -> Void

    init(
        assembly: TFYSwiftRouterAssembly,
        showMessage: @escaping @MainActor (String, String) -> Void
    ) {
        self.assembly = assembly
        self.showMessage = showMessage
    }

    func register(in assembly: TFYSwiftRouterAssembly) throws {
        try assembly.register(TFYDemoStartRoute.self) { [weak self] _ in
            TFYDemoStartViewController(model: TFYDemoStartModel()) { [weak self] action in
                self?.handle(action)
            }
        }
        try assembly.registerTyped(TFYDemoStartPickerRoute.self) { _, context in
            TFYDemoStartViewController(pickerContext: context)
        }
        try assembly.registerTyped(TFYDemoStartSessionRoute.self) { _, context in
            TFYDemoStartViewController(sessionContext: context)
        }
        try assembly.register(TFYDemoStartSwiftUIRoute.self) { _ in
            UIHostingController(rootView: TFYDemoStartSwiftUIView())
        }
    }

    func start() async {
        await deepLinks.add(TFYDemoStartDeepLinkParser(), priority: 100)
    }

    func handleExternalURL(_ url: URL) async throws {
        try await assembly.router.open(
            TFYSwiftDeepLinkRequest(url: url),
            using: deepLinks,
            presentation: .push(),
            scope: TFYDemoTab.playground.scope
        )
    }

    static func registerRestorableRoutes(in registry: TFYSwiftRestorationRegistry) throws {
        try registry.register(TFYDemoStartRoute.self, identifier: "demo.start.v2")
        try registry.register(TFYDemoStartSwiftUIRoute.self, identifier: "demo.start.swiftui.v2")
    }

    private func handle(_ action: TFYDemoStartAction) {
        run { [weak self] in
            guard let self else { return }
            switch action {
            case .push:
                try await openDetail(
                    title: "Push 路由",
                    message: "默认注册只需要 Route 和单参数页面工厂。",
                    scope: TFYDemoTab.start.scope
                )
            case .crossTab:
                try await openDetail(
                    title: "跨 Tab 已完成",
                    message: "TabBar Driver 根据 Scope 自动选择了演练 Tab。",
                    scope: TFYDemoTab.playground.scope
                )
            case .picker:
                let result = try await assembly.router.openTyped(
                    TFYDemoStartPickerRoute(),
                    input: .init(title: "选择路由策略", options: ["singleTop", "singleTask", "none"]),
                    presentation: .sheet(),
                    scope: TFYDemoTab.start.scope
                )
                try await assembly.router.dismiss(scope: TFYDemoTab.start.scope)
                showMessage("结果已返回", result)
            case .session:
                try await demonstrateSession()
            case .deepLink:
                guard let url = URL(string: "tfyrouter://open/detail?title=Deep%20Link%20Route") else { return }
                try await handleExternalURL(url)
            case .swiftUI:
                try await assembly.router.open(
                    TFYDemoStartSwiftUIRoute(),
                    presentation: .sheet(),
                    scope: TFYDemoTab.start.scope
                )
            case .timeline:
                try assembly.tabBarDriver?.select(TFYDemoTab.timeline.scope)
            }
        }
    }

    private func openDetail(title: String, message: String, scope: TFYSwiftNavigationScopeID) async throws {
        try await assembly.router.open(
            TFYDemoPlaygroundRoute.detail(title: title, message: message),
            presentation: .push(),
            scope: scope
        )
    }

    private func demonstrateSession() async throws {
        let session = assembly.router.openTypedSession(
            TFYDemoStartSessionRoute(),
            input: .init(name: "Router Explorer"),
            presentation: .sheet(),
            scope: TFYDemoTab.start.scope
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            try? session.send(.updateStatus("调用方命令已到达页面"))
        }
        let eventTask = Task { @MainActor in
            var iterator = session.events.makeAsyncIterator()
            let event = await iterator.next()
            if event != nil {
                try? session.send(.updateStatus("调用方已收到页面事件"))
            }
            return event
        }
        let output = try await session.value
        _ = await eventTask.value
        try await assembly.router.dismiss(scope: TFYDemoTab.start.scope)
        showMessage("会话完成", output.summary)
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor [weak self] in
            do { try await operation() }
            catch { self?.showMessage("操作未完成", error.localizedDescription) }
        }
    }
}

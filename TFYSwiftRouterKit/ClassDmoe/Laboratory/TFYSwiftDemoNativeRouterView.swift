import SwiftUI
import Combine

private enum TFYSwiftDemoNativeRoute: String, TFYSwiftRoute {
    case page, broken
}

/// 在 UIKit 宿主中嵌入真正的 SwiftUI RouterHost；内部页面由独立 NavigationStack 管理。
@MainActor
struct TFYSwiftDemoNativeRouterView: View {
    @StateObject private var model: TFYSwiftDemoNativeRouterModel

    init() throws {
        let model = try TFYSwiftDemoNativeRouterModel()
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        TFYSwiftSwiftUIRouterHost(driver: model.driver, errorContent: { error in
            // 主题、系统图标和产品文案属于 App，不再由通用路由组件固定提供。
            AnyView(VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text("演示页面暂时不可用").font(.headline)
                Text(error.localizedDescription).font(.callout)
            }.padding())
        }) {
            List {
                Section("原生 SwiftUI 导航") {
                    Button("SwiftUI Push") { model.open(.push()) }
                    Button("SwiftUI Sheet") { model.open(.sheet()) }
                    Button("SwiftUI FullScreen") { model.open(.fullScreen()) }
                    Button("SwiftUI Root") { model.open(.root()) }
                    Button("验证工厂错误回传") { model.openBroken() }
                }
                Section("最近结果") { Text(model.message).accessibilityIdentifier("swiftui-lab-status") }
            }
            .navigationTitle("SwiftUI 实验室")
        }
        .onDisappear { model.cancelPendingOperation() }
    }
}

@MainActor
private final class TFYSwiftDemoNativeRouterModel: ObservableObject {
    let driver = TFYSwiftSwiftUINavigationDriver()
    let router: TFYSwiftRouter
    @Published var message = "点击按钮后观察 NavigationStack、弹层和错误提示。"
    private var operation: Task<Void, Never>?

    init() throws {
        router = TFYSwiftRouter(driver: driver)
        try router.registry.register(TFYSwiftDemoNativeRoute.self) { route, _ in .init(identifier: route.rawValue) }
        try driver.destinations.register(identifier: "page", routeType: TFYSwiftDemoNativeRoute.self) { [weak self] _, context in
            TFYSwiftDemoNativePage(model: self, presentation: context.presentation)
        }
        try driver.destinations.register(identifier: "broken", routeType: TFYSwiftDemoNativeRoute.self) { _, _ -> Text in
            throw TFYSwiftRouteError.invalidPayload("演示工厂创建失败：错误已返回调用方，导航栈未变化")
        }
    }

    func open(_ presentation: TFYSwiftRoutePresentation) {
        perform { try await $0.router.open(TFYSwiftDemoNativeRoute.page, presentation: presentation) }
    }

    func openBroken() {
        perform { model in
            let count = model.driver.path.count
            do { try await model.router.open(TFYSwiftDemoNativeRoute.broken) }
            catch { model.message = "\(error.localizedDescription)；路径数量 \(count) → \(model.driver.path.count)" }
        }
    }

    func close(_ presentation: TFYSwiftRoutePresentation) {
        perform { model in
            switch presentation {
            case .sheet, .fullScreen: try await model.router.dismiss()
            case .root: model.message = "当前为根页面，可 Push 新页或返回外层 UIKit 实验室。"
            default: try await model.router.back()
            }
        }
    }

    func perform(_ work: @escaping @MainActor (TFYSwiftDemoNativeRouterModel) async throws -> Void) {
        operation?.cancel()
        operation = Task { @MainActor [weak self] in
            guard let self else { return }
            do { try await work(self) }
            catch { message = error.localizedDescription }
        }
    }

    func cancelPendingOperation() { operation?.cancel() }
    deinit { operation?.cancel() }
}

/// 页面弱引用流程模型，避免 model → driver → AnyView → model 的循环持有。
@MainActor
private struct TFYSwiftDemoNativePage: View {
    weak var model: TFYSwiftDemoNativeRouterModel?
    let presentation: TFYSwiftRoutePresentation

    var body: some View {
        List {
            Text("这是真正由 SwiftUI 驱动生成的页面。")
            Text("呈现：\(String(describing: presentation))")
            Button("再 Push 一页") { model?.open(.push()) }
            Button("替换当前页") { model?.open(.replace()) }
            Button("关闭 / 返回") { model?.close(presentation) }
        }
        .navigationTitle("SwiftUI 目标页")
    }
}

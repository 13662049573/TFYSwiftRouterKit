// TFYSwiftSwiftUINavigationDriver.swift
// 原生 SwiftUI 导航适配。注册 View 工厂，维护 NavigationStack/Sheet/FullScreen 状态，由 RouterHost 绑定 UI。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

#if os(iOS)
import Combine
import SwiftUI
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
/// SwiftUI 栈条目；以 UUID 比较身份，避免相同 Route 的两次 push 混淆。
public struct TFYSwiftSwiftUINavigationEntry: Identifiable, Hashable {
    /// 当前值的唯一身份；用于关联记录或区分重复地址的页面实例。
    public nonisolated let id: UUID
    /// 页面对应的平台无关目标描述符。
    public let destination: TFYSwiftDestinationDescriptor
    /// 类型擦除后的地址；具体页面通过已登记的类型恢复。
    public let route: TFYSwiftAnyRoute
    /// 创建本条目的导航事务。
    public let transaction: TFYSwiftRouteTransaction
    /// 目标页面持有的临时通信资源。
    public let interaction: TFYSwiftRouteInteraction?
    /// 已提前创建的 View 缓存，确保工厂错误在变更状态前回传。
    public var content: AnyView?
    /// 可选的一次性结果句柄；普通无返回值请求为 nil。
    public var result: TFYSwiftRouteResult? { interaction?.result }

    /// 创建独立页面条目，可传入预构造 View；默认使用新的 UUID。
    public init(
        id: UUID = UUID(),
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?,
        content: AnyView? = nil
    ) {
        self.id = id
        self.destination = destination
        self.route = route
        self.transaction = transaction
        self.interaction = interaction
        self.content = content
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
/// 按目标标识管理可抛错的 SwiftUI View 工厂。
public final class TFYSwiftSwiftUIDestinationRegistry {
    public typealias Factory = @MainActor (TFYSwiftAnyRoute, TFYSwiftDestinationContext) throws -> AnyView
    private var factories: [String: Factory] = [:]

    /// 创建空 SwiftUI 工厂表，支持同步抛错的 View 构造。
    public init() {}

    /// 按目标标识登记类型安全的页面工厂；重复标识默认抛错。
    public func register<R: TFYSwiftRoute, Content: View>(
        identifier: String,
        routeType: R.Type,
        replacingExisting: Bool = false,
        factory: @escaping @MainActor (R, TFYSwiftDestinationContext) throws -> Content
    ) throws {
        if factories[identifier] != nil, !replacingExisting {
            throw TFYSwiftRouteError.duplicateRegistration(identifier)
        }
        factories[identifier] = { route, context in
            guard let route = route.cast(to: routeType) else {
                throw TFYSwiftRouteError.invalidPayload("SwiftUI 页面工厂收到错误 Route 类型")
            }
            return AnyView(try factory(route, context))
        }
    }

    /// 检查指定类型或标识是否已经登记。
    public func contains(_ identifier: String) -> Bool { factories[identifier] != nil }

    /// 移除指定注册映射；不会自动关闭已经展示的页面或撤销服务的业务副作用。
    public func unregister(identifier: String) {
        factories.removeValue(forKey: identifier)
    }

    /// 已登记的页面工厂标识，排序后用于诊断。
    public var registeredDestinationIDs: [String] { factories.keys.sorted() }

    /// 保存注册表快照；同步闭包抛错时恢复映射。不会回滚外部对象内部的业务状态。
    public func performRegistrationTransaction<Result>(
        _ operation: @MainActor () throws -> Result
    ) rethrows -> Result {
        let checkpoint = factories
        do {
            return try operation()
        } catch {
            factories = checkpoint
            throw error
        }
    }

    /// 用条目中的 Route 和交互上下文创建 View；构造失败不应写入导航状态。
    public func makeView(for entry: TFYSwiftSwiftUINavigationEntry) throws -> AnyView {
        guard let factory = factories[entry.destination.identifier] else {
            throw TFYSwiftRouteError.destinationNotRegistered(entry.destination.identifier)
        }
        return try factory(
            entry.route,
            TFYSwiftDestinationContext(
                routeContext: entry.transaction.context,
                presentation: entry.transaction.presentation,
                interaction: entry.interaction
            )
        )
    }
}

/// Native NavigationStack state driver for pure SwiftUI applications.
@MainActor
/// 将导航请求转换成可观察的 SwiftUI 状态。
public final class TFYSwiftSwiftUINavigationDriver: ObservableObject, TFYSwiftNavigationDriver {
    public typealias CustomPresentation = @MainActor (TFYSwiftSwiftUINavigationEntry) async throws -> Void

    /// 当前显式根路由；为空时由 RouterHost 的默认 root 闭包提供内容。
    @Published public private(set) var rootEntry: TFYSwiftSwiftUINavigationEntry?
    /// 根页之后的有序 NavigationStack 路径。
    @Published public private(set) var path: [TFYSwiftSwiftUINavigationEntry] = []
    /// 当前 Sheet 条目；设为 nil 表示请求关闭。
    @Published public private(set) var sheet: TFYSwiftSwiftUINavigationEntry?
    /// 当前全屏条目；设为 nil 表示请求关闭。
    @Published public private(set) var fullScreen: TFYSwiftSwiftUINavigationEntry?

    /// 平台页面工厂注册表。
    public let destinations: TFYSwiftSwiftUIDestinationRegistry
    private var customPresentations: [String: CustomPresentation] = [:]
    private var newWindowPresentation: CustomPresentation?

    /// 创建原生导航状态；可注入共享工厂表或使用默认空表。
    public init(destinations: TFYSwiftSwiftUIDestinationRegistry) {
        self.destinations = destinations
    }

    /// 创建原生导航状态；可注入共享工厂表或使用默认空表。
    public convenience init() {
        self.init(destinations: TFYSwiftSwiftUIDestinationRegistry())
    }

    /// 安装指定标识的自定义呈现处理器；处理器负责实际展示及生命周期管理。
    public func registerCustomPresentation(identifier: String, handler: @escaping CustomPresentation) {
        customPresentations[identifier] = handler
    }

    /// 安装由 App 提供的新窗口/Scene 处理器；核心不会自动创建 Scene。
    public func registerNewWindowPresentation(handler: @escaping CustomPresentation) {
        newWindowPresentation = handler
    }

    /// 由具体平台驱动创建并展示目标页面，工厂或呈现失败通过 throws 回传。
    public func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        guard destinations.contains(destination.identifier) else {
            throw TFYSwiftRouteError.destinationNotRegistered(destination.identifier)
        }
        var entry = TFYSwiftSwiftUINavigationEntry(
            destination: destination,
            route: route,
            transaction: transaction,
            interaction: interaction
        )
        // Build before mutating navigation state so factory errors propagate to the Router.
        entry.content = try destinations.makeView(for: entry)
        switch transaction.presentation {
        case .automatic, .push:
            path.append(entry)
        case .sheet:
            sheet?.interaction?.cancel()
            sheet = entry
        case .fullScreen:
            fullScreen?.interaction?.cancel()
            fullScreen = entry
        case .replace:
            if path.isEmpty {
                rootEntry?.interaction?.cancel()
                rootEntry = entry
            } else {
                path[path.count - 1].interaction?.cancel()
                path[path.count - 1] = entry
            }
        case .root:
            cancel(entries: path)
            rootEntry?.interaction?.cancel()
            sheet?.interaction?.cancel()
            fullScreen?.interaction?.cancel()
            rootEntry = entry
            path.removeAll()
            sheet = nil
            fullScreen = nil
        case .newWindow:
            guard let newWindowPresentation else { throw TFYSwiftRouteError.sceneUnavailable }
            try await newWindowPresentation(entry)
        case .custom(let identifier):
            guard let handler = customPresentations[identifier] else {
                throw TFYSwiftRouteError.presentationFailed("SwiftUI 自定义转场未注册：\(identifier)")
            }
            try await handler(entry)
        }
    }

    /// 判断给定地址是否为当前 Scope 的可见顶层页面。
    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        (fullScreen ?? sheet ?? path.last ?? rootEntry)?.route == route
    }

    /// 尝试激活已有地址；命中时返回 true，并按驱动语义移除其上的页面。
    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        if fullScreen?.route == route || sheet?.route == route { return true }
        if rootEntry?.route == route {
            fullScreen?.interaction?.cancel()
            sheet?.interaction?.cancel()
            cancel(entries: path)
            fullScreen = nil
            sheet = nil
            path.removeAll()
            return true
        }
        guard let index = path.lastIndex(where: { $0.route == route }) else { return false }
        fullScreen?.interaction?.cancel()
        sheet?.interaction?.cancel()
        fullScreen = nil
        sheet = nil
        let removed = Array(path.suffix(from: path.index(after: index)))
        cancel(entries: removed)
        path = Array(path.prefix(through: index))
        return true
    }

    /// 返回当前驱动追踪的地址，包含受支持的模态页面。
    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        var routes = rootEntry.map { [$0.route] } ?? []
        routes.append(contentsOf: path.map(\.route))
        if let sheet { routes.append(sheet.route) }
        if let fullScreen { routes.append(fullScreen.route) }
        return routes
    }

    /// 返回可用于恢复的 root/push 地址顺序；内置驱动排除模态和自定义呈现。
    public func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        var routes = rootEntry.map { [$0.route] } ?? []
        routes.append(contentsOf: path.map(\.route))
        return routes
    }

    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        guard !path.isEmpty else { throw TFYSwiftRouteError.presentationFailed("已位于根页面") }
        let removeCount = min(max(1, count), path.count)
        let removed = Array(path.suffix(removeCount))
        cancel(entries: removed)
        path.removeLast(removeCount)
    }

    /// 清理当前导航栈的根页之后的页面及其交互。
    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        cancel(entries: path)
        path.removeAll()
    }

    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    public func dismiss(in scope: TFYSwiftNavigationScopeID) async throws {
        if let fullScreen {
            fullScreen.interaction?.cancel()
            self.fullScreen = nil
        } else if let sheet {
            sheet.interaction?.cancel()
            self.sheet = nil
        } else {
            throw TFYSwiftRouteError.presentationFailed("没有可关闭的模态页面")
        }
    }

    /// 关闭当前 Scope 的全部模态页面及其交互。
    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        fullScreen?.interaction?.cancel()
        sheet?.interaction?.cancel()
        fullScreen = nil
        sheet = nil
    }

    /// 接收 NavigationStack 的用户回退结果，并取消已从路径中移除的交互。
    func updatePath(_ newPath: [TFYSwiftSwiftUINavigationEntry]) {
        let retainedIDs = Set(newPath.map(\.id))
        cancel(entries: path.filter { !retainedIDs.contains($0.id) })
        path = newPath
    }

    /// 同步 Sheet 关闭后的状态并取消尚未完成的交互。
    func sheetDidDismiss() {
        sheet?.interaction?.cancel()
        sheet = nil
    }

    /// 同步全屏弹层关闭后的状态并取消尚未完成的交互。
    func fullScreenDidDismiss() {
        fullScreen?.interaction?.cancel()
        fullScreen = nil
    }

    private func cancel(entries: [TFYSwiftSwiftUINavigationEntry]) {
        entries.forEach { $0.interaction?.cancel() }
    }
}

/// 将驱动状态双向绑定到 NavigationStack、sheet 和 fullScreenCover。
public struct TFYSwiftSwiftUIRouterHost<Root: View>: View {
    /// 错误展示由 App 注入，组件不绑定图标、主题、文案或资源包。
    public typealias ErrorContent = @MainActor (Error) -> AnyView
    @ObservedObject private var driver: TFYSwiftSwiftUINavigationDriver
    private let root: () -> Root
    private let errorContent: ErrorContent

    /// 连接可观察驱动，并指定尚未安装 rootEntry 时显示的默认根 View。
    public init(
        driver: TFYSwiftSwiftUINavigationDriver,
        errorContent: @escaping ErrorContent = { _ in AnyView(EmptyView()) },
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.driver = driver
        self.root = root
        self.errorContent = errorContent
    }

    /// 根据驱动状态生成可交互的 SwiftUI 页面。
    public var body: some View {
        NavigationStack(path: Binding(
            get: { driver.path },
            set: { driver.updatePath($0) }
        )) {
            Group {
                if let entry = driver.rootEntry { destination(entry) } else { AnyView(root()) }
            }
            .navigationDestination(for: TFYSwiftSwiftUINavigationEntry.self) { destination($0) }
        }
        .sheet(
            item: Binding(get: { driver.sheet }, set: { if $0 == nil { driver.sheetDidDismiss() } }),
            onDismiss: { driver.sheetDidDismiss() }
        ) { entry in
            configuredSheet(destination(entry), entry: entry)
        }
        .fullScreenCover(
            item: Binding(get: { driver.fullScreen }, set: { if $0 == nil { driver.fullScreenDidDismiss() } }),
            onDismiss: { driver.fullScreenDidDismiss() }
        ) { entry in
            destination(entry)
        }
    }

    private func destination(_ entry: TFYSwiftSwiftUINavigationEntry) -> AnyView {
        if let content = entry.content { return content }
        do { return try driver.destinations.makeView(for: entry) }
        catch { return errorContent(error) }
    }

    @ViewBuilder
    private func configuredSheet(_ content: AnyView, entry: TFYSwiftSwiftUINavigationEntry) -> some View {
        if case .sheet(let configuration) = entry.transaction.presentation {
            content
                .presentationDetents(Set(configuration.detents.map { $0 == .medium ? .medium : .large }))
                .presentationDragIndicator(configuration.prefersGrabberVisible ? .visible : .hidden)
                .interactiveDismissDisabled(!configuration.allowsInteractiveDismiss)
        } else {
            content
        }
    }
}

#endif

import Combine
import SwiftUI
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

@MainActor
public struct TFYSwiftSwiftUINavigationEntry: Identifiable, Hashable {
    public nonisolated let id: UUID
    public let destination: TFYSwiftDestinationDescriptor
    public let route: TFYSwiftAnyRoute
    public let transaction: TFYSwiftRouteTransaction
    public let interaction: TFYSwiftRouteInteraction?
    public var result: TFYSwiftRouteResult? { interaction?.result }

    public init(
        id: UUID = UUID(),
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) {
        self.id = id
        self.destination = destination
        self.route = route
        self.transaction = transaction
        self.interaction = interaction
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
public final class TFYSwiftSwiftUIDestinationRegistry {
    public typealias Factory = @MainActor (TFYSwiftAnyRoute, TFYSwiftDestinationContext) throws -> AnyView
    private var factories: [String: Factory] = [:]

    public init() {}

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

    public func contains(_ identifier: String) -> Bool { factories[identifier] != nil }

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
public final class TFYSwiftSwiftUINavigationDriver: ObservableObject, TFYSwiftNavigationDriver {
    public typealias CustomPresentation = @MainActor (TFYSwiftSwiftUINavigationEntry) async throws -> Void

    @Published public private(set) var rootEntry: TFYSwiftSwiftUINavigationEntry?
    @Published public private(set) var path: [TFYSwiftSwiftUINavigationEntry] = []
    @Published public private(set) var sheet: TFYSwiftSwiftUINavigationEntry?
    @Published public private(set) var fullScreen: TFYSwiftSwiftUINavigationEntry?

    public let destinations: TFYSwiftSwiftUIDestinationRegistry
    private var customPresentations: [String: CustomPresentation] = [:]
    private var newWindowPresentation: CustomPresentation?

    public init(destinations: TFYSwiftSwiftUIDestinationRegistry) {
        self.destinations = destinations
    }

    public convenience init() {
        self.init(destinations: TFYSwiftSwiftUIDestinationRegistry())
    }

    public func registerCustomPresentation(identifier: String, handler: @escaping CustomPresentation) {
        customPresentations[identifier] = handler
    }

    public func registerNewWindowPresentation(handler: @escaping CustomPresentation) {
        newWindowPresentation = handler
    }

    public func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws {
        guard destinations.contains(destination.identifier) else {
            throw TFYSwiftRouteError.destinationNotRegistered(destination.identifier)
        }
        let entry = TFYSwiftSwiftUINavigationEntry(
            destination: destination,
            route: route,
            transaction: transaction,
            interaction: interaction
        )
        switch transaction.presentation {
        case .automatic, .push:
            path.append(entry)
        case .sheet:
            sheet = entry
        case .fullScreen:
            fullScreen = entry
        case .replace:
            if path.isEmpty { rootEntry = entry } else { path[path.count - 1] = entry }
        case .root:
            cancel(entries: path)
            rootEntry?.interaction?.cancel()
            rootEntry = entry
            path.removeAll()
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

    public func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool {
        (fullScreen ?? sheet ?? path.last ?? rootEntry)?.route == route
    }

    public func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool {
        guard let index = path.lastIndex(where: { $0.route == route }) else { return false }
        let removed = Array(path.suffix(from: path.index(after: index)))
        cancel(entries: removed)
        path = Array(path.prefix(through: index))
        return true
    }

    public func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        var routes = rootEntry.map { [$0.route] } ?? []
        routes.append(contentsOf: path.map(\.route))
        if let sheet { routes.append(sheet.route) }
        if let fullScreen { routes.append(fullScreen.route) }
        return routes
    }

    public func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws {
        guard !path.isEmpty else { throw TFYSwiftRouteError.presentationFailed("已位于根页面") }
        let removeCount = min(max(1, count), path.count)
        let removed = Array(path.suffix(removeCount))
        cancel(entries: removed)
        path.removeLast(removeCount)
    }

    public func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws {
        cancel(entries: path)
        path.removeAll()
    }

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

    public func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws {
        fullScreen?.interaction?.cancel()
        sheet?.interaction?.cancel()
        fullScreen = nil
        sheet = nil
    }

    func updatePath(_ newPath: [TFYSwiftSwiftUINavigationEntry]) {
        let retainedIDs = Set(newPath.map(\.id))
        cancel(entries: path.filter { !retainedIDs.contains($0.id) })
        path = newPath
    }

    func sheetDidDismiss() {
        sheet?.interaction?.cancel()
        sheet = nil
    }

    func fullScreenDidDismiss() {
        fullScreen?.interaction?.cancel()
        fullScreen = nil
    }

    private func cancel(entries: [TFYSwiftSwiftUINavigationEntry]) {
        entries.forEach { $0.interaction?.cancel() }
    }
}

public struct TFYSwiftSwiftUIRouterHost<Root: View>: View {
    @ObservedObject private var driver: TFYSwiftSwiftUINavigationDriver
    private let root: () -> Root

    public init(
        driver: TFYSwiftSwiftUINavigationDriver,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.driver = driver
        self.root = root
    }

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
        do { return try driver.destinations.makeView(for: entry) }
        catch { return AnyView(TFYSwiftSwiftUIRouteErrorView(error: error)) }
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

private struct TFYSwiftSwiftUIRouteErrorView: View {
    let error: Error
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("页面创建失败").font(.headline)
            Text(error.localizedDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

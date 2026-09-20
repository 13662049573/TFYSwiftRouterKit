// TFYSwiftRestoration.swift
// 显式地址编解码与导航恢复。默认支持 Codable/JSON，也允许 App 注入自己的格式与稳定标识。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// 持久化的地址记录：稳定类型标识与 JSON 编码的载荷。
public struct TFYSwiftRestorableRouteDescriptor: Codable, Hashable, Sendable {
    /// 稳定的注册标识；在对应注册表内必须唯一。
    public let identifier: String
    /// 由已登记编码器生成的数据；默认是 JSON，也可以是 App 自定义格式。
    public let payload: Data

    /// 封装稳定恢复标识和载荷数据；有效性在解码时检查。
    public init(identifier: String, payload: Data) {
        self.identifier = identifier
        self.payload = payload
    }
}

/// 某个 Scope 的有序 root/push 地址列表，不包含弹层。
public struct TFYSwiftNavigationScopeSnapshot: Codable, Hashable, Sendable {
    /// 本次导航操作所属的容器作用域。
    public let scope: TFYSwiftNavigationScopeID
    /// 按导航顺序保存的可恢复地址描述符。
    public let routes: [TFYSwiftRestorableRouteDescriptor]

    /// 保存单个容器的有序可恢复地址。
    public init(scope: TFYSwiftNavigationScopeID, routes: [TFYSwiftRestorableRouteDescriptor]) {
        self.scope = scope
        self.routes = routes
    }
}

/// 带版本和时间的多 Scope 快照；存储介质由 App 决定。
public struct TFYSwiftNavigationSnapshot: Codable, Hashable, Sendable {
    /// 快照结构版本；版本变更需配套登记迁移。
    public let schemaVersion: Int
    /// 快照采集时间，可供 App 判断是否过期。
    public let createdAt: Date
    /// 每个导航容器的快照集合。
    public let scopes: [TFYSwiftNavigationScopeSnapshot]

    /// 创建带结构版本、生成时间及多 Scope 内容的快照。
    public init(schemaVersion: Int = 1, createdAt: Date = Date(), scopes: [TFYSwiftNavigationScopeSnapshot]) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.scopes = scopes
    }
}

@MainActor
/// 显式登记可恢复 Route 的编码器与解码器，不会自动持久化任意类型。
public final class TFYSwiftRestorationRegistry {
    private struct EncoderEntry {
        let identifier: String
        let encode: (TFYSwiftAnyRoute) throws -> Data
    }

    private var encoders: [ObjectIdentifier: EncoderEntry] = [:]
    private var decoders: [String: (Data) throws -> TFYSwiftAnyRoute] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// 创建空编解码表，并可配置默认 JSON 日期、键等策略；仅恢复显式登记的地址。
    public init(encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.encoder = encoder
        self.decoder = decoder
    }

    /// 显式登记 Codable Route 和稳定恢复标识；类型与标识均不可重复。
    public func register<R: TFYSwiftRoute & Codable>(
        _ routeType: R.Type,
        identifier: String
    ) throws {
        try register(routeType, identifier: identifier, encode: { [encoder] route in
            try encoder.encode(route)
        }, decode: { [decoder] data in
            try decoder.decode(routeType, from: data)
        })
    }

    /// 注入地址编解码策略，可使用自定义格式；组件不要求业务 Route 必须采用 JSON/Codable。
    /// identifier 由 App 决定并保持稳定；闭包运行在 MainActor，必须成对匹配。
    public func register<R: TFYSwiftRoute>(
        _ routeType: R.Type,
        identifier: String,
        encode: @escaping @MainActor (R) throws -> Data,
        decode: @escaping @MainActor (Data) throws -> R
    ) throws {
        guard encoders[ObjectIdentifier(routeType)] == nil else {
            throw TFYSwiftRouteError.duplicateRegistration(String(reflecting: routeType))
        }
        guard decoders[identifier] == nil else {
            throw TFYSwiftRouteError.duplicateRegistration(identifier)
        }
        encoders[ObjectIdentifier(routeType)] = EncoderEntry(identifier: identifier) { anyRoute in
            guard let route = anyRoute.cast(to: routeType) else {
                throw TFYSwiftRouteError.restorationFailed("Route 类型不匹配")
            }
            return try encode(route)
        }
        decoders[identifier] = { data in
            TFYSwiftAnyRoute(try decode(data))
        }
    }

    /// 为已登记的 Route 生成持久化描述符；未登记时返回 nil。
    public func descriptor(for route: TFYSwiftAnyRoute) throws -> TFYSwiftRestorableRouteDescriptor? {
        guard let entry = encoders[route.typeID] else { return nil }
        return TFYSwiftRestorableRouteDescriptor(
            identifier: entry.identifier,
            payload: try entry.encode(route)
        )
    }

    /// 将请求/持久化描述符解码成地址；无法匹配或数据非法时抛错。
    public func route(from descriptor: TFYSwiftRestorableRouteDescriptor) throws -> TFYSwiftAnyRoute {
        guard let decode = decoders[descriptor.identifier] else {
            throw TFYSwiftRouteError.restorationFailed("未知的恢复标识：\(descriptor.identifier)")
        }
        return try decode(descriptor.payload)
    }

    /// 移除指定注册映射；不会自动关闭已经展示的页面或撤销服务的业务副作用。
    public func unregister<R: TFYSwiftRoute>(_ routeType: R.Type) {
        guard let entry = encoders.removeValue(forKey: ObjectIdentifier(routeType)) else { return }
        decoders.removeValue(forKey: entry.identifier)
    }

    /// 已登记的持久化标识，排序后用于诊断。
    public var registeredIdentifiers: [String] { decoders.keys.sorted() }
}

/// 生成快照时，对未登记恢复编码器的地址选择跳过或报错。
public enum TFYSwiftUnrestorableRoutePolicy: Sendable {
    /// Omit routes that were not explicitly registered for restoration.
    case skip
    /// Fail snapshot creation when any route is not restorable.
    case fail
}

/// Creates versioned navigation snapshots and replays them through the normal Router pipeline.
/// The full snapshot is decoded and validated before any navigation state is mutated.
@MainActor
/// 负责快照生成、版本迁移、完整解码和逐页恢复；运行期失败通过 Driver 检查点原子回滚。
public final class TFYSwiftRestorationCoordinator {
    public typealias Migration = @MainActor @Sendable (
        TFYSwiftNavigationSnapshot
    ) throws -> TFYSwiftNavigationSnapshot

    /// 地址解析或恢复编码注册表，由当前流程持有。
    public let registry: TFYSwiftRestorationRegistry
    /// 完成组装的核心路由器，供业务层通过协议使用。
    public let router: TFYSwiftRouter
    /// 当前允许恢复到的版本，至少为 1。
    public let currentSchemaVersion: Int
    private var migrations: [Int: Migration] = [:]

    /// 注入编码注册表与 Router；当前版本会归一化为至少 1。
    public init(
        registry: TFYSwiftRestorationRegistry,
        router: TFYSwiftRouter,
        currentSchemaVersion: Int = 1
    ) {
        self.registry = registry
        self.router = router
        self.currentSchemaVersion = max(1, currentSchemaVersion)
    }

    /// Registers a migration whose result must advance `schemaVersion`.
    /// 登记从某个版本开始的迁移；输出版本必须前进且不超过当前支持版本。
    public func registerMigration(fromVersion: Int, migration: @escaping Migration) throws {
        guard migrations[fromVersion] == nil else {
            throw TFYSwiftRouteError.duplicateRegistration("restoration migration v\(fromVersion)")
        }
        migrations[fromVersion] = migration
    }

    /// 从指定 Scope 采集导航地址；重复 Scope 自动去重，未登记地址按策略处理。
    public func makeSnapshot(
        scopes: [TFYSwiftNavigationScopeID],
        unrestorableRoutePolicy: TFYSwiftUnrestorableRoutePolicy = .fail
    ) throws -> TFYSwiftNavigationSnapshot {
        let uniqueScopes = Array(Set(scopes)).sorted { $0.rawValue < $1.rawValue }
        let scopeSnapshots = try uniqueScopes.map { scope in
            let descriptors = try router.navigationRoutes(scope: scope).compactMap { route in
                if let descriptor = try registry.descriptor(for: route) { return descriptor }
                switch unrestorableRoutePolicy {
                case .skip: return nil
                case .fail:
                    throw TFYSwiftRouteError.restorationFailed("Route 未注册恢复编码：\(route.typeName)")
                }
            }
            return TFYSwiftNavigationScopeSnapshot(scope: scope, routes: descriptors)
        }
        return TFYSwiftNavigationSnapshot(
            schemaVersion: currentSchemaVersion,
            scopes: scopeSnapshots
        )
    }

    /// 先迁移并解码完整快照，再按 Scope 依次 root/push；空列表不修改现有导航栈。
    public func restore(_ sourceSnapshot: TFYSwiftNavigationSnapshot) async throws {
        let snapshot = try migrate(sourceSnapshot)
        let duplicateScope = Dictionary(grouping: snapshot.scopes, by: \.scope)
            .first { $0.value.count > 1 }?.key
        if let duplicateScope {
            throw TFYSwiftRouteError.restorationFailed("快照包含重复 Scope：\(duplicateScope.rawValue)")
        }

        // Decode everything first so corrupt payloads never produce a partially restored stack.
        let plan = try snapshot.scopes.map { scopeSnapshot in
            (scopeSnapshot.scope, try scopeSnapshot.routes.map(registry.route(from:)))
        }

        if let scopedDriver = router.driver as? TFYSwiftScopedNavigationDriver,
           let scope = plan.first(where: { !scopedDriver.contains($0.0) })?.0 {
            throw TFYSwiftRouteError.restorationFailed("Scope 未注册：\(scope.rawValue)")
        }
        let registeredRouteNames = Set(router.registry.registeredRouteNames)
        if let route = plan.lazy.flatMap({ $0.1 }).first(where: {
            !registeredRouteNames.contains($0.typeName)
        }) {
            throw TFYSwiftRouteError.restorationFailed("Route 未注册：\(route.typeName)")
        }

        let affectedPlan = plan.filter { !$0.1.isEmpty }
        guard !affectedPlan.isEmpty else { return }
        guard let checkpointing = router.driver as? any TFYSwiftNavigationCheckpointing else {
            throw TFYSwiftRouteError.restorationFailed("导航驱动不支持原子恢复")
        }
        var checkpoints: [any TFYSwiftNavigationCheckpoint] = []
        do {
            for (scope, _) in affectedPlan {
                checkpoints.append(try checkpointing.makeNavigationCheckpoint(in: scope))
            }
            try await apply(affectedPlan)
            checkpoints.forEach { $0.commit() }
        } catch {
            checkpoints.reversed().forEach { $0.rollback() }
            throw error
        }
    }

    private func apply(_ plan: [(TFYSwiftNavigationScopeID, [TFYSwiftAnyRoute])]) async throws {
        for (scope, routes) in plan {
            for (index, route) in routes.enumerated() {
                do {
                    try await router.open(
                        route,
                        presentation: index == 0 ? .root(animated: false) : .push(animated: false),
                        source: .restoration,
                        scope: scope,
                        deduplication: .none
                    )
                } catch {
                    throw TFYSwiftRouteError.restorationFailed(
                        "Scope \(scope.rawValue) 第 \(index + 1) 个页面恢复失败：\(error.localizedDescription)"
                    )
                }
            }
        }
    }

    private func migrate(_ source: TFYSwiftNavigationSnapshot) throws -> TFYSwiftNavigationSnapshot {
        guard source.schemaVersion <= currentSchemaVersion else {
            throw TFYSwiftRouteError.restorationFailed(
                "快照版本 \(source.schemaVersion) 高于当前支持版本 \(currentSchemaVersion)"
            )
        }
        var snapshot = source
        while snapshot.schemaVersion < currentSchemaVersion {
            guard let migration = migrations[snapshot.schemaVersion] else {
                throw TFYSwiftRouteError.restorationFailed(
                    "缺少从 v\(snapshot.schemaVersion) 开始的迁移"
                )
            }
            let previousVersion = snapshot.schemaVersion
            snapshot = try migration(snapshot)
            guard snapshot.schemaVersion > previousVersion,
                  snapshot.schemaVersion <= currentSchemaVersion else {
                throw TFYSwiftRouteError.restorationFailed("迁移没有产生有效的后续版本")
            }
        }
        return snapshot
    }
}

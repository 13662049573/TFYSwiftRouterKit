// TFYSwiftRoute.swift
// 路由地址与上下文。地址只存标识和小型值，页面、服务及完整业务模型通过其他边界传递。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// A strongly typed navigation intent. Routes contain identifiers and small values, never views.
/// 强类型导航意图；Hashable 决定去重，Sendable 保证地址可跨并发边界传递。
public protocol TFYSwiftRoute: Hashable, Sendable {}

/// Safe type erasure used only at the router runtime boundary.
/// 内部类型擦除容器；只接受遵守 Sendable 的 Route，不向业务暴露页面对象。
public struct TFYSwiftAnyRoute: Hashable, @unchecked Sendable, CustomStringConvertible {
    /// 原始类型的运行期身份，仅用于进程内索引，不可用于持久化。
    public let typeID: ObjectIdentifier
    /// 原始类型名称，用于诊断和类型不匹配提示。
    public let typeName: String
    private let storage: AnyHashable

    /// 以原始 Route 建立只读类型擦除容器；泛型约束保证底层地址满足 Sendable。
    public init<R: TFYSwiftRoute>(_ route: R) {
        typeID = ObjectIdentifier(R.self)
        typeName = String(reflecting: R.self)
        storage = AnyHashable(route)
    }

    /// 尝试还原原始 Route 类型；类型不匹配时返回 nil。
    public func cast<R: TFYSwiftRoute>(to type: R.Type = R.self) -> R? {
        storage.base as? R
    }

    public var description: String { String(describing: storage.base) }
}

/// 导航容器的稳定标识；字符串字面量可直接创建，默认作用域为 main。
public struct TFYSwiftNavigationScopeID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    /// 作用域原始字符串；多个容器应使用不同且稳定的值。
    public let rawValue: String

    /// 从字符串创建稳定 Scope 标识；调用方负责在不同导航容器之间保持唯一。
    public init(_ rawValue: String) { self.rawValue = rawValue }
    /// 从字符串创建稳定 Scope 标识；调用方负责在不同导航容器之间保持唯一。
    public init(stringLiteral value: String) { rawValue = value }

    /// 未指定 Scope 时使用的默认导航作用域。
    public static let main: Self = "main"
}

/// 本次请求的来源，用于拦截判断与业务追踪。
public enum TFYSwiftRouteSource: String, Codable, Sendable {
    case userInteraction
    case deepLink
    case universalLink
    case pushNotification
    case restoration
    case programmatic
}

/// 附加追踪信息；不参与地址本身的相等性判断，不宜放入敏感业务数据。
public struct TFYSwiftRouteMetadata: Hashable, Codable, Sendable {
    /// 业务附加字符串信息；建议只放非敏感追踪字段。
    public var values: [String: String]
    /// 可选链路标识，便于关联同一次业务流程的请求。
    public var traceID: String?

    /// 创建轻量追踪元数据；默认没有附加字段与 traceID。
    public init(values: [String: String] = [:], traceID: String? = nil) {
        self.values = values
        self.traceID = traceID
    }

    public static let empty = TFYSwiftRouteMetadata()
}

/// 创建事务时固定的请求上下文；重定向后仍保留来源、Scope 和时间。
public struct TFYSwiftRouteContext: Hashable, Sendable {
    /// 当前值的唯一身份；用于关联记录或区分重复地址的页面实例。
    public let id: UUID
    /// 请求来源，供拦截器和业务判断使用。
    public let source: TFYSwiftRouteSource
    /// 本次导航操作所属的容器作用域。
    public let scope: TFYSwiftNavigationScopeID
    /// 本次请求携带的业务追踪信息。
    public let metadata: TFYSwiftRouteMetadata
    /// 记录创建时间，用于计算相对耗时。
    public let timestamp: Date

    /// 创建请求上下文；默认用户触发、main Scope 和当前时间。
    public init(
        id: UUID = UUID(),
        source: TFYSwiftRouteSource = .userInteraction,
        scope: TFYSwiftNavigationScopeID = .main,
        metadata: TFYSwiftRouteMetadata = .empty,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.scope = scope
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// TFYSwiftObservability.swift
// 路由事件与有界历史。事件中心弱持有观察者，业务侧必须持有自己的 History 或日志观察者。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// 路由生命周期事件名；deduplicated 表示复用了已有页面或忽略重复请求。
public enum TFYSwiftRouteEventName: String, Codable, Sendable {
    case created
    case interceptStarted
    case suspended
    case resumed
    case redirected
    case deduplicated
    case resolved
    case presentStarted
    case presented
    case completed
    case cancelled
    case failed
}

/// 单条事件记录，包含事务 ID、请求上下文、呈现策略、目标标识、耗时和可选说明。
public struct TFYSwiftRouteEvent: Identifiable, Sendable {
    /// 当前值的唯一身份；用于关联记录或区分重复地址的页面实例。
    public let id: UUID
    /// 关联当前结果或事件的路由事务标识。
    public let transactionID: UUID
    /// 事件名称，对应路由生命周期中的一个节点。
    public let name: TFYSwiftRouteEventName
    /// 地址类型名，用于展示诊断信息。
    public let routeName: String
    /// 本次导航操作所属的容器作用域。
    public let scope: TFYSwiftNavigationScopeID
    /// 请求来源，用于区分用户操作、Deep Link、恢复等入口。
    public let source: TFYSwiftRouteSource
    /// 调用方提供的链路标识；不记录 metadata 中可能包含的业务值。
    public let traceID: String?
    /// 本次事务采用的页面呈现策略。
    public let presentation: TFYSwiftRoutePresentation
    /// 本次事务采用的地址去重策略。
    public let deduplication: TFYSwiftRouteDeduplicationPolicy
    /// Resolver 成功后得到的稳定页面工厂标识。
    public let destinationID: String?
    /// 失败或取消时的稳定机器可读错误码。
    public let errorCode: String?
    /// 记录创建时间，用于计算相对耗时。
    public let timestamp: Date
    /// 从请求上下文创建到当前事件的耗时，单位为毫秒。
    public let elapsedMilliseconds: Double
    /// 可选的补充说明或错误原因。
    public let message: String?

    /// 创建事件记录；耗时由 Router 从请求上下文时间计算后传入。
    public init(
        id: UUID = UUID(),
        transactionID: UUID,
        name: TFYSwiftRouteEventName,
        routeName: String,
        scope: TFYSwiftNavigationScopeID,
        timestamp: Date = Date(),
        elapsedMilliseconds: Double,
        message: String? = nil
    ) {
        self.init(
            id: id,
            transactionID: transactionID,
            name: name,
            routeName: routeName,
            scope: scope,
            source: .userInteraction,
            traceID: nil,
            presentation: .automatic,
            deduplication: .none,
            destinationID: nil,
            errorCode: nil,
            timestamp: timestamp,
            elapsedMilliseconds: elapsedMilliseconds,
            message: message
        )
    }

    /// 创建包含完整结构化上下文的事件记录；metadata 业务值不会进入诊断事件。
    public init(
        id: UUID = UUID(),
        transactionID: UUID,
        name: TFYSwiftRouteEventName,
        routeName: String,
        scope: TFYSwiftNavigationScopeID,
        source: TFYSwiftRouteSource,
        traceID: String?,
        presentation: TFYSwiftRoutePresentation,
        deduplication: TFYSwiftRouteDeduplicationPolicy,
        destinationID: String?,
        errorCode: String?,
        timestamp: Date = Date(),
        elapsedMilliseconds: Double,
        message: String? = nil
    ) {
        self.id = id
        self.transactionID = transactionID
        self.name = name
        self.routeName = routeName
        self.scope = scope
        self.source = source
        self.traceID = traceID
        self.presentation = presentation
        self.deduplication = deduplication
        self.destinationID = destinationID
        self.errorCode = errorCode
        self.timestamp = timestamp
        self.elapsedMilliseconds = elapsedMilliseconds
        self.message = message
    }
}

@MainActor
/// 事件订阅接口；回调在 MainActor 执行。
public protocol TFYSwiftRouteObserver: AnyObject {
    /// 接收路由事件；History 会限制缓存长度并通知 onChange。
    func routerDidEmit(_ event: TFYSwiftRouteEvent)
}

@MainActor
/// 弱引用观察者集合，避免 Router 反向延长页面或日志对象生命周期。
public final class TFYSwiftRouteEventCenter {
    private final class WeakObserver {
        weak var value: (any TFYSwiftRouteObserver)?
        init(_ value: any TFYSwiftRouteObserver) { self.value = value }
    }

    private var observers: [WeakObserver] = []

    /// 创建事件中心；观察者以弱引用保存。
    public init() {}

    /// 登记观察者或流水线处理器；同一实例/标识不会重复加入。
    public func add(_ observer: any TFYSwiftRouteObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
        observers.append(WeakObserver(observer))
    }

    /// 移除指定观察者或处理器；后续请求不再调用它。
    public func remove(_ observer: any TFYSwiftRouteObserver) {
        observers.removeAll { $0.value == nil || $0.value === observer }
    }

    /// 发送事件给当前仍存活的观察者。
    public func emit(_ event: TFYSwiftRouteEvent) {
        observers.removeAll { $0.value == nil }
        observers.forEach { $0.value?.routerDidEmit(event) }
    }
}

@MainActor
/// 有容量限制的事件缓冲区，可作为 Inspector 的数据源。
public final class TFYSwiftRouteHistory: TFYSwiftRouteObserver {
    /// 事件中心、历史记录或会话事件流；具体语义由所属类型决定。
    public private(set) var events: [TFYSwiftRouteEvent] = []
    /// 最多保留的事件条数；设置时应使用正数。
    public var capacity: Int
    /// 历史更新/清空后的主线程回调，可用于刷新 Inspector。
    public var onChange: (() -> Void)?

    /// 创建有界事件历史；初始容量会归一化为至少 1。
    public init(capacity: Int = 200) { self.capacity = max(1, capacity) }

    /// 接收路由事件；History 会限制缓存长度并通知 onChange。
    public func routerDidEmit(_ event: TFYSwiftRouteEvent) {
        events.append(event)
        if events.count > capacity { events.removeFirst(events.count - capacity) }
        onChange?()
    }

    /// 清空事件记录并通知界面刷新。
    public func removeAll() {
        events.removeAll()
        onChange?()
    }
}

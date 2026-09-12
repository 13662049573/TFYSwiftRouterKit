// TFYSwiftInterceptor.swift
// 路由拦截流水线。支持放行、拒绝、重定向、挂起恢复；由 Router 限制重复执行次数。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

/// 异步挂起条件；返回 true 会重新经过拦截流水线，false 表示放弃原请求。
public struct TFYSwiftRouteSuspension: @unchecked Sendable {
    /// 挂起原因，写入事务状态与事件记录。
    public let reason: String
    private let resumeOperation: @MainActor @Sendable () async throws -> Bool

    /// 保存挂起原因与恢复闭包；闭包需确保成功、取消、失败均可结束。
    public init(
        reason: String,
        resume: @escaping @MainActor @Sendable () async throws -> Bool
    ) {
        self.reason = reason
        resumeOperation = resume
    }

    @MainActor
    /// 执行挂起恢复条件；业务操作应支持协作式取消，避免无限等待。
    public func resume() async throws -> Bool {
        try await resumeOperation()
    }
}

/// 一次拦截的决策；第一个非 proceed 的结果会结束当前流水线。
public enum TFYSwiftRouteInterceptionResult: @unchecked Sendable {
    case proceed
    case redirect(TFYSwiftAnyRoute)
    case suspend(TFYSwiftRouteSuspension)
    case reject(TFYSwiftRouteError)
}

@MainActor
/// 业务拦截器协议；identifier 用于覆盖和动态移除。
public protocol TFYSwiftRouteInterceptor: AnyObject {
    var identifier: String { get }
    /// 根据当前事务返回放行、重定向、挂起或拒绝决策。
    func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult
}

@MainActor
/// 按优先级从高到低执行的拦截器集合。
public final class TFYSwiftInterceptorPipeline {
    private struct Entry {
        let priority: Int
        let interceptor: any TFYSwiftRouteInterceptor
    }

    private var entries: [Entry] = []

    /// 创建空拦截流水线，按需添加业务处理器。
    public init() {}

    /// 登记观察者或流水线处理器；同一实例/标识不会重复加入。
    public func add(_ interceptor: any TFYSwiftRouteInterceptor, priority: Int = 0) {
        entries.removeAll { $0.interceptor.identifier == interceptor.identifier }
        entries.append(Entry(priority: priority, interceptor: interceptor))
        entries.sort { $0.priority > $1.priority }
    }

    /// 移除指定观察者或处理器；后续请求不再调用它。
    public func remove(identifier: String) {
        entries.removeAll { $0.interceptor.identifier == identifier }
    }

    /// 从高到低依次执行拦截器，遇到第一个非放行结果立即返回。
    public func run(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
        for entry in entries {
            let result = await entry.interceptor.intercept(transaction)
            if case .proceed = result { continue }
            return result
        }
        return .proceed
    }

    /// 按当前执行顺序排列的拦截器标识。
    public var identifiers: [String] { entries.map { $0.interceptor.identifier } }
}

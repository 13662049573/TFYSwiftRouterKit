// TFYSwiftNavigationDriver.swift
// 平台适配协议与一次性结果句柄。核心只描述导航操作，UIKit/SwiftUI 负责实际页面生命周期。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation

@MainActor
/// 只允许完成一次的结果句柄；完成或取消时释放内部回调捕获。
public final class TFYSwiftRouteResult {
    private enum PendingCompletion {
        case none
        case value(Any)
    }

    /// 关联当前结果或事件的路由事务标识。
    public let transactionID: UUID
    private var isFinished = false
    private var isCompletionEnabled: Bool
    private var pendingCompletion = PendingCompletion.none
    private var finishOperation: ((Any) -> Void)?
    private var cancelOperation: ((Error) -> Void)?

    init(
        transactionID: UUID,
        completionEnabled: Bool = true,
        finish: @escaping (Any) -> Void,
        cancel: @escaping (Error) -> Void
    ) {
        self.transactionID = transactionID
        isCompletionEnabled = completionEnabled
        finishOperation = finish
        cancelOperation = cancel
    }

    /// 结束当前结果或流；重复调用会被忽略。
    public func finish<Value: Sendable>(with value: Value) {
        guard !isFinished else { return }
        guard isCompletionEnabled else {
            guard case .none = pendingCompletion else { return }
            pendingCompletion = .value(value)
            return
        }
        complete(with: value)
    }

    func enableCompletion() {
        guard !isFinished, !isCompletionEnabled else { return }
        isCompletionEnabled = true
        guard case .value(let value) = pendingCompletion else { return }
        complete(with: value)
    }

    private func complete(with value: Any) {
        isFinished = true
        let operation = finishOperation
        pendingCompletion = .none
        finishOperation = nil
        cancelOperation = nil
        operation?(value)
    }

    /// 取消结果等待并按当前对象职责关闭交互资源；不等同于自动关闭 UI。
    public func cancel(_ error: Error = TFYSwiftRouteError.cancelled) {
        guard !isFinished else { return }
        isFinished = true
        let operation = cancelOperation
        pendingCompletion = .none
        finishOperation = nil
        cancelOperation = nil
        operation?(error)
    }
}

@MainActor
/// 由平台适配器实现的导航边界；核心不依赖 UIKit 或 SwiftUI。
public protocol TFYSwiftNavigationDriver: AnyObject {
    /// 由具体平台驱动创建并展示目标页面，工厂或呈现失败通过 throws 回传。
    func present(
        destination: TFYSwiftDestinationDescriptor,
        route: TFYSwiftAnyRoute,
        transaction: TFYSwiftRouteTransaction,
        interaction: TFYSwiftRouteInteraction?
    ) async throws

    /// 判断给定地址是否为当前 Scope 的可见顶层页面。
    func isTop(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) -> Bool
    /// 尝试激活已有地址；命中时返回 true，并按驱动语义移除其上的页面。
    func activate(_ route: TFYSwiftAnyRoute, in scope: TFYSwiftNavigationScopeID) async throws -> Bool
    /// 返回当前驱动追踪的地址，包含受支持的模态页面。
    func routes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute]
    /// Routes that form the restorable root/push stack. Modal/custom presentations are excluded.
    /// 返回可用于恢复的 root/push 地址顺序；内置驱动排除模态和自定义呈现。
    func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute]
    /// 回退指定层数；至少回退一层，最多回到当前容器根页。
    func back(count: Int, in scope: TFYSwiftNavigationScopeID) async throws
    /// 清理当前导航栈的根页之后的页面及其交互。
    func backToRoot(in scope: TFYSwiftNavigationScopeID) async throws
    /// 关闭当前 Scope 的顶层模态页面；没有可关闭页面时可能抛错。
    func dismiss(in scope: TFYSwiftNavigationScopeID) async throws
    /// 关闭当前 Scope 的全部模态页面及其交互。
    func dismissAll(in scope: TFYSwiftNavigationScopeID) async throws
}

@MainActor
/// 一次导航状态检查点；调用方必须且只能选择提交或回滚一次。
public protocol TFYSwiftNavigationCheckpoint: AnyObject {
    func commit()
    func rollback()
}

@MainActor
/// 支持原页面实例级回滚的导航驱动；状态恢复只接受实现此协议的驱动。
public protocol TFYSwiftNavigationCheckpointing: TFYSwiftNavigationDriver {
    func makeNavigationCheckpoint(
        in scope: TFYSwiftNavigationScopeID
    ) throws -> any TFYSwiftNavigationCheckpoint
}

public extension TFYSwiftNavigationDriver {
    /// 返回可用于恢复的 root/push 地址顺序；内置驱动排除模态和自定义呈现。
    func navigationRoutes(in scope: TFYSwiftNavigationScopeID) -> [TFYSwiftAnyRoute] {
        routes(in: scope)
    }
}

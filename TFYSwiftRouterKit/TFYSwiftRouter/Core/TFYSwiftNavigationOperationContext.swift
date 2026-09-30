import Foundation

/// Identifies the restoration currently owning navigation checkpoints.
/// Drivers may read this value to reject mutations from unrelated tasks.
public enum TFYSwiftNavigationOperationContext {
    @TaskLocal static var restorationToken: UUID?
    @TaskLocal static var heldCommitLeases: Set<UUID> = []

    public static var restorationID: UUID? { restorationToken }
}

/// Serializes only final navigation commits, never interceptors or resolvers.
@MainActor
final class TFYSwiftNavigationCommitGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private static var activeLeases: Set<UUID> = []
    private var activeLease: UUID?
    private var waiters: [Waiter] = []
    private(set) var isBusy = false

    func perform<Value: Sendable>(
        _ operation: @MainActor () async throws -> Value
    ) async throws -> Value {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        // A lease is unique to this commit, not to the gate. A child task may
        // inherit the old lease and legitimately navigate after this commit ends.
        let lease = UUID()
        activeLease = lease
        Self.activeLeases.insert(lease)
        var heldGates = TFYSwiftNavigationOperationContext.heldCommitLeases
        heldGates.insert(lease)
        return try await TFYSwiftNavigationOperationContext.$heldCommitLeases.withValue(heldGates) {
            try await operation()
        }
    }

    private func acquire() async throws {
        try Task.checkCancellation()
        if !isBusy {
            isBusy = true
            return
        }
        // Waiting on a busy gate while holding another active commit can form
        // A -> B -> A cycles across scopes/routers. Fail before enqueuing. Leases
        // inherited from already finished commits are intentionally ignored.
        guard TFYSwiftNavigationOperationContext.heldCommitLeases.isDisjoint(with: Self.activeLeases) else {
            throw TFYSwiftRouteError.presentationFailed("导航提交不能等待另一个忙碌的 Scope；请在当前呈现返回后再导航")
        }
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: TFYSwiftRouteError.cancelled)
                    return
                }
                waiters.append(Waiter(id: waiterID, continuation: continuation))
            }
        } onCancel: {
            Task { @MainActor in self.cancelWaiter(waiterID) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: TFYSwiftRouteError.cancelled)
    }

    private func release() {
        if let activeLease { Self.activeLeases.remove(activeLease) }
        activeLease = nil
        guard !waiters.isEmpty else {
            isBusy = false
            return
        }
        // Ownership transfers before resuming the next task; no unlocked gap.
        waiters.removeFirst().continuation.resume()
    }
}

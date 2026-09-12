import Foundation

public struct TFYSwiftRouteSuspension: @unchecked Sendable {
    public let reason: String
    private let resumeOperation: @MainActor @Sendable () async throws -> Bool

    public init(
        reason: String,
        resume: @escaping @MainActor @Sendable () async throws -> Bool
    ) {
        self.reason = reason
        resumeOperation = resume
    }

    @MainActor
    public func resume() async throws -> Bool {
        try await resumeOperation()
    }
}

public enum TFYSwiftRouteInterceptionResult: @unchecked Sendable {
    case proceed
    case redirect(TFYSwiftAnyRoute)
    case suspend(TFYSwiftRouteSuspension)
    case reject(TFYSwiftRouteError)
}

@MainActor
public protocol TFYSwiftRouteInterceptor: AnyObject {
    var identifier: String { get }
    func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult
}

@MainActor
public final class TFYSwiftInterceptorPipeline {
    private struct Entry {
        let priority: Int
        let interceptor: any TFYSwiftRouteInterceptor
    }

    private var entries: [Entry] = []

    public init() {}

    public func add(_ interceptor: any TFYSwiftRouteInterceptor, priority: Int = 0) {
        entries.removeAll { $0.interceptor.identifier == interceptor.identifier }
        entries.append(Entry(priority: priority, interceptor: interceptor))
        entries.sort { $0.priority > $1.priority }
    }

    public func remove(identifier: String) {
        entries.removeAll { $0.interceptor.identifier == identifier }
    }

    public func run(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
        for entry in entries {
            let result = await entry.interceptor.intercept(transaction)
            if case .proceed = result { continue }
            return result
        }
        return .proceed
    }

    public var identifiers: [String] { entries.map { $0.interceptor.identifier } }
}

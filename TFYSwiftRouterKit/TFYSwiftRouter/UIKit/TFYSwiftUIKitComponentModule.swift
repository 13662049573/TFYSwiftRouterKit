import UIKit
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// Integration boundary exported by an independently compiled UIKit component implementation.
/// The component keeps all concrete view-controller construction inside `register(in:)`.
@MainActor
public protocol TFYSwiftUIKitComponentModule {
    var rootRegistration: TFYSwiftRootRouteRegistration { get }
    func register(in assembly: TFYSwiftRouterAssembly) throws
}

public extension TFYSwiftRouterAssembly {
    /// Registers independent feature implementations and returns their opaque root addresses.
    /// Duplicate scopes are rejected before any root screen is installed.
    @discardableResult
    func registerComponents(
        _ modules: [any TFYSwiftUIKitComponentModule]
    ) throws -> [TFYSwiftRootRouteRegistration] {
        let registrations = modules.map(\.rootRegistration)
        let duplicates = Dictionary(grouping: registrations, by: \.scope)
            .first { $0.value.count > 1 }?
            .key
        if let duplicates {
            throw TFYSwiftRouteError.duplicateRegistration("root scope: \(duplicates.rawValue)")
        }
        for module in modules { try module.register(in: self) }
        return registrations
    }
}

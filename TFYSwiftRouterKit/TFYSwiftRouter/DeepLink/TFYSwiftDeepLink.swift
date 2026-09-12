import Foundation
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

public struct TFYSwiftDeepLinkRequest: Sendable {
    public let url: URL
    public let source: TFYSwiftRouteSource
    public let metadata: TFYSwiftRouteMetadata

    public init(
        url: URL,
        source: TFYSwiftRouteSource = .deepLink,
        metadata: TFYSwiftRouteMetadata = .empty
    ) {
        self.url = url
        self.source = source
        self.metadata = metadata
    }
}

public protocol TFYSwiftDeepLinkParser: Sendable {
    var identifier: String { get }
    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute?
}

public struct TFYSwiftDeepLinkPolicy: Sendable {
    public var allowedSchemes: Set<String>
    public var allowedHosts: Set<String>
    public var maximumURLLength: Int

    public init(
        allowedSchemes: Set<String>,
        allowedHosts: Set<String> = [],
        maximumURLLength: Int = 2_048
    ) {
        self.allowedSchemes = Set(allowedSchemes.map { $0.lowercased() })
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
        self.maximumURLLength = maximumURLLength
    }

    public static func app(scheme: String, universalLinkHosts: Set<String> = []) -> Self {
        Self(
            allowedSchemes: [scheme, "https"],
            allowedHosts: universalLinkHosts
        )
    }
}

public actor TFYSwiftDeepLinkEngine {
    private let policy: TFYSwiftDeepLinkPolicy
    private var parsers: [any TFYSwiftDeepLinkParser] = []

    public init(policy: TFYSwiftDeepLinkPolicy) { self.policy = policy }

    public func add(_ parser: any TFYSwiftDeepLinkParser) {
        parsers.removeAll { $0.identifier == parser.identifier }
        parsers.append(parser)
    }

    public func route(for request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute {
        try validate(request.url)
        for parser in parsers {
            if let route = try await parser.parse(request) { return route }
        }
        throw TFYSwiftRouteError.invalidDeepLink("没有 Parser 能处理该链接")
    }

    private func validate(_ url: URL) throws {
        guard url.absoluteString.count <= policy.maximumURLLength else {
            throw TFYSwiftRouteError.invalidDeepLink("URL 超过长度限制")
        }
        guard let scheme = url.scheme?.lowercased(), policy.allowedSchemes.contains(scheme) else {
            throw TFYSwiftRouteError.invalidDeepLink("Scheme 不在允许列表")
        }
        if scheme == "http" || scheme == "https" {
            guard let host = url.host?.lowercased(), policy.allowedHosts.contains(host) else {
                throw TFYSwiftRouteError.invalidDeepLink("Host 不在允许列表")
            }
        }
        guard url.user == nil, url.password == nil else {
            throw TFYSwiftRouteError.invalidDeepLink("URL 不允许携带用户凭据")
        }
    }
}

public extension TFYSwiftRouter {
    func open(
        _ request: TFYSwiftDeepLinkRequest,
        using engine: TFYSwiftDeepLinkEngine,
        presentation: TFYSwiftRoutePresentation = .automatic,
        scope: TFYSwiftNavigationScopeID = .main
    ) async throws {
        let route = try await engine.route(for: request)
        try await open(
            route,
            presentation: presentation,
            source: request.source,
            scope: scope,
            metadata: request.metadata,
            deduplication: .singleTop
        )
    }
}

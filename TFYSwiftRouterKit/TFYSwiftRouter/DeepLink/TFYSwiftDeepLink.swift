// TFYSwiftDeepLink.swift
// 外部 URL 输入适配。先验证 Scheme、Host、长度和凭据，再按优先级解析为强类型地址。
// 接入示例见 Documentation/TFYSwiftRouterKit-完整使用指南.md。

import Foundation
#if SWIFT_PACKAGE
import TFYSwiftRouterCore
#endif

/// 经过系统入口接收的 URL 请求；还未完成白名单和业务参数校验。
public struct TFYSwiftDeepLinkRequest: Sendable {
    /// 待校验和解析的外部 URL。
    public let url: URL
    /// 请求来源，供拦截器和业务判断使用。
    public let source: TFYSwiftRouteSource
    /// 本次请求携带的业务追踪信息。
    public let metadata: TFYSwiftRouteMetadata

    /// 包装原始 URL 及来源；构造本身不代表该 URL 已通过校验。
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

/// URL 到类型擦除地址的解析协议；不处理的链接返回 nil，非法参数抛错。
public protocol TFYSwiftDeepLinkParser: Sendable {
    var identifier: String { get }
    /// 解析本组件支持的 URL；不匹配返回 nil，非法业务参数抛错。
    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute?
}

/// 外部 URL 的允许范围；初始化时统一转换 Scheme/Host 为小写。
public struct TFYSwiftDeepLinkPolicy: Sendable {
    /// 允许的协议集合，比较时使用小写。
    public var allowedSchemes: Set<String>
    /// HTTP/HTTPS 允许的域名集合；自定义 Scheme 的 host 由 Parser 验证。
    public var allowedHosts: Set<String>
    /// URL 字符数上限；默认 2048。
    public var maximumURLLength: Int

    /// 创建白名单策略；初始化时小写化 Scheme/Host，并限制 URL 长度至少为 1。
    public init(
        allowedSchemes: Set<String>,
        allowedHosts: Set<String> = [],
        maximumURLLength: Int = 2_048
    ) {
        self.allowedSchemes = Set(allowedSchemes.map { $0.lowercased() })
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
        self.maximumURLLength = max(1, maximumURLLength)
    }

    /// 创建自定义 Scheme 加 HTTPS 的白名单策略；HTTPS 域名必须显式提供。
    public static func app(scheme: String, universalLinkHosts: Set<String> = []) -> Self {
        Self(
            allowedSchemes: [scheme, "https"],
            allowedHosts: universalLinkHosts
        )
    }
}

/// actor 隔离的解析引擎；只负责校验和解析，选 Tab 由 App 完成。
public actor TFYSwiftDeepLinkEngine {
    private struct Entry {
        let priority: Int
        let order: Int
        let parser: any TFYSwiftDeepLinkParser
    }

    private let policy: TFYSwiftDeepLinkPolicy
    private var parsers: [Entry] = []
    private var nextOrder = 0

    /// 创建独立解析 actor，并固定本引擎的 URL 校验策略。
    public init(policy: TFYSwiftDeepLinkPolicy) { self.policy = policy }

    /// 登记观察者或流水线处理器；同一实例/标识不会重复加入。
    public func add(_ parser: any TFYSwiftDeepLinkParser, priority: Int = 0) {
        parsers.removeAll { $0.parser.identifier == parser.identifier }
        parsers.append(Entry(priority: priority, order: nextOrder, parser: parser))
        nextOrder += 1
        parsers.sort {
            $0.priority == $1.priority ? $0.order < $1.order : $0.priority > $1.priority
        }
    }

    /// 移除指定观察者或处理器；后续请求不再调用它。
    public func remove(identifier: String) {
        parsers.removeAll { $0.parser.identifier == identifier }
    }

    /// 按当前优先级和登记顺序排列的 Parser 标识。
    public var parserIdentifiers: [String] { parsers.map { $0.parser.identifier } }

    /// 将请求/持久化描述符解码成地址；无法匹配或数据非法时抛错。
    public func route(for request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute {
        try validate(request.url)
        for entry in parsers {
            if let route = try await entry.parser.parse(request) { return route }
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
    /// 发起导航请求；带 expecting 的重载等待最终结果，其他重载在驱动接收展示后返回。
    func open(
        _ request: TFYSwiftDeepLinkRequest,
        using engine: TFYSwiftDeepLinkEngine,
        presentation: TFYSwiftRoutePresentation = .automatic,
        scope: TFYSwiftNavigationScopeID? = nil
    ) async throws {
        let route = try await engine.route(for: request)
        try await open(
            route,
            presentation: presentation,
            source: request.source,
            scope: scope ?? defaultScope,
            metadata: request.metadata,
            deduplication: .singleTop
        )
    }
}

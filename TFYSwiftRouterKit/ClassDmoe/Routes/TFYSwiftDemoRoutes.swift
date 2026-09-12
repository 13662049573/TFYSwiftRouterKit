import Foundation
import UIKit

// MARK: - Tab and Scope contracts

enum TFYSwiftDemoTab: Int, CaseIterable, Sendable {
    case home
    case products
    case cart
    case profile

    var scope: TFYSwiftNavigationScopeID {
        switch self {
        case .home: "demo.home"
        case .products: "demo.products"
        case .cart: "demo.cart"
        case .profile: "demo.profile"
        }
    }

    var title: String {
        switch self {
        case .home: "首页"
        case .products: "商品"
        case .cart: "购物车"
        case .profile: "我的"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .products: "square.grid.2x2"
        case .cart: "cart"
        case .profile: "person.crop.circle"
        }
    }
}

// MARK: - Feature Interface routes

enum TFYSwiftDemoHomeRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case architecture
    case inspector
    case laboratory
}

enum TFYSwiftDemoProductRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case detail(id: String)
    case reviews(productID: String)
}

enum TFYSwiftDemoCartRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case summary
    case checkout
    case couponPicker
}

enum TFYSwiftDemoProfileRoute: Hashable, Sendable, TFYSwiftRoute {
    case root
    case user(id: String)
    case orders
    case settings
    case themePicker
}

// MARK: - Product Interface communication contracts

/// Full models are transient route input and deliberately do not conform to Hashable/Codable.
struct TFYSwiftDemoProduct: Sendable {
    let id: String
    let name: String
    let price: Decimal
    let tags: [String]
}

enum TFYSwiftDemoProductCommand: Sendable {
    case refresh
    case updateBadge(Int)
}

enum TFYSwiftDemoProductEvent: Sendable {
    case favoriteTapped(productID: String)
    case shareTapped(productID: String)
}

struct TFYSwiftDemoProductOutput: Sendable {
    let productID: String
    let favoriteCount: Int
    let didConfirm: Bool
}

// MARK: - Cart Interface service and route models

struct TFYSwiftDemoCartLine: Sendable, Equatable {
    let productID: String
    let name: String
    let quantity: Int
}

struct TFYSwiftDemoCartSnapshot: Sendable, Equatable {
    let lines: [TFYSwiftDemoCartLine]
    var totalQuantity: Int { lines.reduce(0) { $0 + $1.quantity } }
}

struct TFYSwiftDemoCheckoutOutput: Sendable {
    let orderID: String
    let coupon: String?
}

protocol TFYSwiftDemoCartServicing: TFYSwiftComponentService {
    func add(_ product: TFYSwiftDemoProduct) async throws -> TFYSwiftDemoCartSnapshot
    func snapshot() async -> TFYSwiftDemoCartSnapshot
    func clear() async
}

enum TFYSwiftDemoComponentKeys {
    static let cart = TFYSwiftComponentServiceKey<any TFYSwiftDemoCartServicing>()
}

actor TFYSwiftDemoCartService: TFYSwiftDemoCartServicing {
    private var lines: [String: TFYSwiftDemoCartLine] = [:]

    func add(_ product: TFYSwiftDemoProduct) async throws -> TFYSwiftDemoCartSnapshot {
        let old = lines[product.id]
        lines[product.id] = TFYSwiftDemoCartLine(
            productID: product.id,
            name: product.name,
            quantity: (old?.quantity ?? 0) + 1
        )
        return makeSnapshot()
    }

    func snapshot() async -> TFYSwiftDemoCartSnapshot { makeSnapshot() }

    func clear() async { lines.removeAll() }

    private func makeSnapshot() -> TFYSwiftDemoCartSnapshot {
        TFYSwiftDemoCartSnapshot(lines: lines.values.sorted { $0.productID < $1.productID })
    }
}

// MARK: - External input boundary

struct TFYSwiftDemoDeepLinkParser: TFYSwiftDeepLinkParser {
    let identifier = "demo.deep-link-parser"

    func parse(_ request: TFYSwiftDeepLinkRequest) async throws -> TFYSwiftAnyRoute? {
        let url = request.url
        let path = url.pathComponents.filter { $0 != "/" }
        let customScheme = url.scheme?.lowercased() == "tfyswift"
        let feature = (customScheme ? url.host : path.first)?.lowercased()
        let value = customScheme ? path.first : path.dropFirst().first

        switch feature {
        case "product":
            guard let value, !value.isEmpty, value.count <= 64 else {
                throw TFYSwiftRouteError.invalidPayload("product 需要 1...64 位 ID")
            }
            return TFYSwiftAnyRoute(TFYSwiftDemoProductRoute.detail(id: value))
        case "profile":
            guard let value, !value.isEmpty, value.count <= 64 else {
                throw TFYSwiftRouteError.invalidPayload("profile 需要 1...64 位 userID")
            }
            return TFYSwiftAnyRoute(TFYSwiftDemoProfileRoute.user(id: value))
        case "cart":
            return TFYSwiftAnyRoute(TFYSwiftDemoCartRoute.summary)
        default:
            return nil
        }
    }
}

// MARK: - Cross-feature guard

@MainActor
final class TFYSwiftDemoAuthenticationInterceptor: TFYSwiftRouteInterceptor {
    let identifier = "demo.authentication"
    var isAuthenticated = false
    var presenterProvider: (@MainActor () -> UIViewController?)?

    func intercept(_ transaction: TFYSwiftRouteTransaction) async -> TFYSwiftRouteInterceptionResult {
        let needsAuthentication =
            transaction.route.cast(to: TFYSwiftDemoProfileRoute.self) == .orders ||
            transaction.route.cast(to: TFYSwiftDemoCartRoute.self) == .checkout
        guard needsAuthentication, !isAuthenticated else { return .proceed }

        return .suspend(TFYSwiftRouteSuspension(reason: "等待模拟登录") { [weak self] in
            guard let self else { return false }
            let accepted = await self.requestLogin()
            if accepted { self.isAuthenticated = true }
            return accepted
        })
    }

    private func requestLogin() async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "跨组件登录拦截",
                message: "Router 暂停原流程；登录成功后继续进入原目标页面。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in continuation.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "模拟登录", style: .default) { _ in continuation.resume(returning: true) })
            presenterProvider?()?.present(alert, animated: true)
        }
    }
}

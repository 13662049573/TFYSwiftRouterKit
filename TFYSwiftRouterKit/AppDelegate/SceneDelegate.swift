//
//  SceneDelegate.swift
//  TFYSwiftRouterKit
//
//  Created by tianfengyou on 2026/9/12.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: TFYSwiftDemoAppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let appWindow = UIWindow(windowScene: windowScene)
        window = appWindow
        do {
            let coordinator = try TFYSwiftDemoAppCoordinator()
            appCoordinator = coordinator
            appWindow.rootViewController = coordinator.tabBarController
            appWindow.makeKeyAndVisible()

            let initialURL = connectionOptions.urlContexts.first?.url
            Task { @MainActor [weak self, weak coordinator] in
                do {
                    guard let coordinator else { return }
                    try await coordinator.start()
                    if let initialURL { try await coordinator.handleExternalURL(initialURL) }
                } catch {
                    self?.showError(title: "Demo 启动失败", error: error)
                }
            }
        } catch {
            appWindow.rootViewController = TFYSwiftDemoDetailViewController(
                heading: "Demo 装配失败",
                message: error.localizedDescription,
                color: .systemRed
            )
            appWindow.makeKeyAndVisible()
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handle(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handle(url)
    }

    private func handle(_ url: URL) {
        Task { @MainActor [weak self] in
            do { try await self?.appCoordinator?.handleExternalURL(url) }
            catch { self?.showError(title: "Deep Link 失败", error: error) }
        }
    }

    @MainActor
    private func showError(title: String, error: Error) {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        window?.rootViewController?.present(alert, animated: true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

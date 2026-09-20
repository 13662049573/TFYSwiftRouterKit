//
//  SceneDelegate.swift
//  TFYSwiftRouterKit
//
//  Created by tianfengyou on 2026/9/12.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: TFYDemoAppCoordinator?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let appWindow = UIWindow(windowScene: windowScene)
        window = appWindow
        do {
            let coordinator = try TFYDemoAppCoordinator()
            appCoordinator = coordinator
            appWindow.rootViewController = coordinator.tabBarController
            appWindow.makeKeyAndVisible()

            let launchURL = connectionOptions.urlContexts.first?.url
                ?? connectionOptions.userActivities.first(where: {
                    $0.activityType == NSUserActivityTypeBrowsingWeb
                })?.webpageURL
            Task { @MainActor [weak self] in
                do {
                    try await coordinator.start()
                    if let launchURL { try await coordinator.handleExternalURL(launchURL) }
                } catch {
                    self?.showError(title: "Demo 启动失败", error: error)
                }
            }
        } catch {
            appWindow.rootViewController = makeFailureViewController(error)
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

    private func makeFailureViewController(_ error: Error) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "Demo 装配失败\n\n\(error.localizedDescription)"
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: controller.view.readableContentGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: controller.view.readableContentGuide.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
        return controller
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

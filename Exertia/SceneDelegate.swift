//
//  SceneDelegate.swift
//  Exertia
//
//  Created by satakshi on 06/11/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AudioManager.shared.resumeAfterAppForeground()
        Task {
            await SupabaseManager.shared.setUserOnline()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        AudioManager.shared.pauseForAppBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AudioManager.shared.pauseForAppBackground()
        Task {
            await SupabaseManager.shared.setUserOffline()
        }
    }
}

//
//  AppDelegate.swift
//  Exertia
//
//  Created by satakshi on 06/11/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // FORCE WAKE UP
        print("⚡️ APP LAUNCHED. WAKING UP SUPABASE...")
        _ = SupabaseManager.shared
        AudioManager.shared.configureAudioSession()
        AudioManager.shared.applySavedSettings()
        application.isIdleTimerDisabled = true

        // NOTE: Do NOT call setUserOnline here — the splash screen handles auth first.
        // Calling authenticated API here races with token refresh and can blacklist the refresh token.

        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

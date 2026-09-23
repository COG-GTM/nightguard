//
//  SceneDelegate.swift
//  nightguard
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let rootTabView = LillyRootTabView()
        let hostingController = UIHostingController(rootView: rootTabView)

        let window = UserInteractionDetectorWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        
        // The Lilly Health shell is a light UI; the legacy glucose screens opt back into dark via preferredColorScheme.
        window.overrideUserInterfaceStyle = .light
        
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()
        window.tintColor = LillyTheme.uiRed
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.window = window
            appDelegate.dimScreenOnIdle()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Scene-based apps do not reliably forward every activation through the
        // UIApplicationDelegate lifecycle, so install the grace period here too.
        (UIApplication.shared.delegate as? AppDelegate)?.applyTransientLocalAudioSuppression()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        (UIApplication.shared.delegate as? AppDelegate)?.applicationWillResignActive(UIApplication.shared)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        (UIApplication.shared.delegate as? AppDelegate)?.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.applicationDidEnterBackground(UIApplication.shared)
    }
}

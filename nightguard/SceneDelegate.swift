//
//  SceneDelegate.swift
//  nightguard
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private(set) var router: AppRouter?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let defaultWatchlistID = ProcessInfo.processInfo.environment["CAPITALIQ_DEFAULT_WATCHLIST"] ?? UserDefaultsRepository.defaultWatchlistID.value
        let router = AppRouter(store: .shared, defaultWatchlistID: defaultWatchlistID)
        self.router = router
        if let activity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
            router.handle(userActivity: activity)
        }
        connectionOptions.urlContexts.forEach { router.handle(url: $0.url) }
        
        scene.title = router.currentRoute.map { "Capital IQ Pro · \($0.title)" } ?? "Capital IQ Pro"
        windowScene.sizeRestrictions?.minimumSize = CapitalIQLayout.stageManagerMinimumSize
        
        let hostingController = CapitalIQHostingController(router: router)

        let window = UserInteractionDetectorWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        
        // Capital IQ Pro is a light UI; the legacy glucose screens are no longer the root.
        window.overrideUserInterfaceStyle = .light
        
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()
        window.tintColor = CapitalIQTheme.uiRed
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.window = window
            appDelegate.dimScreenOnIdle()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        router?.handle(userActivity: userActivity)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { router?.handle(url: $0.url) }
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        router?.currentRoute?.userActivity
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

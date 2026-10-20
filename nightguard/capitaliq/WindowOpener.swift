//
//  WindowOpener.swift
//  nightguard
//
//  Opens a route in a new iPad window (Split View / Stage Manager).
//

import UIKit

enum WindowOpener {

    static var supportsMultipleWindows: Bool {
        UIApplication.shared.supportsMultipleScenes
    }

    static func open(_ route: WatchlistRoute) {
        guard supportsMultipleWindows else { return }
        let activity = route.userActivity
        if #available(iOS 17.0, *) {
            let request = UISceneSessionActivationRequest(role: .windowApplication, userActivity: activity)
            UIApplication.shared.activateSceneSession(for: request)
        } else {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil, errorHandler: nil)
        }
    }
}

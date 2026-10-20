//
//  CapitalIQRootView.swift
//  nightguard
//
//  Adaptive S&P Capital IQ Pro shell. Compact width (iPhone, Slide Over,
//  1/3 Split View) gets the tab bar; regular width gets the three-column
//  NavigationSplitView. ⌘ shortcuts are routed through
//  CapitalIQHostingController.
//

import SwiftUI
import UIKit

struct CapitalIQRootView: View {

    @ObservedObject var router: AppRouter
    @StateObject private var store: WatchlistStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(router: AppRouter) {
        self.router = router
        _store = StateObject(wrappedValue: router.store)
        CapitalIQRootView.configureAppearance()
    }

    var body: some View {
        GeometryReader { geometry in
            let layout: CapitalIQColumnLayout = horizontalSizeClass == .compact ? .stacked : CapitalIQLayout.columnLayout(forWidth: geometry.size.width)
            Group {
                if layout == .stacked {
                    CapitalIQTabView()
                } else {
                    CapitalIQSplitView(layout: layout)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accentColor(CapitalIQTheme.red)
        .environmentObject(store)
        .environmentObject(router)
        .onAppear {
            if UIDevice.current.userInterfaceIdiom == .phone {
                AppDelegate.updateOrientationLock(.portrait, rotateTo: .portrait)
            } else {
                AppDelegate.updateOrientationLock(.all)
            }
        }
    }

    static func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor(white: 0.88, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = CapitalIQTheme.uiRed
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: CapitalIQTheme.uiRed]
        appearance.stackedLayoutAppearance.normal.iconColor = .darkGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.darkGray]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = CapitalIQTheme.uiNavy
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white
    }
}

/// Hosts the root view and exposes hardware-keyboard shortcuts
/// (⌘1 watchlists, ⌘F search, ⌘↑ / ⌘↓ switch watchlist).
final class CapitalIQHostingController: UIHostingController<CapitalIQRootView> {

    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
        super.init(rootView: CapitalIQRootView(router: router))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [
            command("1", title: "Watchlists"),
            command("f", title: "Search"),
            command(UIKeyCommand.inputUpArrow, title: "Previous Watchlist"),
            command(UIKeyCommand.inputDownArrow, title: "Next Watchlist"),
        ]
    }

    private func command(_ input: String, title: String) -> UIKeyCommand {
        let command = UIKeyCommand(title: title, action: #selector(handleKeyCommand(_:)), input: input, modifierFlags: .command)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    @objc private func handleKeyCommand(_ sender: UIKeyCommand) {
        guard let input = sender.input, let command = CapitalIQKeyCommand(key: CapitalIQHostingController.keyName(for: input), command: sender.modifierFlags.contains(.command)) else { return }
        router.handle(command)
    }

    static func keyName(for input: String) -> String {
        switch input {
        case UIKeyCommand.inputUpArrow: return "up"
        case UIKeyCommand.inputDownArrow: return "down"
        default: return input
        }
    }
}

//
//  CapitalIQRootView.swift
//  nightguard
//
//  S&P Capital IQ Pro shell: News · Markets · Search · Alerts · More.
//  The same phone tab bar is used on every device.
//

import SwiftUI
import UIKit

enum CapitalIQTab: Hashable {
    case news, markets, search, alerts, more
}

struct CapitalIQRootView: View {

    @StateObject private var store = WatchlistStore.shared
    @State private var selectedTab: CapitalIQTab = .news

    init() {
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

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView { NewsFeedView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("News", systemImage: "newspaper") }
                .tag(CapitalIQTab.news)

            NavigationView { MarketsView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Markets", systemImage: "chart.xyaxis.line") }
                .tag(CapitalIQTab.markets)

            NavigationView { SearchView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(CapitalIQTab.search)

            NavigationView { AlertsView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("Alerts", systemImage: "bell") }
                .tag(CapitalIQTab.alerts)

            NavigationView { CapitalIQMoreView() }
                .navigationViewStyle(.stack)
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(CapitalIQTab.more)
        }
        .accentColor(CapitalIQTheme.red)
        .environmentObject(store)
        .onAppear {
            AppDelegate.updateOrientationLock(.portrait, rotateTo: .portrait)
        }
    }
}

struct CapitalIQRootView_Previews: PreviewProvider {
    static var previews: some View {
        CapitalIQRootView()
    }
}

//
//  LillyRootTabView.swift
//  nightguard
//
//  Lilly Health™-style shell: Home · Logbook · Explore · Care · More.
//  The Nightscout glucose screens live behind "More" and the Blood Glucose chip.
//

import SwiftUI
import UIKit

enum LillyTab: Hashable {
    case home, logbook, explore, care, more
}

struct LillyRootTabView: View {

    @StateObject private var store = HealthLogStore.shared
    @State private var selectedTab: LillyTab = .home

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = UIColor(white: 0.9, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = LillyTheme.uiRed
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: LillyTheme.uiRed]
        appearance.stackedLayoutAppearance.normal.iconColor = .darkGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.darkGray]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = LillyTheme.uiRed
        UITabBar.appearance().unselectedItemTintColor = .darkGray
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LillyHomeView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(LillyTab.home)

            LillyLogbookView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Logbook")
                }
                .tag(LillyTab.logbook)

            LillyExploreView()
                .tabItem {
                    Image(systemName: "safari")
                    Text("Explore")
                }
                .tag(LillyTab.explore)

            LillyCareView()
                .tabItem {
                    Image(systemName: "stethoscope")
                    Text("Care")
                }
                .tag(LillyTab.care)

            LillyMoreView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("More")
                }
                .tag(LillyTab.more)
        }
        .accentColor(LillyTheme.red)
        .environmentObject(store)
        .onAppear {
            AppDelegate.updateOrientationLock(.portrait, rotateTo: .portrait)
        }
    }
}

struct LillyRootTabView_Previews: PreviewProvider {
    static var previews: some View {
        LillyRootTabView()
    }
}

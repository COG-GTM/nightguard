//
//  CapitalIQTabView.swift
//  nightguard
//
//  Compact-width root (iPhone, Slide Over, 1/3 Split View): the phone tab
//  bar with Watchlists promoted to a top-level tab.
//

import SwiftUI

struct CapitalIQTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: WatchlistStore

    private var selectedTab: Binding<CapitalIQSection> {
        Binding(
            get: { [.news, .markets, .watchlists, .search, .more].contains(router.section) ? router.section : .more },
            set: { router.section = $0 }
        )
    }

    var body: some View {
        TabView(selection: selectedTab) {
            NavigationStack { NewsFeedView() }
                .tabItem { Label("News", systemImage: "newspaper") }
                .tag(CapitalIQSection.news)

            NavigationStack { MarketsView() }
                .tabItem { Label("Markets", systemImage: "chart.xyaxis.line") }
                .tag(CapitalIQSection.markets)

            NavigationStack(path: $router.watchlistStack) {
                WatchlistIndexView()
                    .navigationDestination(for: CapitalIQStackStep.self) { step in
                        switch step {
                        case .watchlist(let id): WatchlistDetailView(watchlistID: id)
                        case .company(let ticker):
                            if let instrument = store.instrument(ticker) { CompanyProfileView(instrument: instrument) }
                        }
                    }
            }
            .tabItem { Label("Watchlists", systemImage: "list.star") }
            .tag(CapitalIQSection.watchlists)

            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(CapitalIQSection.search)

            NavigationStack { CapitalIQMoreView() }
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(CapitalIQSection.more)
        }
        .onChange(of: router.watchlistStack) { stack in
            if !stack.contains(where: { if case .company = $0 { return true } else { return false } }) {
                router.selectedTicker = nil
            }
        }
        .accessibilityIdentifier("capitaliq_tab_view")
    }
}

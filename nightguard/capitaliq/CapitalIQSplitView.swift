//
//  CapitalIQSplitView.swift
//  nightguard
//
//  Three-column root for regular width: sidebar · list · detail.
//

import SwiftUI

struct CapitalIQSplitView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: WatchlistStore
    let layout: CapitalIQColumnLayout
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if layout == .threeColumn {
                threeColumnView
            } else {
                twoColumnView
            }
        }
        .accessibilityIdentifier("capitaliq_split_view")
    }

    /// Full-screen landscape: sidebar · list · detail.
    private var threeColumnView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            NavigationStack {
                contentColumn
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 420)
        } detail: {
            NavigationStack {
                detailColumn
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { columnVisibility = .all }
    }

    /// 1/2 and 2/3 Split View (600–999pt): the sidebar stays visible and the
    /// company profile is pushed onto the content column instead of a third column.
    private var twoColumnView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack {
                contentColumn
                    .navigationDestination(isPresented: companyPresented) {
                        if let instrument = router.selectedInstrument {
                            CompanyProfileView(instrument: instrument)
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear { columnVisibility = .all }
    }

    private var sidebar: some View {
        CapitalIQSidebarView()
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }

    private var companyPresented: Binding<Bool> {
        Binding(
            get: { router.selectedInstrument != nil },
            set: { if !$0 { router.select(ticker: nil) } }
        )
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch router.section {
        case .news: NewsFeedView()
        case .markets: MarketsView()
        case .watchlists:
            if let id = router.selectedWatchlistID {
                WatchlistTableView(watchlistID: id)
            } else {
                WatchlistIndexView()
            }
        case .search: SearchView()
        case .alerts: AlertsView()
        case .more: CapitalIQMoreView()
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let instrument = router.selectedInstrument {
            CompanyProfileView(instrument: instrument)
        } else {
            VStack(spacing: 12) {
                CapitalIQWordmark(size: 22)
                Text(router.section == .watchlists ? "Select a security to open its company profile." : "Select an item to see details.")
                    .font(.system(size: 15))
                    .foregroundColor(CapitalIQTheme.inkMuted)
                if router.section == .watchlists {
                    Text("⌘↑ / ⌘↓ switch watchlists · ⌘F search · ⌘1 watchlists")
                        .font(.system(size: 12))
                        .foregroundColor(CapitalIQTheme.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CapitalIQTheme.canvas)
            .accessibilityIdentifier("detail_placeholder")
        }
    }
}

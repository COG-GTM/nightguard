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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CapitalIQSidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
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
        .onAppear { columnVisibility = layout == .threeColumn ? .all : .doubleColumn }
        .onChange(of: layout) { newValue in
            columnVisibility = newValue == .threeColumn ? .all : .doubleColumn
        }
        .accessibilityIdentifier("capitaliq_split_view")
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

//
//  WatchlistDetailView.swift
//  nightguard
//
//  Compact watchlist list: ticker, name, last price and change.
//

import SwiftUI

struct WatchlistDetailView: View {
    @EnvironmentObject private var store: WatchlistStore
    let watchlistID: String

    var body: some View {
        let watchlist = store.watchlist(id: watchlistID)
        List {
            if let watchlist {
                ForEach(store.instruments(in: watchlist)) { instrument in
                    NavigationLink(destination: CompanyProfileView(instrument: instrument)) {
                        InstrumentRow(instrument: instrument)
                    }
                }
                .onDelete { offsets in
                    let tickers = store.instruments(in: watchlist).map(\.ticker)
                    offsets.map { tickers[$0] }.forEach { store.remove(ticker: $0, from: watchlist.id) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(watchlist?.name ?? "Watchlist")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("watchlist_detail")
    }
}

struct WatchlistIndexView: View {
    @EnvironmentObject private var store: WatchlistStore

    var body: some View {
        List(store.watchlists) { watchlist in
            NavigationLink(destination: WatchlistDetailView(watchlistID: watchlist.id)) {
                HStack {
                    Image(systemName: "list.star").foregroundColor(CapitalIQTheme.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(watchlist.name).font(.system(size: 16, weight: .semibold)).foregroundColor(CapitalIQTheme.ink)
                        Text("\(watchlist.tickers.count) securities").font(.system(size: 12)).foregroundColor(CapitalIQTheme.inkMuted)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("watchlist_row_\(watchlist.id)")
        }
        .listStyle(.plain)
        .navigationTitle("Watchlists")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("watchlist_index")
    }
}

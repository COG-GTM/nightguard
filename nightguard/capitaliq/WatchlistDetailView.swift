//
//  WatchlistDetailView.swift
//  nightguard
//
//  Compact watchlist list: ticker, name, last price and change.
//

import SwiftUI

struct WatchlistDetailView: View {
    @EnvironmentObject private var store: WatchlistStore
    @EnvironmentObject private var router: AppRouter
    let watchlistID: String

    var body: some View {
        let watchlist = store.watchlist(id: watchlistID)
        List {
            if let watchlist {
                ForEach(store.instruments(in: watchlist)) { instrument in
                    Button {
                        router.select(ticker: instrument.ticker)
                    } label: {
                        HStack {
                            InstrumentRow(instrument: instrument)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                    .draggable(instrument.ticker)
                    .contextMenu {
                        if WindowOpener.supportsMultipleWindows {
                            Button {
                                WindowOpener.open(.company(ticker: instrument.ticker))
                            } label: {
                                Label("Open in New Window", systemImage: "square.split.2x1")
                            }
                        }
                        Button(role: .destructive) {
                            store.remove(ticker: instrument.ticker, from: watchlist.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .accessibilityIdentifier("watchlist_row_\(instrument.ticker)")
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
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        List(store.watchlists) { watchlist in
            Button {
                router.select(watchlistID: watchlist.id)
            } label: {
                HStack {
                    Image(systemName: "list.star").foregroundColor(CapitalIQTheme.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(watchlist.name).font(.system(size: 16, weight: .semibold)).foregroundColor(CapitalIQTheme.ink)
                        Text("\(watchlist.tickers.count) securities").font(.system(size: 12)).foregroundColor(CapitalIQTheme.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.vertical, 4)
            }
            .contextMenu {
                if WindowOpener.supportsMultipleWindows {
                    Button {
                        WindowOpener.open(.watchlist(id: watchlist.id))
                    } label: {
                        Label("Open in New Window", systemImage: "square.split.2x1")
                    }
                }
            }
            .accessibilityIdentifier("watchlist_row_\(watchlist.id)")
        }
        .listStyle(.plain)
        .navigationTitle("Watchlists")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("watchlist_index")
    }
}

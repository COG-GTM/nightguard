//
//  WatchlistStore.swift
//  nightguard
//
//  In-memory watchlist state for the Capital IQ Pro demo stand-in.
//

import Foundation
import Combine

final class WatchlistStore: ObservableObject {

    static let shared = WatchlistStore()

    @Published private(set) var watchlists: [Watchlist]
    private let instrumentsByTicker: [String: Instrument]

    init(watchlists: [Watchlist] = SampleMarketData.watchlists,
         instruments: [Instrument] = SampleMarketData.instruments) {
        self.watchlists = watchlists
        self.instrumentsByTicker = Dictionary(uniqueKeysWithValues: instruments.map { ($0.ticker, $0) })
    }

    var allInstruments: [Instrument] {
        instrumentsByTicker.values.sorted { $0.ticker < $1.ticker }
    }

    func watchlist(id: String) -> Watchlist? {
        watchlists.first { $0.id == id }
    }

    func instrument(_ ticker: String) -> Instrument? {
        instrumentsByTicker[ticker.uppercased()]
    }

    func instruments(in watchlist: Watchlist) -> [Instrument] {
        watchlist.tickers.compactMap { instrumentsByTicker[$0] }
    }

    func search(_ query: String) -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allInstruments }
        return allInstruments.filter {
            $0.ticker.lowercased().hasPrefix(trimmed) || $0.name.lowercased().contains(trimmed)
        }
    }

    @discardableResult
    func add(ticker: String, to watchlistID: String) -> Bool {
        let normalized = ticker.uppercased()
        guard instrumentsByTicker[normalized] != nil,
              let index = watchlists.firstIndex(where: { $0.id == watchlistID }),
              !watchlists[index].tickers.contains(normalized) else { return false }
        watchlists[index].tickers.append(normalized)
        return true
    }

    func remove(ticker: String, from watchlistID: String) {
        guard let index = watchlists.firstIndex(where: { $0.id == watchlistID }) else { return }
        watchlists[index].tickers.removeAll { $0 == ticker.uppercased() }
    }

    func watchlist(after id: String?) -> Watchlist? {
        guard !watchlists.isEmpty else { return nil }
        guard let id, let index = watchlists.firstIndex(where: { $0.id == id }) else { return watchlists.first }
        return watchlists[(index + 1) % watchlists.count]
    }

    func watchlist(before id: String?) -> Watchlist? {
        guard !watchlists.isEmpty else { return nil }
        guard let id, let index = watchlists.firstIndex(where: { $0.id == id }) else { return watchlists.last }
        return watchlists[(index - 1 + watchlists.count) % watchlists.count]
    }
}

//
//  WatchlistStoreTest.swift
//  nightguardTests
//

import XCTest

class WatchlistStoreTest: XCTestCase {

    func testAddIsIdempotentAndValidatesTicker() {
        let store = WatchlistStore()
        XCTAssertTrue(store.add(ticker: "aapl", to: "us-banks"))
        XCTAssertFalse(store.add(ticker: "AAPL", to: "us-banks"))
        XCTAssertFalse(store.add(ticker: "NOPE", to: "us-banks"))
        XCTAssertEqual(store.watchlist(id: "us-banks")?.tickers.last, "AAPL")
    }

    func testRemove() {
        let store = WatchlistStore()
        store.remove(ticker: "JPM", from: "us-banks")
        XCTAssertFalse(store.watchlist(id: "us-banks")!.tickers.contains("JPM"))
    }

    func testSearchMatchesTickerPrefixOrName() {
        let store = WatchlistStore()
        XCTAssertEqual(store.search("jp").map(\.ticker), ["JPM"])
        XCTAssertTrue(store.search("global").map(\.ticker).contains("SPGI"))
        XCTAssertEqual(store.search("").count, store.allInstruments.count)
    }

    func testNeighbourWatchlistsWrap() {
        let store = WatchlistStore()
        let ids = store.watchlists.map(\.id)
        XCTAssertEqual(store.watchlist(after: ids.last)?.id, ids.first)
        XCTAssertEqual(store.watchlist(before: ids.first)?.id, ids.last)
        XCTAssertEqual(store.watchlist(after: nil)?.id, ids.first)
    }
}

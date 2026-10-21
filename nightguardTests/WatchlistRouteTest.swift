//
//  WatchlistRouteTest.swift
//  nightguardTests
//

import XCTest

class WatchlistRouteTest: XCTestCase {

    func testUniversalLinkToWatchlist() {
        let route = WatchlistRoute(url: URL(string: "https://capitaliq.spglobal.com/watchlist/us-banks")!)
        XCTAssertEqual(route, .watchlist(id: "us-banks"))
    }

    func testCustomSchemeToCompanyUppercasesTicker() {
        let route = WatchlistRoute(url: URL(string: "capitaliqpro://company/jpm")!)
        XCTAssertEqual(route, .company(ticker: "JPM"))
    }

    func testWatchlistsIndexLink() {
        XCTAssertEqual(WatchlistRoute(url: URL(string: "https://capitaliq.spglobal.com/watchlists")!), .watchlists)
    }

    func testUnknownHostIsRejected() {
        XCTAssertNil(WatchlistRoute(url: URL(string: "https://example.com/watchlist/us-banks")!))
        XCTAssertNil(WatchlistRoute(url: URL(string: "https://capitaliq.spglobal.com/portfolio/1")!))
    }

    func testRouteRoundTripsThroughUserActivity() {
        let route = WatchlistRoute.watchlist(id: "energy-majors")
        let activity = route.userActivity
        XCTAssertEqual(activity.activityType, WatchlistRoute.activityType)
        XCTAssertEqual(WatchlistRoute(userActivity: activity), route)
        XCTAssertEqual(route.universalLink.absoluteString, "https://capitaliq.spglobal.com/watchlist/energy-majors")
    }

    func testBrowsingWebActivityIsHandled() {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://capitaliq.spglobal.com/company/SPGI")
        XCTAssertEqual(WatchlistRoute(userActivity: activity), .company(ticker: "SPGI"))
    }

    func testRouterNavigatesToWatchlistFromURL() {
        let router = AppRouter(store: WatchlistStore())
        XCTAssertTrue(router.handle(url: URL(string: "https://capitaliq.spglobal.com/watchlist/tech-megacaps")!))
        XCTAssertEqual(router.section, .watchlists)
        XCTAssertEqual(router.selectedWatchlistID, "tech-megacaps")
        XCTAssertEqual(router.watchlistStack, [.watchlist("tech-megacaps")])
        XCTAssertEqual(router.currentRoute, .watchlist(id: "tech-megacaps"))
    }

    func testRouterIgnoresUnknownWatchlist() {
        let router = AppRouter(store: WatchlistStore())
        router.navigate(to: .watchlist(id: "does-not-exist"))
        XCTAssertEqual(router.section, .news)
        XCTAssertNil(router.selectedWatchlistID)
    }

    func testDefaultWatchlistLandsOnWatchlistAtLaunch() {
        let router = AppRouter(store: WatchlistStore(), defaultWatchlistID: "us-banks")
        XCTAssertEqual(router.section, .watchlists)
        XCTAssertEqual(router.selectedWatchlistID, "us-banks")
    }

    func testCompanySelectionPushesOntoWatchlistStack() {
        let router = AppRouter(store: WatchlistStore(), defaultWatchlistID: "us-banks")
        router.select(ticker: "GS")
        XCTAssertEqual(router.selectedTicker, "GS")
        XCTAssertEqual(router.watchlistStack, [.watchlist("us-banks"), .company("GS")])
        XCTAssertEqual(router.currentRoute, .company(ticker: "GS"))
    }

    func testKeyCommandMapping() {
        XCTAssertEqual(CapitalIQKeyCommand(key: "1", command: true), .showWatchlists)
        XCTAssertEqual(CapitalIQKeyCommand(key: "f", command: true), .focusSearch)
        XCTAssertEqual(CapitalIQKeyCommand(key: "up", command: true), .previousWatchlist)
        XCTAssertEqual(CapitalIQKeyCommand(key: "down", command: true), .nextWatchlist)
        XCTAssertNil(CapitalIQKeyCommand(key: "1", command: false))
        XCTAssertNil(CapitalIQKeyCommand(key: "z", command: true))
    }

    func testCommandOneShowsWatchlistsAndArrowsCycle() {
        let store = WatchlistStore()
        let router = AppRouter(store: store)
        router.handle(.showWatchlists)
        XCTAssertEqual(router.section, .watchlists)
        XCTAssertEqual(router.selectedWatchlistID, store.watchlists[0].id)
        router.handle(.nextWatchlist)
        XCTAssertEqual(router.selectedWatchlistID, store.watchlists[1].id)
        router.handle(.previousWatchlist)
        XCTAssertEqual(router.selectedWatchlistID, store.watchlists[0].id)
        router.handle(.previousWatchlist)
        XCTAssertEqual(router.selectedWatchlistID, store.watchlists.last?.id)
    }

    func testCommandFSwitchesToSearchAndRequestsFocus() {
        let router = AppRouter(store: WatchlistStore(), defaultWatchlistID: "us-banks")
        router.select(ticker: "JPM")
        router.handle(.focusSearch)
        XCTAssertEqual(router.section, .search)
        XCTAssertNil(router.selectedTicker)
        XCTAssertEqual(router.searchFocusRequest, 1)
    }
}

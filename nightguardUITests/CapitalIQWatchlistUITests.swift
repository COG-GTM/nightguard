//
//  CapitalIQWatchlistUITests.swift
//  nightguardUITests
//
//  Acceptance: a watchlist is reachable in ≤ 2 taps from cold launch, and
//  regular-width iPad shows the split-view container.
//

import XCTest

class CapitalIQWatchlistUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        app.launchEnvironment["TEST"] = "1"
        environment.forEach { app.launchEnvironment[$0.key] = $0.value }
        app.launch()
        return app
    }

    /// SwiftUI maps List to collection views, Labels to cells/static texts etc., so look up
    /// accessibility identifiers independently of the element type.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Tap the hittable element carrying `identifier`; falls back to a coordinate tap when
    /// SwiftUI only exposes non-hittable children (e.g. the Label icon) under that identifier.
    private func tap(_ identifier: String, in app: XCUIApplication) {
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5), "missing element \(identifier)")
        if let hittable = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) {
            hittable.tap()
        } else {
            matches.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func testWatchlistReachableInTwoTapsOrFewer() {
        let app = launch()
        let watchlistsTab = app.tabBars.buttons["Watchlists"]
        if watchlistsTab.waitForExistence(timeout: 5) {
            // Compact width (iPhone, Slide Over, 1/3 Split View): tab bar + stacked navigation.
            watchlistsTab.tap()                                                           // tap 1
            XCTAssertTrue(element("watchlist_index", in: app).waitForExistence(timeout: 5))
            tap("watchlist_row_us-banks", in: app)                                        // tap 2
            XCTAssertTrue(element("watchlist_detail", in: app).waitForExistence(timeout: 5))
        } else {
            // Regular width (iPad): the watchlist is one tap away in the sidebar.
            XCTAssertTrue(element("capitaliq_split_view", in: app).waitForExistence(timeout: 5))
            tap("sidebar_watchlist_us-banks", in: app)                                    // tap 1
            XCTAssertTrue(element("watchlist_table", in: app).waitForExistence(timeout: 5))
        }
    }

    func testDefaultWatchlistOpensOnColdLaunch() {
        let app = launch(environment: ["CAPITALIQ_DEFAULT_WATCHLIST": "energy-majors"])
        let landed = element("watchlist_table", in: app).waitForExistence(timeout: 8)
            || element("watchlist_detail", in: app).waitForExistence(timeout: 2)
        XCTAssertTrue(landed, "cold launch should land on the default watchlist with zero taps")
        XCTAssertTrue(element("watchlist_row_XOM", in: app).waitForExistence(timeout: 5))
    }

    func testRegularWidthShowsSplitViewWithSidebarAndDetail() throws {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        guard element("capitaliq_split_view", in: app).waitForExistence(timeout: 5) else {
            throw XCTSkip("Three-column layout is an iPad (regular width) acceptance criterion")
        }
        XCTAssertTrue(element("capitaliq_sidebar", in: app).waitForExistence(timeout: 5))
        tap("sidebar_watchlist_us-banks", in: app)
        XCTAssertTrue(element("watchlist_table", in: app).waitForExistence(timeout: 5))
        tap("watchlist_row_JPM", in: app)
        XCTAssertTrue(element("company_profile_JPM", in: app).waitForExistence(timeout: 5))
    }
}

//
//  CapitalIQWatchlistUITests.swift
//  nightguardUITests
//
//  Acceptance: a watchlist is reachable in ≤ 2 taps from cold launch, and
//  regular-width iPad shows the split-view container.
//

import XCTest
import UIKit

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

    func testWatchlistReachableInTwoTapsOrFewer() {
        let app = launch()
        let watchlistsTab = app.tabBars.buttons["Watchlists"]
        if watchlistsTab.waitForExistence(timeout: 5) {
            watchlistsTab.tap()                                             // tap 1
            app.otherElements["watchlist_index"].firstMatch.waitForExistence(timeout: 5)
            app.buttons["watchlist_row_us-banks"].firstMatch.tap()           // tap 2
            XCTAssertTrue(app.otherElements["watchlist_detail"].firstMatch.waitForExistence(timeout: 5)
                          || app.tables["watchlist_detail"].firstMatch.waitForExistence(timeout: 1))
        } else {
            XCTAssertTrue(app.otherElements["capitaliq_split_view"].firstMatch.waitForExistence(timeout: 5))
            app.buttons["sidebar_watchlist_us-banks"].firstMatch.tap()      // tap 1
            XCTAssertTrue(app.otherElements["watchlist_table"].firstMatch.waitForExistence(timeout: 5))
        }
    }

    func testDefaultWatchlistOpensOnColdLaunch() {
        let app = launch(environment: ["CAPITALIQ_DEFAULT_WATCHLIST": "energy-majors"])
        let landed = app.otherElements["watchlist_table"].firstMatch.waitForExistence(timeout: 8)
            || app.otherElements["watchlist_detail"].firstMatch.waitForExistence(timeout: 1)
            || app.tables["watchlist_detail"].firstMatch.waitForExistence(timeout: 1)
        XCTAssertTrue(landed, "cold launch should land on the default watchlist with zero taps")
        XCTAssertTrue(app.staticTexts["XOM"].firstMatch.waitForExistence(timeout: 5))
    }

    func testRegularWidthShowsSplitViewWithSidebarAndDetail() throws {
        let app = launch()
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Three-column layout is an iPad-only acceptance criterion")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.otherElements["capitaliq_split_view"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["capitaliq_sidebar"].firstMatch.exists || app.tables["capitaliq_sidebar"].firstMatch.exists)
        app.buttons["sidebar_watchlist_us-banks"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["watchlist_table"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["watchlist_row_JPM"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["company_profile_JPM"].firstMatch.waitForExistence(timeout: 5))
    }
}

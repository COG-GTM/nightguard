//
//  CapitalIQLayoutTest.swift
//  nightguardTests
//

import XCTest

class CapitalIQLayoutTest: XCTestCase {

    func testSlideOverAndOneThirdSplitAreStacked() {
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 320), .stacked)   // Slide Over
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 375), .stacked)   // 1/3 Split View
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 390), .stacked)   // iPhone
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 592), .stacked)   // 1/2 Split View on 11" (iOS reports compact width here)
    }

    func testHalfAndTwoThirdsSplitUseTwoColumns() {
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 678), .twoColumn)  // 1/2 Split View on 13"
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 694), .twoColumn)  // 2/3 Split View on 11"
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 834), .twoColumn)  // iPad portrait
    }

    func testFullScreenLandscapeUsesThreeColumns() {
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 1024), .threeColumn)
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 1194), .threeColumn)
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: 1366), .threeColumn)
    }

    func testStageManagerMinimumWindowStaysStacked() {
        XCTAssertEqual(CapitalIQLayout.columnLayout(forWidth: CapitalIQLayout.stageManagerMinimumSize.width), .stacked)
    }

    func testProfilePaneBreakpoint() {
        XCTAssertFalse(CapitalIQLayout.profileUsesTwoPanes(width: 390))
        XCTAssertTrue(CapitalIQLayout.profileUsesTwoPanes(width: 820))
    }

    func testFittingColumnsDropsOptionalColumnsFromTheRight() {
        let fitted = WatchlistColumn.fitting(WatchlistColumn.defaultVisible, availableWidth: 400)
        XCTAssertTrue(fitted.contains(.ticker))
        XCTAssertTrue(fitted.contains(.price))
        XCTAssertFalse(fitted.contains(.dividendYield))
        XCTAssertEqual(fitted, WatchlistColumn.defaultVisible.filter(fitted.contains))
        XCTAssertEqual(WatchlistColumn.fitting(WatchlistColumn.defaultVisible, availableWidth: 2000), WatchlistColumn.defaultVisible)
    }

    func testRequiredColumnsAreAlwaysRestored() {
        let columns = WatchlistColumn.columns(fromRawValues: ["name", "volume"])
        XCTAssertEqual(columns, [.ticker, .name, .price, .volume])
        XCTAssertEqual(WatchlistColumn.columns(fromRawValues: ["bogus"]), WatchlistColumn.defaultVisible)
    }
}

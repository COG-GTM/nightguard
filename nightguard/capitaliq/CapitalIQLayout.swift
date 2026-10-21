//
//  CapitalIQLayout.swift
//  nightguard
//
//  Width-driven layout decisions for Split View, Slide Over, Stage Manager
//  and full-screen iPad, plus the configurable watchlist table columns.
//

import Foundation
import CoreGraphics

enum CapitalIQColumnLayout: Equatable {
    /// Phone / Slide Over / 1/3 Split View: tab bar + stacked navigation.
    case stacked
    /// 1/2 and 2/3 Split View, narrow Stage Manager windows: sidebar + list/detail.
    case twoColumn
    /// Full-screen iPad and wide Stage Manager windows: sidebar + list + detail.
    case threeColumn
}

enum CapitalIQLayout {

    /// Below this width (Slide Over ≈ 320pt, 1/3 Split ≈ 375pt) iOS reports a compact size class.
    static let compactMaximumWidth: CGFloat = 599
    /// Three columns need roughly sidebar 260 + list 360 + detail 400.
    static let threeColumnMinimumWidth: CGFloat = 1000
    /// Smallest window Stage Manager may resize us to.
    static let stageManagerMinimumSize = CGSize(width: 320, height: 480)

    static func columnLayout(forWidth width: CGFloat) -> CapitalIQColumnLayout {
        if width <= compactMaximumWidth { return .stacked }
        if width >= threeColumnMinimumWidth { return .threeColumn }
        return .twoColumn
    }

    /// Company profile shows two side-by-side panes once the detail pane is wide enough.
    static func profileUsesTwoPanes(width: CGFloat) -> Bool {
        width >= 700
    }
}

enum WatchlistColumn: String, CaseIterable, Codable, Identifiable {
    case ticker, name, price, change, changePercent, marketCap, peRatio, dividendYield, volume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ticker: return "Ticker"
        case .name: return "Company"
        case .price: return "Last"
        case .change: return "Chg"
        case .changePercent: return "Chg %"
        case .marketCap: return "Mkt Cap"
        case .peRatio: return "P/E"
        case .dividendYield: return "Div Yld"
        case .volume: return "Volume"
        }
    }

    var width: CGFloat {
        switch self {
        case .ticker: return 72
        case .name: return 220
        case .price: return 84
        case .change: return 76
        case .changePercent: return 80
        case .marketCap: return 90
        case .peRatio: return 64
        case .dividendYield: return 72
        case .volume: return 80
        }
    }

    /// Ticker and last price are always shown.
    var isRequired: Bool { self == .ticker || self == .price }

    static let defaultVisible: [WatchlistColumn] = [.ticker, .name, .price, .change, .changePercent, .marketCap, .peRatio, .dividendYield]

    static func columns(fromRawValues raw: [String]) -> [WatchlistColumn] {
        let parsed = raw.compactMap(WatchlistColumn.init(rawValue:))
        var result = parsed.isEmpty ? defaultVisible : parsed
        for required in WatchlistColumn.allCases where required.isRequired && !result.contains(required) {
            result.insert(required, at: required == .ticker ? 0 : min(result.count, 1))
        }
        return WatchlistColumn.allCases.filter(result.contains)
    }

    /// Drops optional columns from the right until the row fits `availableWidth`.
    static func fitting(_ preferred: [WatchlistColumn], availableWidth: CGFloat, spacing: CGFloat = 12) -> [WatchlistColumn] {
        var columns = preferred
        func totalWidth() -> CGFloat {
            columns.reduce(0) { $0 + $1.width } + CGFloat(max(columns.count - 1, 0)) * spacing
        }
        while totalWidth() > availableWidth, let index = columns.lastIndex(where: { !$0.isRequired }) {
            columns.remove(at: index)
        }
        return columns
    }
}

extension Instrument {
    func value(for column: WatchlistColumn) -> String {
        switch column {
        case .ticker: return ticker
        case .name: return name
        case .price: return PriceFormatter.price(price)
        case .change: return String(format: "%@%.2f", change >= 0 ? "+" : "", change)
        case .changePercent: return PriceFormatter.percent(changePercent)
        case .marketCap: return PriceFormatter.marketCap(marketCapBillions)
        case .peRatio: return String(format: "%.1fx", peRatio)
        case .dividendYield: return String(format: "%.1f%%", dividendYield)
        case .volume: return PriceFormatter.volume(volumeMillions)
        }
    }
}

extension UserDefaultsRepository {
    /// Visible columns of the regular-width watchlist table (WatchlistColumn raw values).
    /// Lives here (iOS app target only) because UserDefaultsRepository is shared with the watch and widget targets.
    static let watchlistColumns = UserDefaultsValue<[String]>(key: "capitaliq.watchlistColumns", default: WatchlistColumn.defaultVisible.map(\.rawValue))
}

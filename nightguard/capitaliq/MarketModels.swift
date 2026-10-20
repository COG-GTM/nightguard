//
//  MarketModels.swift
//  nightguard
//
//  Domain model for the S&P Capital IQ Pro demo stand-in: instruments,
//  watchlists, news and company-profile content. Pure Foundation so the
//  unit-test target can compile it without UIKit/SwiftUI.
//

import Foundation

struct Instrument: Identifiable, Hashable, Codable {
    let ticker: String
    let name: String
    let exchange: String
    let sector: String
    let country: String
    let price: Double
    let change: Double
    let marketCapBillions: Double
    let peRatio: Double
    let dividendYield: Double
    let volumeMillions: Double

    var id: String { ticker }

    var changePercent: Double {
        let previous = price - change
        guard previous != 0 else { return 0 }
        return change / previous * 100
    }
}

struct Watchlist: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var tickers: [String]
}

struct NewsItem: Identifiable, Hashable {
    let id: String
    let headline: String
    let source: String
    let minutesAgo: Int
    let tickers: [String]
    let summary: String
}

struct KeyDevelopment: Identifiable, Hashable {
    let id: String
    let date: String
    let type: String
    let headline: String
}

struct FinancialRow: Identifiable, Hashable {
    let label: String
    let values: [String]

    var id: String { label }
}

struct Officer: Identifiable, Hashable {
    let name: String
    let title: String

    var id: String { name + title }
}

struct MarketIndex: Identifiable, Hashable {
    let name: String
    let level: Double
    let change: Double

    var id: String { name }

    var changePercent: Double {
        let previous = level - change
        guard previous != 0 else { return 0 }
        return change / previous * 100
    }
}

enum PriceFormatter {

    static func price(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    static func change(_ change: Double, percent: Double) -> String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f (%@%.2f%%)", sign, change, sign, percent)
    }

    static func percent(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
    }

    static func marketCap(_ billions: Double) -> String {
        if billions >= 1000 {
            return String(format: "%.2fT", billions / 1000)
        }
        return String(format: "%.1fB", billions)
    }

    static func volume(_ millions: Double) -> String {
        String(format: "%.1fM", millions)
    }
}

enum SampleMarketData {

    static let instruments: [Instrument] = [
        Instrument(ticker: "JPM", name: "JPMorgan Chase & Co.", exchange: "NYSE", sector: "Financials", country: "United States", price: 212.43, change: 1.82, marketCapBillions: 611.2, peRatio: 12.1, dividendYield: 2.2, volumeMillions: 8.4),
        Instrument(ticker: "BAC", name: "Bank of America Corporation", exchange: "NYSE", sector: "Financials", country: "United States", price: 41.17, change: -0.36, marketCapBillions: 318.9, peRatio: 13.4, dividendYield: 2.5, volumeMillions: 31.2),
        Instrument(ticker: "WFC", name: "Wells Fargo & Company", exchange: "NYSE", sector: "Financials", country: "United States", price: 63.08, change: 0.54, marketCapBillions: 214.6, peRatio: 12.8, dividendYield: 2.3, volumeMillions: 14.7),
        Instrument(ticker: "C", name: "Citigroup Inc.", exchange: "NYSE", sector: "Financials", country: "United States", price: 66.91, change: -1.12, marketCapBillions: 126.4, peRatio: 10.9, dividendYield: 3.3, volumeMillions: 12.9),
        Instrument(ticker: "GS", name: "The Goldman Sachs Group, Inc.", exchange: "NYSE", sector: "Financials", country: "United States", price: 514.22, change: 6.47, marketCapBillions: 165.1, peRatio: 15.6, dividendYield: 2.1, volumeMillions: 2.1),
        Instrument(ticker: "MS", name: "Morgan Stanley", exchange: "NYSE", sector: "Financials", country: "United States", price: 118.36, change: 0.91, marketCapBillions: 190.3, peRatio: 16.2, dividendYield: 3.0, volumeMillions: 6.8),
        Instrument(ticker: "XOM", name: "Exxon Mobil Corporation", exchange: "NYSE", sector: "Energy", country: "United States", price: 117.54, change: -2.18, marketCapBillions: 467.8, peRatio: 13.9, dividendYield: 3.2, volumeMillions: 15.3),
        Instrument(ticker: "CVX", name: "Chevron Corporation", exchange: "NYSE", sector: "Energy", country: "United States", price: 154.06, change: -1.47, marketCapBillions: 282.5, peRatio: 14.8, dividendYield: 4.2, volumeMillions: 7.9),
        Instrument(ticker: "SHEL", name: "Shell plc", exchange: "LSE", sector: "Energy", country: "United Kingdom", price: 33.72, change: 0.21, marketCapBillions: 209.1, peRatio: 12.3, dividendYield: 3.9, volumeMillions: 4.6),
        Instrument(ticker: "BP", name: "BP p.l.c.", exchange: "LSE", sector: "Energy", country: "United Kingdom", price: 35.18, change: 0.44, marketCapBillions: 92.7, peRatio: 11.7, dividendYield: 5.1, volumeMillions: 9.1),
        Instrument(ticker: "AAPL", name: "Apple Inc.", exchange: "NasdaqGS", sector: "Information Technology", country: "United States", price: 227.63, change: 2.94, marketCapBillions: 3461.0, peRatio: 34.5, dividendYield: 0.4, volumeMillions: 48.2),
        Instrument(ticker: "MSFT", name: "Microsoft Corporation", exchange: "NasdaqGS", sector: "Information Technology", country: "United States", price: 421.88, change: -3.21, marketCapBillions: 3136.0, peRatio: 35.8, dividendYield: 0.7, volumeMillions: 19.6),
        Instrument(ticker: "NVDA", name: "NVIDIA Corporation", exchange: "NasdaqGS", sector: "Information Technology", country: "United States", price: 138.07, change: 4.56, marketCapBillions: 3388.0, peRatio: 64.2, dividendYield: 0.0, volumeMillions: 212.4),
        Instrument(ticker: "ASML", name: "ASML Holding N.V.", exchange: "ENXTAM", sector: "Information Technology", country: "Netherlands", price: 712.40, change: -8.90, marketCapBillions: 280.4, peRatio: 36.1, dividendYield: 0.9, volumeMillions: 1.2),
        Instrument(ticker: "SPGI", name: "S&P Global Inc.", exchange: "NYSE", sector: "Financials", country: "United States", price: 512.77, change: 3.08, marketCapBillions: 160.9, peRatio: 39.4, dividendYield: 0.7, volumeMillions: 1.4),
        Instrument(ticker: "MCO", name: "Moody's Corporation", exchange: "NYSE", sector: "Financials", country: "United States", price: 468.15, change: 1.62, marketCapBillions: 85.3, peRatio: 41.7, dividendYield: 0.7, volumeMillions: 0.6),
    ]

    static let watchlists: [Watchlist] = [
        Watchlist(id: "us-banks", name: "US Banks", tickers: ["JPM", "BAC", "WFC", "C", "GS", "MS"]),
        Watchlist(id: "energy-majors", name: "Energy Majors", tickers: ["XOM", "CVX", "SHEL", "BP"]),
        Watchlist(id: "tech-megacaps", name: "Tech Megacaps", tickers: ["AAPL", "MSFT", "NVDA", "ASML"]),
        Watchlist(id: "ratings-peers", name: "Ratings & Data Peers", tickers: ["SPGI", "MCO"]),
    ]

    static let indices: [MarketIndex] = [
        MarketIndex(name: "S&P 500", level: 5842.47, change: 23.36),
        MarketIndex(name: "Dow Jones", level: 43275.91, change: -140.59),
        MarketIndex(name: "Nasdaq", level: 18489.55, change: 138.83),
        MarketIndex(name: "FTSE 100", level: 8358.25, change: -26.88),
        MarketIndex(name: "Euro Stoxx 50", level: 4986.51, change: 12.04),
        MarketIndex(name: "Nikkei 225", level: 38911.19, change: 70.56),
        MarketIndex(name: "US 10Y Yield", level: 4.08, change: 0.03),
        MarketIndex(name: "WTI Crude", level: 70.56, change: -1.45),
    ]

    static let news: [NewsItem] = [
        NewsItem(id: "n1", headline: "JPMorgan lifts full-year NII guidance as deposit costs stabilize", source: "S&P Global Market Intelligence", minutesAgo: 14, tickers: ["JPM"], summary: "Management now expects net interest income of roughly $92.5B, citing slower deposit repricing and loan growth in card."),
        NewsItem(id: "n2", headline: "Exxon, Chevron slip as crude retreats on OPEC+ supply signals", source: "S&P Global Commodity Insights", minutesAgo: 41, tickers: ["XOM", "CVX"], summary: "WTI fell below $71 after reports that producers may unwind voluntary cuts earlier than planned."),
        NewsItem(id: "n3", headline: "NVIDIA data center backlog extends into 2026, analysts raise targets", source: "S&P Global Market Intelligence", minutesAgo: 67, tickers: ["NVDA"], summary: "Consensus estimates for FY26 revenue moved up 4% following supply-chain checks on Blackwell shipments."),
        NewsItem(id: "n4", headline: "Goldman Sachs trading revenue beats as equities desk posts record quarter", source: "S&P Global Market Intelligence", minutesAgo: 95, tickers: ["GS"], summary: "Equities trading revenue rose 18% year over year; investment banking fees grew 20%."),
        NewsItem(id: "n5", headline: "S&P Global ratings issuance outlook: investment-grade volumes to stay elevated", source: "S&P Global Ratings", minutesAgo: 130, tickers: ["SPGI"], summary: "Refinancing walls in 2025–2027 continue to support issuance despite wider spreads in high yield."),
        NewsItem(id: "n6", headline: "ASML Q3 bookings miss consensus; 2025 guide trimmed", source: "S&P Global Market Intelligence", minutesAgo: 180, tickers: ["ASML"], summary: "Bookings of €2.6B compared with consensus of €5.4B; management cited slower recovery outside AI."),
        NewsItem(id: "n7", headline: "Citigroup reorganization: five business lines report directly to CEO", source: "S&P Global Market Intelligence", minutesAgo: 240, tickers: ["C"], summary: "The bank completed the management layer reductions announced last year, removing roughly 7,000 roles."),
        NewsItem(id: "n8", headline: "Shell flags weaker refining margins in Q3 trading update", source: "S&P Global Commodity Insights", minutesAgo: 310, tickers: ["SHEL"], summary: "Indicative refining margins fell to $5.5/bbl from $7.7/bbl in the second quarter."),
    ]

    static func instrument(_ ticker: String) -> Instrument? {
        instruments.first { $0.ticker == ticker }
    }

    static func news(for ticker: String) -> [NewsItem] {
        news.filter { $0.tickers.contains(ticker) }
    }

    static func keyDevelopments(for instrument: Instrument) -> [KeyDevelopment] {
        [
            KeyDevelopment(id: "\(instrument.ticker)-kd1", date: "Oct 15, 2026", type: "Earnings Call", headline: "\(instrument.name) Q3 2026 earnings call transcript available"),
            KeyDevelopment(id: "\(instrument.ticker)-kd2", date: "Oct 08, 2026", type: "Guidance", headline: "\(instrument.name) reaffirms FY2026 guidance"),
            KeyDevelopment(id: "\(instrument.ticker)-kd3", date: "Sep 24, 2026", type: "Executive Change", headline: "\(instrument.name) names new head of \(instrument.sector)"),
            KeyDevelopment(id: "\(instrument.ticker)-kd4", date: "Sep 02, 2026", type: "Buyback", headline: "Board authorizes additional share repurchase program"),
        ]
    }

    static let financialPeriods = ["FY2023", "FY2024", "FY2025", "LTM"]

    static func financials(for instrument: Instrument) -> [FinancialRow] {
        let base = instrument.marketCapBillions / 4
        func series(_ factor: Double, growth: Double) -> [String] {
            (0..<4).map { String(format: "%.1fB", base * factor * pow(1 + growth, Double($0))) }
        }
        return [
            FinancialRow(label: "Total Revenue", values: series(0.42, growth: 0.07)),
            FinancialRow(label: "EBITDA", values: series(0.14, growth: 0.09)),
            FinancialRow(label: "Net Income", values: series(0.08, growth: 0.11)),
            FinancialRow(label: "Diluted EPS", values: (0..<4).map { String(format: "%.2f", instrument.price / instrument.peRatio * pow(1.1, Double($0) - 3)) }),
            FinancialRow(label: "Total Assets", values: series(1.8, growth: 0.04)),
            FinancialRow(label: "Total Debt", values: series(0.35, growth: 0.02)),
        ]
    }

    static func officers(for instrument: Instrument) -> [Officer] {
        [
            Officer(name: "Chief Executive Officer", title: "CEO & Director"),
            Officer(name: "Chief Financial Officer", title: "CFO"),
            Officer(name: "Chief Operating Officer", title: "COO"),
            Officer(name: "Chief Risk Officer", title: "CRO"),
        ]
    }

    static func estimates(for instrument: Instrument) -> [FinancialRow] {
        [
            FinancialRow(label: "EPS (FY+1)", values: [String(format: "%.2f", instrument.price / instrument.peRatio * 1.1)]),
            FinancialRow(label: "Revenue (FY+1)", values: [String(format: "%.1fB", instrument.marketCapBillions * 0.46)]),
            FinancialRow(label: "Target Price", values: [String(format: "%.2f", instrument.price * 1.12)]),
            FinancialRow(label: "Consensus", values: [instrument.change >= 0 ? "Outperform" : "Hold"]),
        ]
    }
}

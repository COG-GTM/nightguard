//
//  AppRouter.swift
//  nightguard
//
//  Navigation state for one Capital IQ Pro window: the selected section,
//  watchlist and company, plus universal-link / user-activity / keyboard
//  routing. Pure Foundation + Combine so it is unit-testable.
//

import Foundation
import Combine

enum CapitalIQSection: String, CaseIterable, Hashable, Codable {
    case news, markets, watchlists, search, alerts, more

    var title: String {
        switch self {
        case .news: return "News"
        case .markets: return "Markets"
        case .watchlists: return "Watchlists"
        case .search: return "Search"
        case .alerts: return "Alerts"
        case .more: return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .news: return "newspaper"
        case .markets: return "chart.xyaxis.line"
        case .watchlists: return "list.star"
        case .search: return "magnifyingglass"
        case .alerts: return "bell"
        case .more: return "ellipsis.circle"
        }
    }
}

/// Deep-linkable destinations. Universal link form:
/// `https://capitaliq.spglobal.com/watchlist/{id}`, `/watchlists`, `/company/{ticker}`.
/// Custom scheme form: `capitaliqpro://watchlist/{id}` etc.
enum WatchlistRoute: Equatable {
    case watchlists
    case watchlist(id: String)
    case company(ticker: String)

    static let universalLinkHost = "capitaliq.spglobal.com"
    static let urlScheme = "capitaliqpro"
    static let activityType = "com.spglobal.capitaliqpro.route"
    private static let activityURLKey = "url"

    init?(url: URL) {
        var components: [String]
        if url.scheme?.lowercased() == WatchlistRoute.urlScheme {
            components = [url.host ?? ""] + url.pathComponents.filter { $0 != "/" }
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.lowercased() == WatchlistRoute.universalLinkHost {
            components = url.pathComponents.filter { $0 != "/" }
        } else {
            return nil
        }
        components = components.filter { !$0.isEmpty }
        switch (components.first?.lowercased(), components.dropFirst().first) {
        case ("watchlists", nil):
            self = .watchlists
        case ("watchlist", let id?):
            self = .watchlist(id: id)
        case ("company", let ticker?):
            self = .company(ticker: ticker.uppercased())
        default:
            return nil
        }
    }

    init?(userActivity: NSUserActivity) {
        guard userActivity.activityType == WatchlistRoute.activityType || userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return nil }
        if let url = userActivity.webpageURL, let route = WatchlistRoute(url: url) {
            self = route
        } else if let string = userActivity.userInfo?[WatchlistRoute.activityURLKey] as? String,
                  let url = URL(string: string), let route = WatchlistRoute(url: url) {
            self = route
        } else {
            return nil
        }
    }

    var path: String {
        switch self {
        case .watchlists: return "/watchlists"
        case .watchlist(let id): return "/watchlist/\(id)"
        case .company(let ticker): return "/company/\(ticker)"
        }
    }

    var universalLink: URL {
        URL(string: "https://\(WatchlistRoute.universalLinkHost)\(path)")!
    }

    var title: String {
        switch self {
        case .watchlists: return "Watchlists"
        case .watchlist(let id): return id
        case .company(let ticker): return ticker
        }
    }

    var userActivity: NSUserActivity {
        let activity = NSUserActivity(activityType: WatchlistRoute.activityType)
        activity.title = title
        activity.webpageURL = universalLink
        activity.userInfo = [WatchlistRoute.activityURLKey: universalLink.absoluteString]
        activity.targetContentIdentifier = universalLink.absoluteString
        activity.isEligibleForHandoff = true
        return activity
    }
}

enum CapitalIQKeyCommand: Equatable, CaseIterable {
    case showWatchlists, focusSearch, nextWatchlist, previousWatchlist

    /// Maps a key + command-modifier pair to a shortcut. `key` is "1", "f", "up" or "down".
    init?(key: String, command: Bool) {
        guard command else { return nil }
        switch key.lowercased() {
        case "1": self = .showWatchlists
        case "f": self = .focusSearch
        case "up": self = .previousWatchlist
        case "down": self = .nextWatchlist
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .showWatchlists: return "Watchlists"
        case .focusSearch: return "Search"
        case .nextWatchlist: return "Next Watchlist"
        case .previousWatchlist: return "Previous Watchlist"
        }
    }
}

enum CapitalIQStackStep: Hashable {
    case watchlist(String)
    case company(String)
}

final class AppRouter: ObservableObject {

    @Published var section: CapitalIQSection
    @Published var selectedWatchlistID: String?
    @Published var selectedTicker: String?
    /// Phone-width navigation stack for the Watchlists tab.
    @Published var watchlistStack: [CapitalIQStackStep] = []
    /// Incremented whenever ⌘F asks the search field to take focus.
    @Published var searchFocusRequest = 0

    let store: WatchlistStore

    init(store: WatchlistStore = .shared, defaultWatchlistID: String? = nil) {
        self.store = store
        if let id = defaultWatchlistID, !id.isEmpty, let watchlist = store.watchlist(id: id) {
            section = .watchlists
            selectedWatchlistID = watchlist.id
            watchlistStack = [.watchlist(watchlist.id)]
        } else {
            section = .news
            selectedWatchlistID = nil
        }
    }

    var selectedWatchlist: Watchlist? {
        selectedWatchlistID.flatMap { store.watchlist(id: $0) }
    }

    var selectedInstrument: Instrument? {
        selectedTicker.flatMap { store.instrument($0) }
    }

    /// The route describing what this window shows, used for state restoration and "Open in New Window".
    var currentRoute: WatchlistRoute? {
        if let ticker = selectedTicker { return .company(ticker: ticker) }
        guard section == .watchlists else { return nil }
        if let id = selectedWatchlistID { return .watchlist(id: id) }
        return .watchlists
    }

    func navigate(to route: WatchlistRoute) {
        switch route {
        case .watchlists:
            section = .watchlists
            selectedTicker = nil
            watchlistStack = []
        case .watchlist(let id):
            guard let watchlist = store.watchlist(id: id) else { return }
            section = .watchlists
            selectedWatchlistID = watchlist.id
            selectedTicker = nil
            watchlistStack = [.watchlist(watchlist.id)]
        case .company(let ticker):
            guard let instrument = store.instrument(ticker) else { return }
            section = .watchlists
            selectedTicker = instrument.ticker
            if let id = selectedWatchlistID {
                watchlistStack = [.watchlist(id), .company(instrument.ticker)]
            } else {
                watchlistStack = [.company(instrument.ticker)]
            }
        }
    }

    func select(watchlistID: String) {
        navigate(to: .watchlist(id: watchlistID))
    }

    func select(ticker: String?) {
        guard let ticker else {
            selectedTicker = nil
            return
        }
        navigate(to: .company(ticker: ticker))
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        guard let route = WatchlistRoute(url: url) else { return false }
        navigate(to: route)
        return true
    }

    @discardableResult
    func handle(userActivity: NSUserActivity) -> Bool {
        guard let route = WatchlistRoute(userActivity: userActivity) else { return false }
        navigate(to: route)
        return true
    }

    func handle(_ command: CapitalIQKeyCommand) {
        switch command {
        case .showWatchlists:
            if let id = selectedWatchlistID ?? store.watchlists.first?.id {
                navigate(to: .watchlist(id: id))
            } else {
                navigate(to: .watchlists)
            }
        case .focusSearch:
            section = .search
            selectedTicker = nil
            searchFocusRequest += 1
        case .previousWatchlist:
            if let previous = store.watchlist(before: selectedWatchlistID) { navigate(to: .watchlist(id: previous.id)) }
        case .nextWatchlist:
            if let next = store.watchlist(after: selectedWatchlistID) { navigate(to: .watchlist(id: next.id)) }
        }
    }
}

//
//  CapitalIQSidebarView.swift
//  nightguard
//
//  Regular-width sidebar: Home, Watchlists (top level, one tap) and Tools.
//

import SwiftUI

enum CapitalIQSidebarItem: Hashable {
    case section(CapitalIQSection)
    case watchlist(String)
}

struct CapitalIQSidebarView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: WatchlistStore
    @State private var dropTarget: String?

    private var selection: Binding<CapitalIQSidebarItem?> {
        Binding(
            get: {
                if router.section == .watchlists, let id = router.selectedWatchlistID {
                    return .watchlist(id)
                }
                return .section(router.section)
            },
            set: { item in
                switch item {
                case .section(let section)?:
                    router.section = section
                    router.selectedTicker = nil
                    if section == .watchlists { router.navigate(to: .watchlists) }
                case .watchlist(let id)?:
                    router.select(watchlistID: id)
                case nil:
                    break
                }
            }
        )
    }

    var body: some View {
        List(selection: selection) {
            Section {
                sectionRow(.news)
                sectionRow(.markets)
            } header: {
                CapitalIQWordmark(size: 15).padding(.bottom, 8).textCase(nil)
            }

            Section("Watchlists") {
                ForEach(store.watchlists) { watchlist in
                    Label {
                        HStack {
                            Text(watchlist.name)
                            Spacer()
                            Text("\(watchlist.tickers.count)")
                                .font(.system(size: 12))
                                .foregroundColor(CapitalIQTheme.inkMuted)
                        }
                    } icon: {
                        Image(systemName: "list.star")
                    }
                    .tag(CapitalIQSidebarItem.watchlist(watchlist.id))
                    .accessibilityIdentifier("sidebar_watchlist_\(watchlist.id)")
                    .listRowBackground(dropTarget == watchlist.id ? CapitalIQTheme.red.opacity(0.15) : nil)
                    .contextMenu {
                        if WindowOpener.supportsMultipleWindows {
                            Button {
                                WindowOpener.open(.watchlist(id: watchlist.id))
                            } label: {
                                Label("Open in New Window", systemImage: "square.split.2x1")
                            }
                        }
                        Button {
                            UIPasteboard.general.url = WatchlistRoute.watchlist(id: watchlist.id).universalLink
                        } label: {
                            Label("Copy Link", systemImage: "link")
                        }
                    }
                    .dropDestination(for: String.self) { tickers, _ in
                        tickers.map { store.add(ticker: $0, to: watchlist.id) }.contains(true)
                    } isTargeted: { targeted in
                        dropTarget = targeted ? watchlist.id : (dropTarget == watchlist.id ? nil : dropTarget)
                    }
                }
                Label("All Watchlists", systemImage: "square.grid.2x2")
                    .tag(CapitalIQSidebarItem.section(.watchlists))
                    .accessibilityIdentifier("sidebar_all_watchlists")
            }

            Section("Tools") {
                sectionRow(.search)
                sectionRow(.alerts)
                sectionRow(.more)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Capital IQ Pro")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("capitaliq_sidebar")
    }

    private func sectionRow(_ section: CapitalIQSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(CapitalIQSidebarItem.section(section))
            .accessibilityIdentifier("sidebar_\(section.rawValue)")
    }
}

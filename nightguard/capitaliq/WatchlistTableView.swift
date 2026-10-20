//
//  WatchlistTableView.swift
//  nightguard
//
//  Regular-width watchlist: configurable multi-column table with pointer
//  hover, context menus and drag & drop of tickers.
//

import SwiftUI

struct WatchlistTableView: View {
    @EnvironmentObject private var store: WatchlistStore
    @EnvironmentObject private var router: AppRouter
    let watchlistID: String
    @State private var preferredColumns = WatchlistColumn.columns(fromRawValues: UserDefaultsRepository.watchlistColumns.value)
    @State private var hoveredTicker: String?
    @State private var isDropTargeted = false

    private let spacing: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let columns = WatchlistColumn.fitting(preferredColumns, availableWidth: geometry.size.width - 32, spacing: spacing)
            let watchlist = store.watchlist(id: watchlistID)
            VStack(spacing: 0) {
                header(columns: columns)
                Divider()
                if let watchlist {
                    List {
                        ForEach(store.instruments(in: watchlist)) { instrument in
                            row(instrument, columns: columns, watchlist: watchlist)
                        }
                    }
                    .listStyle(.plain)
                    .dropDestination(for: String.self) { tickers, _ in
                        tickers.map { store.add(ticker: $0, to: watchlist.id) }.contains(true)
                    } isTargeted: { isDropTargeted = $0 }
                } else {
                    Spacer()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 0).stroke(CapitalIQTheme.red, lineWidth: isDropTargeted ? 2 : 0)
            )
            .navigationTitle(watchlist?.name ?? "Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    columnMenu
                    if WindowOpener.supportsMultipleWindows {
                        Button {
                            WindowOpener.open(.watchlist(id: watchlistID))
                        } label: {
                            Label("Open in New Window", systemImage: "square.split.2x1")
                        }
                        .accessibilityIdentifier("watchlist_open_new_window")
                    }
                }
            }
        }
        .accessibilityIdentifier("watchlist_table")
    }

    private var columnMenu: some View {
        Menu {
            ForEach(WatchlistColumn.allCases) { column in
                Button {
                    toggle(column)
                } label: {
                    if preferredColumns.contains(column) {
                        Label(column.title, systemImage: "checkmark")
                    } else {
                        Text(column.title)
                    }
                }
                .disabled(column.isRequired)
            }
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
        }
        .accessibilityIdentifier("watchlist_columns_menu")
    }

    private func toggle(_ column: WatchlistColumn) {
        if preferredColumns.contains(column) {
            preferredColumns.removeAll { $0 == column }
        } else {
            preferredColumns.append(column)
        }
        preferredColumns = WatchlistColumn.allCases.filter(preferredColumns.contains)
        UserDefaultsRepository.watchlistColumns.value = preferredColumns.map(\.rawValue)
    }

    private func header(columns: [WatchlistColumn]) -> some View {
        HStack(spacing: spacing) {
            ForEach(columns) { column in
                Text(column.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(CapitalIQTheme.inkMuted)
                    .frame(width: column == .name ? nil : column.width, alignment: alignment(for: column))
                    .frame(maxWidth: column == .name ? .infinity : nil, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(CapitalIQTheme.canvas)
    }

    private func row(_ instrument: Instrument, columns: [WatchlistColumn], watchlist: Watchlist) -> some View {
        let isSelected = router.selectedTicker == instrument.ticker
        return Button {
            router.select(ticker: instrument.ticker)
        } label: {
            HStack(spacing: spacing) {
                ForEach(columns) { column in
                    Text(instrument.value(for: column))
                        .font(column == .ticker ? .system(size: 14, weight: .bold) : column == .name ? .system(size: 14) : CapitalIQTheme.numeric(14))
                        .foregroundColor(color(for: column, instrument: instrument, selected: isSelected))
                        .lineLimit(1)
                        .frame(width: column == .name ? nil : column.width, alignment: alignment(for: column))
                        .frame(maxWidth: column == .name ? .infinity : nil, alignment: .leading)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? CapitalIQTheme.navy : (hoveredTicker == instrument.ticker ? CapitalIQTheme.navy.opacity(0.06) : Color.clear))
        .onHover { hovering in
            hoveredTicker = hovering ? instrument.ticker : (hoveredTicker == instrument.ticker ? nil : hoveredTicker)
        }
        .hoverEffect(.highlight)
        .draggable(instrument.ticker)
        .contextMenu {
            if WindowOpener.supportsMultipleWindows {
                Button {
                    WindowOpener.open(.company(ticker: instrument.ticker))
                } label: {
                    Label("Open in New Window", systemImage: "square.split.2x1")
                }
            }
            Menu {
                ForEach(store.watchlists.filter { $0.id != watchlist.id }) { other in
                    Button(other.name) { store.add(ticker: instrument.ticker, to: other.id) }
                }
            } label: {
                Label("Add to Watchlist", systemImage: "plus.circle")
            }
            Button {
                UIPasteboard.general.string = instrument.ticker
            } label: {
                Label("Copy Ticker", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                store.remove(ticker: instrument.ticker, from: watchlist.id)
            } label: {
                Label("Remove from \(watchlist.name)", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("watchlist_row_\(instrument.ticker)")
    }

    private func alignment(for column: WatchlistColumn) -> Alignment {
        switch column {
        case .ticker, .name: return .leading
        default: return .trailing
        }
    }

    private func color(for column: WatchlistColumn, instrument: Instrument, selected: Bool) -> Color {
        if selected { return .white }
        switch column {
        case .change, .changePercent: return CapitalIQTheme.color(forChange: instrument.change)
        case .name: return CapitalIQTheme.inkMuted
        default: return CapitalIQTheme.ink
        }
    }
}

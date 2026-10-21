//
//  SearchView.swift
//  nightguard
//
//  Company search across public and private profiles. ⌘F (via AppRouter)
//  focuses the search field.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: WatchlistStore
    @EnvironmentObject private var router: AppRouter
    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(CapitalIQTheme.inkMuted)
                TextField("Search companies, tickers, people", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .accessibilityIdentifier("company_search_field")
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(CapitalIQTheme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(CapitalIQTheme.canvas)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
            List(store.search(query)) { instrument in
                NavigationLink(destination: CompanyProfileView(instrument: instrument)) {
                    InstrumentRow(instrument: instrument)
                }
                .draggable(instrument.ticker)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if router.searchFocusRequest > 0 { isSearchFieldFocused = true } }
        .onChange(of: router.searchFocusRequest) { _ in isSearchFieldFocused = true }
        .accessibilityIdentifier("company_search")
    }
}

struct InstrumentRow: View {
    let instrument: Instrument

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(instrument.ticker).font(.system(size: 15, weight: .bold)).foregroundColor(CapitalIQTheme.ink)
                    Text(instrument.exchange).font(.system(size: 11)).foregroundColor(CapitalIQTheme.inkMuted)
                }
                Text(instrument.name).font(.system(size: 13)).foregroundColor(CapitalIQTheme.inkMuted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(PriceFormatter.price(instrument.price)).font(CapitalIQTheme.numeric(15, weight: .semibold)).foregroundColor(CapitalIQTheme.ink)
                PriceChangeText(change: instrument.change, percent: instrument.changePercent, font: CapitalIQTheme.numeric(12, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
    }
}

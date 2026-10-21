//
//  SearchView.swift
//  nightguard
//
//  Company search across public and private profiles.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: WatchlistStore
    @State private var query = ""
    var isSearchFieldFocused: FocusState<Bool>.Binding? = nil

    var body: some View {
        List(store.search(query)) { instrument in
            NavigationLink(destination: CompanyProfileView(instrument: instrument)) {
                InstrumentRow(instrument: instrument)
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search companies, tickers, people")
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
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

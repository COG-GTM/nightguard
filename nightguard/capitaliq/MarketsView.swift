//
//  MarketsView.swift
//  nightguard
//
//  Intraday market monitor: index tiles and sector movers.
//

import SwiftUI

struct IndexTile: View {
    let index: MarketIndex

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(index.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CapitalIQTheme.inkMuted)
                Text(PriceFormatter.price(index.level))
                    .font(CapitalIQTheme.numeric(22, weight: .bold))
                    .foregroundColor(CapitalIQTheme.ink)
                PriceChangeText(change: index.change, percent: index.changePercent, font: CapitalIQTheme.numeric(13, weight: .semibold))
            }
        }
    }
}

struct MarketsView: View {
    @EnvironmentObject private var store: WatchlistStore

    private var movers: [Instrument] {
        store.allInstruments.sorted { abs($0.changePercent) > abs($1.changePercent) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CapitalIQSectionTitle("Global Indices")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(SampleMarketData.indices) { IndexTile(index: $0) }
                }
                CapitalIQSectionTitle("Top Movers")
                CapitalIQCard {
                    VStack(spacing: 0) {
                        ForEach(Array(movers.prefix(8).enumerated()), id: \.element.id) { offset, instrument in
                            NavigationLink(destination: CompanyProfileView(instrument: instrument)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(instrument.ticker).font(.system(size: 15, weight: .bold)).foregroundColor(CapitalIQTheme.ink)
                                        Text(instrument.name).font(.system(size: 12)).foregroundColor(CapitalIQTheme.inkMuted).lineLimit(1)
                                    }
                                    Spacer()
                                    Text(PriceFormatter.price(instrument.price)).font(CapitalIQTheme.numeric(15)).foregroundColor(CapitalIQTheme.ink)
                                    Text(PriceFormatter.percent(instrument.changePercent))
                                        .font(CapitalIQTheme.numeric(13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(CapitalIQTheme.color(forChange: instrument.change))
                                        .cornerRadius(4)
                                        .frame(width: 80)
                                }
                                .padding(.vertical, 10)
                            }
                            if offset < min(movers.count, 8) - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(CapitalIQTheme.canvas)
        .navigationTitle("Markets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

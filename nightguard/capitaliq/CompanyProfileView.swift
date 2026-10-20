//
//  CompanyProfileView.swift
//  nightguard
//
//  Mobile corporate profile: a single scroll from snapshot to officers.
//

import SwiftUI

struct CompanyProfileView: View {
    let instrument: Instrument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompanyHeaderCard(instrument: instrument)
                CompanySnapshotCard(instrument: instrument)
                CompanyNewsCard(instrument: instrument)
                CompanyKeyDevelopmentsCard(instrument: instrument)
                CompanyFinancialsCard(instrument: instrument)
                CompanyEstimatesCard(instrument: instrument)
                CompanyOfficersCard(instrument: instrument)
            }
            .padding(16)
        }
        .background(CapitalIQTheme.canvas)
        .navigationTitle(instrument.ticker)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("company_profile_\(instrument.ticker)")
    }
}

struct CompanyHeaderCard: View {
    let instrument: Instrument

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(instrument.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(CapitalIQTheme.ink)
                Text("\(instrument.exchange):\(instrument.ticker) · \(instrument.sector) · \(instrument.country)")
                    .font(.system(size: 13))
                    .foregroundColor(CapitalIQTheme.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(PriceFormatter.price(instrument.price))
                        .font(CapitalIQTheme.numeric(34, weight: .bold))
                        .foregroundColor(CapitalIQTheme.ink)
                    PriceChangeText(change: instrument.change, percent: instrument.changePercent, font: CapitalIQTheme.numeric(16, weight: .semibold))
                }
                Text("Delayed · USD · Last updated 16:00 ET")
                    .font(.system(size: 11))
                    .foregroundColor(CapitalIQTheme.inkMuted)
            }
        }
    }
}

struct CompanySnapshotCard: View {
    let instrument: Instrument

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 10) {
                CapitalIQSectionTitle("Snapshot")
                KeyValueRow(label: "Market Cap", value: PriceFormatter.marketCap(instrument.marketCapBillions))
                KeyValueRow(label: "P/E (LTM)", value: String(format: "%.1fx", instrument.peRatio))
                KeyValueRow(label: "Dividend Yield", value: String(format: "%.1f%%", instrument.dividendYield))
                KeyValueRow(label: "Volume", value: PriceFormatter.volume(instrument.volumeMillions))
                KeyValueRow(label: "S&P Credit Rating", value: instrument.marketCapBillions > 300 ? "AA-" : "A")
            }
        }
    }
}

struct CompanyNewsCard: View {
    let instrument: Instrument

    var body: some View {
        let items = SampleMarketData.news(for: instrument.ticker)
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 10) {
                CapitalIQSectionTitle("Latest News")
                if items.isEmpty {
                    Text("No company news in the last 24 hours.").font(.system(size: 14)).foregroundColor(CapitalIQTheme.inkMuted)
                }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.headline).font(.system(size: 15, weight: .semibold)).foregroundColor(CapitalIQTheme.ink)
                        Text("\(item.source) · \(item.minutesAgo)m ago").font(.system(size: 12)).foregroundColor(CapitalIQTheme.inkMuted)
                    }
                }
            }
        }
    }
}

struct CompanyKeyDevelopmentsCard: View {
    let instrument: Instrument

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 10) {
                CapitalIQSectionTitle("Key Developments")
                ForEach(SampleMarketData.keyDevelopments(for: instrument)) { development in
                    HStack(alignment: .top, spacing: 10) {
                        Text(development.date).font(.system(size: 12)).foregroundColor(CapitalIQTheme.inkMuted).frame(width: 90, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(development.type).font(.system(size: 11, weight: .semibold)).foregroundColor(CapitalIQTheme.red)
                            Text(development.headline).font(.system(size: 14)).foregroundColor(CapitalIQTheme.ink)
                        }
                    }
                }
            }
        }
    }
}

struct CompanyFinancialsCard: View {
    let instrument: Instrument

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 10) {
                CapitalIQSectionTitle("Financials (USD)")
                HStack {
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(SampleMarketData.financialPeriods, id: \.self) { period in
                        Text(period).font(.system(size: 11, weight: .semibold)).foregroundColor(CapitalIQTheme.inkMuted).frame(width: 64, alignment: .trailing)
                    }
                }
                ForEach(SampleMarketData.financials(for: instrument)) { row in
                    HStack {
                        Text(row.label).font(.system(size: 13)).foregroundColor(CapitalIQTheme.ink).frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                            Text(value).font(CapitalIQTheme.numeric(13)).foregroundColor(CapitalIQTheme.ink).frame(width: 64, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

struct CompanyEstimatesCard: View {
    let instrument: Instrument

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 10) {
                CapitalIQSectionTitle("Estimates")
                ForEach(SampleMarketData.estimates(for: instrument)) { row in
                    KeyValueRow(label: row.label, value: row.values.first ?? "")
                }
            }
        }
    }
}

struct CompanyOfficersCard: View {
    let instrument: Instrument

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 10) {
                CapitalIQSectionTitle("Officers & Directors")
                ForEach(SampleMarketData.officers(for: instrument)) { officer in
                    KeyValueRow(label: officer.name, value: officer.title)
                }
            }
        }
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(CapitalIQTheme.inkMuted)
            Spacer()
            Text(value).font(CapitalIQTheme.numeric(14, weight: .semibold)).foregroundColor(CapitalIQTheme.ink)
        }
    }
}

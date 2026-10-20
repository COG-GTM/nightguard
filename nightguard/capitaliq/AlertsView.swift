//
//  AlertsView.swift
//  nightguard
//
//  Push alert inbox (news, filings, key developments, price alerts).
//

import SwiftUI

struct AlertsView: View {
    private struct AlertEntry: Identifiable {
        let id: Int
        let category: String
        let icon: String
        let text: String
        let age: String
    }

    private let alerts: [AlertEntry] = [
        AlertEntry(id: 1, category: "Price Alert", icon: "bell.badge", text: "NVDA crossed above 135.00 (threshold on Tech Megacaps)", age: "9m"),
        AlertEntry(id: 2, category: "Key Development", icon: "doc.text", text: "JPM: Q3 2026 earnings call transcript available", age: "32m"),
        AlertEntry(id: 3, category: "Filing", icon: "tray.full", text: "GS filed 10-Q for period ending Sep 30, 2026", age: "1h"),
        AlertEntry(id: 4, category: "Curated · Energy", icon: "flame", text: "Editor's pick: OPEC+ unwinding cuts — what it means for majors", age: "2h"),
        AlertEntry(id: 5, category: "Estimates", icon: "chart.line.uptrend.xyaxis", text: "ASML: 7 analysts revised FY25 EPS down in the last 24h", age: "3h"),
        AlertEntry(id: 6, category: "Screening", icon: "line.3.horizontal.decrease.circle", text: "2 new matches for 'Banks P/E < 12, Yield > 2%'", age: "5h"),
    ]

    var body: some View {
        List(alerts) { alert in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: alert.icon)
                    .foregroundColor(CapitalIQTheme.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.category).font(.system(size: 12, weight: .semibold)).foregroundColor(CapitalIQTheme.inkMuted)
                    Text(alert.text).font(.system(size: 15)).foregroundColor(CapitalIQTheme.ink)
                }
                Spacer()
                Text(alert.age).font(.system(size: 12)).foregroundColor(CapitalIQTheme.inkMuted)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

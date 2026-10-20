//
//  NewsFeedView.swift
//  nightguard
//
//  News home feed with the market ticker strip across the top.
//

import SwiftUI

struct MarketTickerStrip: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(SampleMarketData.indices) { index in
                    HStack(spacing: 6) {
                        Text(index.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(PriceFormatter.price(index.level))
                            .font(CapitalIQTheme.numeric(12))
                            .foregroundColor(.white.opacity(0.85))
                        Text(PriceFormatter.percent(index.changePercent))
                            .font(CapitalIQTheme.numeric(12, weight: .semibold))
                            .foregroundColor(index.change < 0 ? Color(red: 1, green: 0.55, blue: 0.6) : Color(red: 0.45, green: 0.9, blue: 0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(CapitalIQTheme.navyDeep)
        .accessibilityIdentifier("market_ticker_strip")
    }
}

struct NewsCard: View {
    let item: NewsItem

    var body: some View {
        CapitalIQCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(item.tickers, id: \.self) { ticker in
                        Text(ticker)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CapitalIQTheme.navy.opacity(0.08))
                            .foregroundColor(CapitalIQTheme.navy)
                            .cornerRadius(4)
                    }
                    Spacer()
                    Text("\(item.minutesAgo)m ago")
                        .font(.system(size: 12))
                        .foregroundColor(CapitalIQTheme.inkMuted)
                }
                Text(item.headline)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CapitalIQTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.summary)
                    .font(.system(size: 14))
                    .foregroundColor(CapitalIQTheme.inkMuted)
                    .lineLimit(3)
                Text(item.source)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CapitalIQTheme.red)
            }
        }
    }
}

struct NewsFeedView: View {
    @State private var sortByRelevance = false

    var body: some View {
        VStack(spacing: 0) {
            MarketTickerStrip()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CapitalIQSectionTitle("Top News")
                        Spacer()
                        Picker("Sort", selection: $sortByRelevance) {
                            Text("Most Recent").tag(false)
                            Text("Relevance").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                    }
                    ForEach(sortByRelevance ? SampleMarketData.news.reversed() : SampleMarketData.news) { item in
                        NewsCard(item: item)
                    }
                }
                .padding(16)
            }
            .background(CapitalIQTheme.canvas)
        }
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("news_feed")
    }
}

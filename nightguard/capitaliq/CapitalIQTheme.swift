//
//  CapitalIQTheme.swift
//  nightguard
//
//  Visual language for the S&P Capital IQ Pro demo stand-in: S&P Global red,
//  navy headers, light cards and tabular numerals.
//

import SwiftUI
import UIKit

enum CapitalIQTheme {

    static let red = Color(red: 0xD6 / 255, green: 0x00 / 255, blue: 0x2A / 255)
    static let navy = Color(red: 0x0A / 255, green: 0x1F / 255, blue: 0x44 / 255)
    static let navyDeep = Color(red: 0x06 / 255, green: 0x14 / 255, blue: 0x2E / 255)
    static let ink = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let inkMuted = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
    static let canvas = Color(red: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let card = Color.white
    static let hairline = Color(red: 0xE1 / 255, green: 0xE4 / 255, blue: 0xE8 / 255)
    static let gain = Color(red: 0x0E / 255, green: 0x8A / 255, blue: 0x3E / 255)
    static let loss = Color(red: 0xC6 / 255, green: 0x1F / 255, blue: 0x2E / 255)

    static let uiRed = UIColor(red: 0xD6 / 255, green: 0x00 / 255, blue: 0x2A / 255, alpha: 1)
    static let uiNavy = UIColor(red: 0x0A / 255, green: 0x1F / 255, blue: 0x44 / 255, alpha: 1)

    static let cornerRadius: CGFloat = 12

    static func numeric(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }

    static func color(forChange change: Double) -> Color {
        change < 0 ? loss : gain
    }
}

/// "S&P Global · Capital IQ Pro" wordmark.
struct CapitalIQWordmark: View {
    var size: CGFloat = 20
    var onDark = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("S&P Global")
                .font(.system(size: size, weight: .heavy))
                .foregroundColor(onDark ? .white : CapitalIQTheme.ink)
            Rectangle()
                .fill(CapitalIQTheme.red)
                .frame(width: 2, height: size * 0.9)
            Text("Capital IQ Pro")
                .font(.system(size: size * 0.85, weight: .regular))
                .foregroundColor(onDark ? Color.white.opacity(0.9) : CapitalIQTheme.inkMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("S&P Global Capital IQ Pro")
    }
}

/// Signed, colored price change such as "+1.24 (+0.86%)".
struct PriceChangeText: View {
    let change: Double
    let percent: Double
    var font: Font = CapitalIQTheme.numeric(14, weight: .semibold)

    var body: some View {
        Text(PriceFormatter.change(change, percent: percent))
            .font(font)
            .foregroundColor(CapitalIQTheme.color(forChange: change))
    }
}

struct CapitalIQCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CapitalIQTheme.card)
            .cornerRadius(CapitalIQTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CapitalIQTheme.cornerRadius)
                    .stroke(CapitalIQTheme.hairline, lineWidth: 1)
            )
    }
}

struct CapitalIQSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(CapitalIQTheme.inkMuted)
    }
}

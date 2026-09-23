//
//  LillyTheme.swift
//  nightguard
//
//  Visual language for the Lilly Health™-style shell: Lilly red, serif display
//  type, warm paper backgrounds and pill buttons.
//

import SwiftUI
import UIKit

enum LillyTheme {

    static let red = Color(red: 0xD5 / 255, green: 0x2B / 255, blue: 0x1E / 255)
    static let redSoft = Color(red: 0xF6 / 255, green: 0xC9 / 255, blue: 0xC4 / 255)
    static let ink = Color(red: 0x1D / 255, green: 0x1D / 255, blue: 0x1F / 255)
    static let inkMuted = Color(red: 0x6B / 255, green: 0x6B / 255, blue: 0x70 / 255)
    static let paper = Color(red: 0xF7 / 255, green: 0xF6 / 255, blue: 0xF3 / 255)
    static let card = Color.white
    static let hairline = Color(red: 0xE6 / 255, green: 0xE4 / 255, blue: 0xDF / 255)
    static let zepboundGreen = Color(red: 0x5B / 255, green: 0xA8 / 255, blue: 0x3C / 255)
    static let heroTop = Color(red: 0x1F / 255, green: 0x2A / 255, blue: 0x3C / 255)
    static let heroBottom = Color(red: 0x0B / 255, green: 0x0F / 255, blue: 0x17 / 255)

    static let uiRed = UIColor(red: 0xD5 / 255, green: 0x2B / 255, blue: 0x1E / 255, alpha: 1)

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let cornerRadius: CGFloat = 18
}

/// "Lilly Health™" wordmark — the red script "Lilly" next to a plain "Health".
struct LillyWordmark: View {
    var size: CGFloat = 22
    var onDark = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Lilly")
                .font(.system(size: size * 1.15, weight: .bold, design: .serif))
                .italic()
                .foregroundColor(onDark ? .white : LillyTheme.red)
            Text("Health™")
                .font(.system(size: size, weight: .medium, design: .default))
                .foregroundColor(onDark ? .white : LillyTheme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lilly Health")
    }
}

/// "zepbound (tirzepatide) injection" product wordmark.
struct ZepboundWordmark: View {
    var onDark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Text("zepbound")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(onDark ? .white : LillyTheme.zepboundGreen)
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(LillyTheme.zepboundGreen)
            }
            Text("(tirzepatide) injection")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(onDark ? Color.white.opacity(0.8) : LillyTheme.inkMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zepbound, tirzepatide injection")
    }
}

struct LillyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LillyTheme.body(15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Capsule().fill(LillyTheme.red.opacity(configuration.isPressed ? 0.75 : 1)))
    }
}

struct LillyOutlineButtonStyle: ButtonStyle {
    var onDark = false

    func makeBody(configuration: Configuration) -> some View {
        let tint: Color = onDark ? .white : LillyTheme.ink
        return configuration.label
            .font(LillyTheme.body(15, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .overlay(Capsule().stroke(tint.opacity(configuration.isPressed ? 0.5 : 1), lineWidth: 1.5))
    }
}

struct LillyCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LillyTheme.cornerRadius, style: .continuous)
                    .fill(LillyTheme.card)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
}

struct LillySectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(LillyTheme.body(11, weight: .semibold))
            .kerning(1.1)
            .foregroundColor(LillyTheme.inkMuted)
    }
}

/// Trends / Entries style segmented control with a red selected pill.
struct LillySegmentedControl<Segment: Hashable>: View {
    let segments: [(Segment, String)]
    @Binding var selection: Segment

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments, id: \.0) { item in
                let selected = item.0 == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = item.0 }
                } label: {
                    Text(item.1)
                        .font(LillyTheme.body(14, weight: .semibold))
                        .foregroundColor(selected ? .white : LillyTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(selected ? LillyTheme.red : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white).overlay(Capsule().stroke(LillyTheme.hairline)))
    }
}

/// Seven-day strip (SUN … SAT) with the selected day in a red disc.
struct LillyWeekStrip: View {
    @Binding var selectedDay: Date
    var markedDays: Set<Date> = []

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shift(by: -7) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                Text(selectedDay, format: .dateTime.month(.wide).day().year())
                    .font(LillyTheme.body(15, weight: .semibold))
                    .foregroundColor(LillyTheme.ink)
                Spacer()
                Button { shift(by: 7) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundColor(LillyTheme.ink)
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                    let isToday = calendar.isDateInToday(day)
                    let isFuture = day > Date()
                    VStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.abbreviated))
                            .font(LillyTheme.body(10, weight: .semibold))
                            .foregroundColor(LillyTheme.inkMuted)
                            .textCase(.uppercase)
                        ZStack {
                            Circle()
                                .fill(isSelected ? LillyTheme.red : Color.clear)
                                .frame(width: 32, height: 32)
                            Text(day, format: .dateTime.day())
                                .font(LillyTheme.body(15, weight: isSelected || isToday ? .bold : .regular))
                                .foregroundColor(isSelected ? .white : (isFuture ? LillyTheme.inkMuted.opacity(0.5) : LillyTheme.ink))
                        }
                        Circle()
                            .fill(markedDays.contains(calendar.startOfDay(for: day)) ? LillyTheme.red : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isFuture else { return }
                        selectedDay = day
                    }
                }
            }
        }
    }

    private func shift(by days: Int) {
        if let shifted = calendar.date(byAdding: .day, value: days, to: selectedDay), shifted <= Date() {
            selectedDay = shifted
        }
    }
}

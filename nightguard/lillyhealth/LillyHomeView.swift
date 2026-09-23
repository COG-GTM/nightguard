//
//  LillyHomeView.swift
//  nightguard
//
//  Personalized "Today" dashboard: dosing-day hero, daily entry chips, today's
//  totals and the entry streak.
//

import SwiftUI

enum LillyLogSheet: Identifiable {
    case medication, weight, food, activity, sleep, glucose

    var id: Int { hashValue }
}

struct LillyHomeView: View {

    @Binding var selectedTab: LillyTab
    @EnvironmentObject private var store: HealthLogStore
    @State private var activeSheet: LillyLogSheet?
    @State private var heroDismissed = false

    private let today = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if !heroDismissed {
                        dosingHero
                    }
                    dailyEntries
                    todaySummary
                    progress
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(LillyTheme.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $activeSheet) { sheet in
            LillyLogSheetHost(sheet: sheet)
                .environmentObject(store)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            LillyWordmark(size: 22)
            Spacer()
            Button {
                selectedTab = .more
            } label: {
                ZStack {
                    Circle().fill(LillyTheme.redSoft).frame(width: 38, height: 38)
                    Text("AM")
                        .font(LillyTheme.body(13, weight: .bold))
                        .foregroundColor(LillyTheme.red)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.top, 12)
    }

    private var dosingHero: some View {
        let dosingDay = store.isDosingDay(today)
        return VStack(alignment: .leading, spacing: 14) {
            ZepboundWordmark(onDark: true)
            Text(dosingDay ? "Today is your dosing day" : "Next dose \(nextDoseText)")
                .font(LillyTheme.display(30, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(dosingDay
                 ? "Log your dose to help keep you on track with your weight loss journey."
                 : "You are on track. Your last dose was \(store.lastDose?.doseMg.mgString ?? "—").")
                .font(LillyTheme.body(15))
                .foregroundColor(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Log Dose") { activeSheet = .medication }
                    .buttonStyle(LillyPrimaryButtonStyle())
                Button("Dismiss") { withAnimation { heroDismissed = true } }
                    .buttonStyle(LillyOutlineButtonStyle(onDark: true))
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LillyTheme.cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [LillyTheme.heroTop, LillyTheme.heroBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 260, height: 260)
                        .offset(x: 140, y: -120)
                        .clipShape(RoundedRectangle(cornerRadius: LillyTheme.cornerRadius, style: .continuous))
                )
        )
    }

    private var nextDoseText: String {
        guard let next = store.nextDoseDate else { return "today" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: today),
                                                   to: Calendar.current.startOfDay(for: next)).day ?? 0
        if days == 1 { return "tomorrow" }
        return "in \(days) days"
    }

    private var dailyEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            LillySectionLabel("Daily entries")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    entryChip("Weight", systemImage: "scalemass", sheet: .weight)
                    entryChip("Sleep", systemImage: "moon.zzz", sheet: .sleep)
                    entryChip("Food", systemImage: "fork.knife", sheet: .food)
                    entryChip("Activity", systemImage: "figure.walk", sheet: .activity)
                    entryChip("Blood Glucose", systemImage: "drop", sheet: .glucose)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func entryChip(_ title: String, systemImage: String, sheet: LillyLogSheet) -> some View {
        Button {
            activeSheet = sheet
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(LillyTheme.body(14, weight: .semibold))
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(LillyTheme.red)
            }
            .foregroundColor(LillyTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white).overlay(Capsule().stroke(LillyTheme.hairline)))
        }
        .buttonStyle(.plain)
    }

    private var todaySummary: some View {
        let calories = store.calories(on: today)
        let target = max(store.calorieTarget, 1)
        let ratio = min(Double(calories) / Double(target), 1)
        return VStack(alignment: .leading, spacing: 12) {
            LillySectionLabel("Today")
            LillyCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Calories")
                            .font(LillyTheme.body(15, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Spacer()
                        Text("\(calories)")
                            .font(LillyTheme.display(24, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Text("/ \(store.calorieTarget) cal")
                            .font(LillyTheme.body(13))
                            .foregroundColor(LillyTheme.inkMuted)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(LillyTheme.hairline)
                            Capsule().fill(LillyTheme.red).frame(width: proxy.size.width * ratio)
                        }
                    }
                    .frame(height: 8)
                    Divider()
                    HStack(spacing: 0) {
                        summaryStat(value: "\(store.activeMinutes(on: today))", unit: "active min", label: "Activity")
                        Divider().frame(height: 36)
                        summaryStat(value: store.weight(on: today).map { $0.pounds.cleanValue } ?? "—", unit: "lbs", label: "Weight")
                        Divider().frame(height: 36)
                        summaryStat(value: store.sleep(on: today).map { $0.hours.cleanValue } ?? "—", unit: "hrs", label: "Sleep")
                    }
                }
            }
        }
    }

    private func summaryStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(LillyTheme.display(20, weight: .semibold))
                    .foregroundColor(LillyTheme.ink)
                Text(unit)
                    .font(LillyTheme.body(11))
                    .foregroundColor(LillyTheme.inkMuted)
            }
            Text(label)
                .font(LillyTheme.body(12))
                .foregroundColor(LillyTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var progress: some View {
        let streak = store.entryStreak(asOf: today)
        return VStack(alignment: .leading, spacing: 12) {
            LillySectionLabel("Your progress")
            LillyCard {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle().fill(LillyTheme.redSoft).frame(width: 46, height: 46)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(LillyTheme.red)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .font(LillyTheme.display(24, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Text("Entry streak. Keep logging to see how your habits and your weight move together.")
                            .font(LillyTheme.body(13))
                            .foregroundColor(LillyTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        streakWeek
                            .padding(.top, 6)
                    }
                }
            }
            if let latest = store.latestWeight, let start = store.startingWeight {
                LillyCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight")
                                .font(LillyTheme.body(13, weight: .semibold))
                                .foregroundColor(LillyTheme.inkMuted)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(latest.pounds.cleanValue)
                                    .font(LillyTheme.display(28, weight: .semibold))
                                    .foregroundColor(LillyTheme.ink)
                                Text("lbs")
                                    .font(LillyTheme.body(13))
                                    .foregroundColor(LillyTheme.inkMuted)
                            }
                            Text("\((start.pounds - latest.pounds).cleanValue) lbs since \(start.date.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(LillyTheme.body(13))
                                .foregroundColor(LillyTheme.inkMuted)
                        }
                        Spacer()
                        Button("Log Weight") { activeSheet = .weight }
                            .buttonStyle(LillyOutlineButtonStyle())
                    }
                }
            }
        }
    }

    private var streakWeek: some View {
        let calendar = Calendar.current
        let days = store.daysWithEntries
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let week = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        return HStack(spacing: 8) {
            ForEach(week, id: \.self) { day in
                let logged = days.contains(calendar.startOfDay(for: day))
                VStack(spacing: 4) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(LillyTheme.body(10, weight: .semibold))
                        .foregroundColor(LillyTheme.inkMuted)
                    ZStack {
                        Circle()
                            .fill(logged ? LillyTheme.red : Color.clear)
                            .overlay(Circle().stroke(logged ? LillyTheme.red : LillyTheme.hairline, lineWidth: 1.5))
                            .frame(width: 22, height: 22)
                        if logged {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Demo build. Logbook entries are stored on this device only and are not medical advice. Blood glucose values come from your Nightscout site.")
            .font(LillyTheme.body(11))
            .foregroundColor(LillyTheme.inkMuted)
            .padding(.top, 8)
    }
}

/// Routes a `LillyLogSheet` to the matching entry form (or the Nightscout glucose screen).
struct LillyLogSheetHost: View {
    let sheet: LillyLogSheet

    var body: some View {
        switch sheet {
        case .medication:
            LogMedicationView()
        case .weight:
            LogWeightView()
        case .food:
            LogFoodView()
        case .activity:
            LogActivityView()
        case .sleep:
            LogSleepView()
        case .glucose:
            MainView()
                .preferredColorScheme(.dark)
        }
    }
}

//
//  LillyLogbookView.swift
//  nightguard
//
//  Logbook with Trends (dose + weight charts) and Entries (per-day food,
//  medication, weight, activity and sleep cards).
//

import SwiftUI

struct LillyLogbookView: View {

    enum Mode: Hashable {
        case trends, entries
    }

    @EnvironmentObject private var store: HealthLogStore
    @State private var mode: Mode = .entries
    @State private var selectedDay = Date()
    @State private var activeSheet: LillyLogSheet?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Logbook")
                        .font(LillyTheme.display(30, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    LillySegmentedControl(segments: [(Mode.trends, "Trends"), (Mode.entries, "Entries")], selection: $mode)

                    if mode == .entries {
                        LillyWeekStrip(selectedDay: $selectedDay, markedDays: store.daysWithEntries)
                            .padding(.vertical, 4)
                        entries
                    } else {
                        trends
                    }
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

    // MARK: - Entries

    private var entries: some View {
        VStack(spacing: 14) {
            foodCard
            medicationCard
            weightCard
            activityCard
            sleepCard
        }
    }

    private var foodCard: some View {
        let items = store.food(on: selectedDay)
        return entryCard(title: "Food", systemImage: "fork.knife", sheet: .food) {
            if items.isEmpty {
                emptyRow("Track your meals")
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(LillyTheme.body(15, weight: .medium))
                                    .foregroundColor(LillyTheme.ink)
                                Text("\(item.meal.title) · \(item.date.formatted(.dateTime.hour().minute()))")
                                    .font(LillyTheme.body(12))
                                    .foregroundColor(LillyTheme.inkMuted)
                            }
                            Spacer()
                            Text("\(item.calories) cal")
                                .font(LillyTheme.body(14, weight: .semibold))
                                .foregroundColor(LillyTheme.ink)
                        }
                        .padding(.vertical, 10)
                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                    Divider()
                    HStack {
                        Text("Total")
                            .font(LillyTheme.body(13, weight: .semibold))
                            .foregroundColor(LillyTheme.inkMuted)
                        Spacer()
                        Text("\(store.calories(on: selectedDay)) cal")
                            .font(LillyTheme.body(14, weight: .bold))
                            .foregroundColor(LillyTheme.ink)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    private var medicationCard: some View {
        let items = store.medications(on: selectedDay)
        return entryCard(title: "Medication", systemImage: "syringe", sheet: .medication) {
            if items.isEmpty {
                emptyRow("No dose recorded")
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.medication) \(item.doseMg.mgString)")
                                .font(LillyTheme.body(15, weight: .medium))
                                .foregroundColor(LillyTheme.ink)
                            Text("\(item.injectionSite) · \(item.date.formatted(.dateTime.hour().minute()))")
                                .font(LillyTheme.body(12))
                                .foregroundColor(LillyTheme.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(LillyTheme.zepboundGreen)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var weightCard: some View {
        entryCard(title: "Weight", systemImage: "scalemass", sheet: .weight) {
            if let weight = store.weight(on: selectedDay) {
                valueRow(value: weight.pounds.cleanValue, unit: "lbs", time: weight.date)
            } else {
                emptyRow("Track your weight")
            }
        }
    }

    private var activityCard: some View {
        let items = store.activities(on: selectedDay)
        return entryCard(title: "Activity", systemImage: "figure.walk", sheet: .activity) {
            if items.isEmpty {
                emptyRow("Track your movement")
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(LillyTheme.body(15, weight: .medium))
                                .foregroundColor(LillyTheme.ink)
                            Text(item.date, format: .dateTime.hour().minute())
                                .font(LillyTheme.body(12))
                                .foregroundColor(LillyTheme.inkMuted)
                        }
                        Spacer()
                        Text("\(item.minutes) min")
                            .font(LillyTheme.body(14, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var sleepCard: some View {
        entryCard(title: "Sleep", systemImage: "moon.zzz", sheet: .sleep) {
            if let sleep = store.sleep(on: selectedDay) {
                valueRow(value: sleep.hours.cleanValue, unit: "hrs", time: sleep.date)
            } else {
                emptyRow("Track your sleep")
            }
        }
    }

    private func entryCard<Content: View>(title: String, systemImage: String, sheet: LillyLogSheet,
                                          @ViewBuilder content: @escaping () -> Content) -> some View {
        LillyCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(LillyTheme.red)
                        .frame(width: 22)
                    Text(title)
                        .font(LillyTheme.body(16, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                    Spacer()
                    Button {
                        activeSheet = sheet
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                            Text("Enter")
                        }
                        .font(LillyTheme.body(13, weight: .semibold))
                        .foregroundColor(LillyTheme.red)
                    }
                    .buttonStyle(.plain)
                }
                content()
            }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(LillyTheme.body(14))
            .foregroundColor(LillyTheme.inkMuted)
            .padding(.vertical, 4)
    }

    private func valueRow(value: String, unit: String, time: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(LillyTheme.display(26, weight: .semibold))
                .foregroundColor(LillyTheme.ink)
            Text(unit)
                .font(LillyTheme.body(13))
                .foregroundColor(LillyTheme.inkMuted)
            Spacer()
            Text(time, format: .dateTime.hour().minute())
                .font(LillyTheme.body(12))
                .foregroundColor(LillyTheme.inkMuted)
        }
    }

    // MARK: - Trends

    private var trends: some View {
        VStack(spacing: 14) {
            doseTrend
            weightTrend
            calorieTrend
        }
    }

    private var doseTrend: some View {
        let doses = store.doseHistory(weeks: 12)
        let maxDose = ZepboundDose.strengthsMg.last ?? 15
        return LillyCard {
            VStack(alignment: .leading, spacing: 12) {
                LillySectionLabel("Dose")
                if let last = store.lastDose {
                    Text("Last entered dose \(last.doseMg.mgString)")
                        .font(LillyTheme.body(15, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                    Text(last.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(LillyTheme.body(12))
                        .foregroundColor(LillyTheme.inkMuted)
                } else {
                    Text("No doses logged yet")
                        .font(LillyTheme.body(15, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(doses) { dose in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(dose.id == store.lastDose?.id ? LillyTheme.red : LillyTheme.redSoft)
                                .frame(height: max(8, CGFloat(dose.doseMg / maxDose) * 110))
                            Text(dose.date, format: .dateTime.day())
                                .font(LillyTheme.body(9))
                                .foregroundColor(LillyTheme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 130, alignment: .bottom)
                .padding(.top, 8)
            }
        }
    }

    private var weightTrend: some View {
        let history = store.weightHistory(days: 90)
        return LillyCard {
            VStack(alignment: .leading, spacing: 12) {
                LillySectionLabel("Weight")
                if let latest = store.latestWeight {
                    Text("Last entered weight \(latest.pounds.cleanValue) lbs")
                        .font(LillyTheme.body(15, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                    Text(latest.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(LillyTheme.body(12))
                        .foregroundColor(LillyTheme.inkMuted)
                } else {
                    Text("No weight logged yet")
                        .font(LillyTheme.body(15, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                }
                LillyLineChart(values: history.map { $0.pounds })
                    .frame(height: 120)
                    .padding(.top, 8)
                HStack {
                    if let first = history.first {
                        Text(first.date, format: .dateTime.month(.abbreviated).day())
                    }
                    Spacer()
                    if let last = history.last {
                        Text(last.date, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(LillyTheme.body(10))
                .foregroundColor(LillyTheme.inkMuted)
            }
        }
    }

    private var calorieTrend: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let target = max(store.calorieTarget, 1)
        return LillyCard {
            VStack(alignment: .leading, spacing: 12) {
                LillySectionLabel("Calories")
                Text("Daily target \(store.calorieTarget) cal")
                    .font(LillyTheme.body(15, weight: .semibold))
                    .foregroundColor(LillyTheme.ink)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let calories = store.calories(on: day)
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(calories > target ? LillyTheme.red : LillyTheme.ink.opacity(0.75))
                                .frame(height: max(4, CGFloat(min(Double(calories) / Double(target), 1.2)) * 90))
                            Text(day, format: .dateTime.weekday(.narrow))
                                .font(LillyTheme.body(10))
                                .foregroundColor(LillyTheme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120, alignment: .bottom)
            }
        }
    }
}

/// Minimal line chart (no Swift Charts — the app targets iOS 15).
struct LillyLineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let minValue = (values.min() ?? 0) - 1
            let maxValue = (values.max() ?? 1) + 1
            let span = max(maxValue - minValue, 1)
            let points: [CGPoint] = values.enumerated().map { index, value in
                let x = values.count > 1 ? width * CGFloat(index) / CGFloat(values.count - 1) : width / 2
                let y = height - CGFloat((value - minValue) / span) * height
                return CGPoint(x: x, y: y)
            }
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [LillyTheme.red.opacity(0.25), LillyTheme.red.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(LillyTheme.red, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                if let last = points.last {
                    Circle()
                        .fill(LillyTheme.red)
                        .frame(width: 10, height: 10)
                        .position(last)
                }
            }
        }
    }
}

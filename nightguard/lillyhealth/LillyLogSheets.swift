//
//  LillyLogSheets.swift
//  nightguard
//
//  Entry forms for medication, weight, food, activity and sleep.
//

import SwiftUI

/// Shared chrome for the log sheets: serif title, Cancel button, paper background.
private struct LillySheetScaffold<Content: View>: View {
    let title: String
    let primaryTitle: String
    let primaryEnabled: Bool
    let onPrimary: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content()
                    Button(primaryTitle, action: onPrimary)
                        .buttonStyle(LillyPrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(!primaryEnabled)
                        .opacity(primaryEnabled ? 1 : 0.5)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(LillyTheme.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(LillyTheme.display(20, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(LillyTheme.red)
                }
            }
        }
        .navigationViewStyle(.stack)
        .accentColor(LillyTheme.red)
    }
}

private struct LillyFieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(LillyTheme.body(11, weight: .semibold))
            .kerning(1.0)
            .foregroundColor(LillyTheme.inkMuted)
    }
}

private struct LillyDateField: View {
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LillyFieldLabel("When")
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }
}

// MARK: - Medication

struct LogMedicationView: View {
    @EnvironmentObject private var store: HealthLogStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var date = Date()
    @State private var doseMg: Double = ZepboundDose.strengthsMg[0]
    @State private var site = ZepboundDose.injectionSites[0]

    var body: some View {
        LillySheetScaffold(title: "Log Medication", primaryTitle: "Log Dose", primaryEnabled: true, onPrimary: save) {
            LillyCard {
                VStack(alignment: .leading, spacing: 14) {
                    ZepboundWordmark()
                    if let last = store.lastDose {
                        Text("Last dose on \(last.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · \(last.doseMg.mgString)")
                            .font(LillyTheme.body(13))
                            .foregroundColor(LillyTheme.inkMuted)
                    } else {
                        Text("No dose logged yet")
                            .font(LillyTheme.body(13))
                            .foregroundColor(LillyTheme.inkMuted)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "syringe")
                        Text("Single-Dose Pen")
                    }
                    .font(LillyTheme.body(13, weight: .semibold))
                    .foregroundColor(LillyTheme.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LillyFieldLabel("Dose")
                HStack(spacing: 8) {
                    ForEach(ZepboundDose.strengthsMg, id: \.self) { strength in
                        let selected = strength == doseMg
                        Button {
                            doseMg = strength
                        } label: {
                            Text(strength.cleanValue)
                                .font(LillyTheme.body(14, weight: .semibold))
                                .foregroundColor(selected ? .white : LillyTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selected ? LillyTheme.red : Color.white)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LillyTheme.hairline))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("mg, once weekly")
                    .font(LillyTheme.body(12))
                    .foregroundColor(LillyTheme.inkMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                LillyFieldLabel("Injection site")
                Picker("Injection site", selection: $site) {
                    ForEach(ZepboundDose.injectionSites, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            }

            LillyDateField(date: $date)
        }
        .onAppear {
            if let last = store.lastDose {
                doseMg = last.doseMg
            }
        }
    }

    private func save() {
        store.log(MedicationEntry(date: date, medication: ZepboundDose.productName, doseMg: doseMg, injectionSite: site))
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Weight

struct LogWeightView: View {
    @EnvironmentObject private var store: HealthLogStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var date = Date()
    @State private var pounds: Double = 0

    var body: some View {
        LillySheetScaffold(title: "Log Weight", primaryTitle: "Save Weight", primaryEnabled: pounds > 0, onPrimary: save) {
            LillyCard {
                VStack(alignment: .leading, spacing: 8) {
                    LillyFieldLabel("Weight")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("0", value: $pounds, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .font(LillyTheme.display(40, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Text("lbs")
                            .font(LillyTheme.body(16))
                            .foregroundColor(LillyTheme.inkMuted)
                    }
                    Stepper("", value: $pounds, in: 0...800, step: 0.2)
                        .labelsHidden()
                }
            }
            LillyDateField(date: $date)
        }
        .onAppear {
            if pounds == 0, let latest = store.latestWeight {
                pounds = latest.pounds
            }
        }
    }

    private func save() {
        store.log(WeightEntry(date: date, pounds: (pounds * 10).rounded() / 10))
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Food

struct LogFoodView: View {
    @EnvironmentObject private var store: HealthLogStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var date = Date()
    @State private var name = ""
    @State private var calories: Int = 0
    @State private var meal: MealType = .lunch

    var body: some View {
        LillySheetScaffold(title: "Log Food", primaryTitle: "Save Meal",
                           primaryEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty && calories > 0,
                           onPrimary: save) {
            LillyCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        LillyFieldLabel("What did you eat?")
                        TextField("Grilled chicken salad", text: $name)
                            .font(LillyTheme.body(17))
                            .foregroundColor(LillyTheme.ink)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        LillyFieldLabel("Calories")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", value: $calories, format: .number)
                                .keyboardType(.numberPad)
                                .font(LillyTheme.display(32, weight: .semibold))
                                .foregroundColor(LillyTheme.ink)
                            Text("cal")
                                .font(LillyTheme.body(15))
                                .foregroundColor(LillyTheme.inkMuted)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                LillyFieldLabel("Meal")
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            LillyDateField(date: $date)
        }
        .onAppear { meal = MealType.suggested(for: date) }
    }

    private func save() {
        store.log(FoodEntry(date: date, name: name.trimmingCharacters(in: .whitespaces), calories: calories, meal: meal))
        presentationMode.wrappedValue.dismiss()
    }
}

extension MealType {
    static func suggested(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

// MARK: - Activity

struct LogActivityView: View {
    @EnvironmentObject private var store: HealthLogStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var date = Date()
    @State private var name = ""
    @State private var minutes: Int = 30

    private let suggestions = ["Walk", "Run", "Cycling", "Strength Training", "Yoga", "Swimming"]

    var body: some View {
        LillySheetScaffold(title: "Log Activity", primaryTitle: "Save Activity",
                           primaryEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty && minutes > 0,
                           onPrimary: save) {
            LillyCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        LillyFieldLabel("Activity")
                        TextField("Morning walk", text: $name)
                            .font(LillyTheme.body(17))
                            .foregroundColor(LillyTheme.ink)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) { name = suggestion }
                                    .font(LillyTheme.body(13, weight: .semibold))
                                    .foregroundColor(name == suggestion ? .white : LillyTheme.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(name == suggestion ? LillyTheme.red : LillyTheme.paper))
                            }
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        LillyFieldLabel("Duration")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(minutes)")
                                .font(LillyTheme.display(32, weight: .semibold))
                                .foregroundColor(LillyTheme.ink)
                            Text("min")
                                .font(LillyTheme.body(15))
                                .foregroundColor(LillyTheme.inkMuted)
                            Spacer()
                            Stepper("", value: $minutes, in: 5...300, step: 5)
                                .labelsHidden()
                        }
                    }
                }
            }
            LillyDateField(date: $date)
        }
    }

    private func save() {
        store.log(ActivityEntry(date: date, name: name.trimmingCharacters(in: .whitespaces), minutes: minutes))
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Sleep

struct LogSleepView: View {
    @EnvironmentObject private var store: HealthLogStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var date = Date()
    @State private var hours: Double = 7.5

    var body: some View {
        LillySheetScaffold(title: "Log Sleep", primaryTitle: "Save Sleep", primaryEnabled: hours > 0, onPrimary: save) {
            LillyCard {
                VStack(alignment: .leading, spacing: 8) {
                    LillyFieldLabel("Hours slept")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(hours.cleanValue)
                            .font(LillyTheme.display(40, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Text("hrs")
                            .font(LillyTheme.body(16))
                            .foregroundColor(LillyTheme.inkMuted)
                    }
                    Slider(value: $hours, in: 0...14, step: 0.5)
                        .accentColor(LillyTheme.red)
                }
            }
            LillyDateField(date: $date)
        }
    }

    private func save() {
        store.log(SleepEntry(date: date, hours: hours))
        presentationMode.wrappedValue.dismiss()
    }
}

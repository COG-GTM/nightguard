//
//  LillyCareView.swift
//  nightguard
//
//  Care: medicine schedule, savings and support, plus the Nightscout care
//  actions (temporary targets, carb corrections) that ship with nightguard.
//

import SwiftUI

struct LillyCareView: View {

    @EnvironmentObject private var store: HealthLogStore
    @State private var showMedicationSheet = false
    @State private var showNightscoutCare = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Care")
                        .font(LillyTheme.display(30, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    medicine
                    savings
                    support
                    nightscout
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(LillyTheme.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showMedicationSheet) {
            LogMedicationView().environmentObject(store)
        }
        .sheet(isPresented: $showNightscoutCare) {
            CareView(selectedTab: .constant(.care))
                .preferredColorScheme(.dark)
        }
    }

    private var medicine: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("My medicine")
            LillyCard {
                VStack(alignment: .leading, spacing: 14) {
                    ZepboundWordmark()
                    HStack(spacing: 0) {
                        careStat(label: "Current dose", value: store.lastDose?.doseMg.mgString ?? "—")
                        Divider().frame(height: 36)
                        careStat(label: "Next dose", value: store.nextDoseDate.map { nextDoseLabel($0) } ?? "Today")
                        Divider().frame(height: 36)
                        careStat(label: "Doses logged", value: "\(store.medications.count)")
                    }
                    Button("Log Dose") { showMedicationSheet = true }
                        .buttonStyle(LillyPrimaryButtonStyle())
                }
            }
        }
    }

    private func nextDoseLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || date < Date() { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func careStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(LillyTheme.display(18, weight: .semibold))
                .foregroundColor(LillyTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(LillyTheme.body(11))
                .foregroundColor(LillyTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private var savings: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("Savings")
            LillyCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(LillyTheme.redSoft).frame(width: 46, height: 46)
                        Image(systemName: "creditcard")
                            .foregroundColor(LillyTheme.red)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zepbound Savings Card")
                            .font(LillyTheme.body(15, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Text("See if you are eligible to pay as little as $25 for a 1- or 3-month prescription.")
                            .font(LillyTheme.body(13))
                            .foregroundColor(LillyTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(LillyTheme.inkMuted)
                }
            }
        }
    }

    private var support: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("Support")
            LillyCard(padding: 0) {
                VStack(spacing: 0) {
                    supportRow("Talk to a Lilly representative", systemImage: "phone")
                    Divider().padding(.leading, 56)
                    supportRow("Injection training videos", systemImage: "play.rectangle")
                    Divider().padding(.leading, 56)
                    supportRow("Share a report with your care team", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func supportRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundColor(LillyTheme.red)
                .frame(width: 26)
            Text(title)
                .font(LillyTheme.body(15, weight: .medium))
                .foregroundColor(LillyTheme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(LillyTheme.inkMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var nightscout: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("Nightscout")
            LillyCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.black).frame(width: 46, height: 46)
                        Image(systemName: "drop.fill")
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Temporary targets & carbs")
                            .font(LillyTheme.body(15, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                        Text("Send a temporary glucose target or a carb correction to your Nightscout site.")
                            .font(LillyTheme.body(13))
                            .foregroundColor(LillyTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(LillyTheme.inkMuted)
                }
                .contentShape(Rectangle())
                .onTapGesture { showNightscoutCare = true }
            }
        }
    }
}

//
//  LillyMoreView.swift
//  nightguard
//
//  More: profile, goals and the original nightguard screens (glucose, alarms,
//  statistics, duration, preferences).
//

import SwiftUI

struct LillyMoreView: View {

    fileprivate enum Screen: Identifiable {
        case glucose, alarms, stats, duration, prefs

        var id: Int { hashValue }
    }

    @EnvironmentObject private var store: HealthLogStore
    @State private var activeScreen: Screen?
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("More")
                        .font(LillyTheme.display(30, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    profile
                    goals
                    nightguardScreens
                    about
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(LillyTheme.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(item: $activeScreen) { screen in
            NightguardScreenHost(screen: screen.rawView)
        }
        .alert(isPresented: $showResetConfirmation) {
            Alert(
                title: Text("Clear logbook?"),
                message: Text("Removes every food, weight, activity, sleep and medication entry stored on this device."),
                primaryButton: .destructive(Text("Clear")) { store.removeAll() },
                secondaryButton: .cancel()
            )
        }
    }

    private var profile: some View {
        LillyCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(LillyTheme.redSoft).frame(width: 52, height: 52)
                    Text("AM")
                        .font(LillyTheme.body(17, weight: .bold))
                        .foregroundColor(LillyTheme.red)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Amit")
                        .font(LillyTheme.display(20, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                    Text("Zepbound® · started \((store.medications.last?.date ?? Date()).formatted(.dateTime.month(.abbreviated).day()))")
                        .font(LillyTheme.body(13))
                        .foregroundColor(LillyTheme.inkMuted)
                }
                Spacer()
            }
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("Goals")
            LillyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Daily calorie target")
                            .font(LillyTheme.body(15, weight: .medium))
                            .foregroundColor(LillyTheme.ink)
                        Spacer()
                        Text("\(store.calorieTarget) cal")
                            .font(LillyTheme.body(15, weight: .semibold))
                            .foregroundColor(LillyTheme.ink)
                    }
                    Stepper("Daily calorie target", value: $store.calorieTarget, in: 1000...4000, step: 50)
                        .labelsHidden()
                }
            }
        }
    }

    private var nightguardScreens: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("Blood glucose (Nightscout)")
            LillyCard(padding: 0) {
                VStack(spacing: 0) {
                    row("Glucose", systemImage: "waveform.path.ecg", screen: .glucose)
                    Divider().padding(.leading, 56)
                    row("Alarms", systemImage: "bell", screen: .alarms)
                    Divider().padding(.leading, 56)
                    row("Statistics", systemImage: "chart.bar", screen: .stats)
                    Divider().padding(.leading, 56)
                    row("Duration", systemImage: "clock", screen: .duration)
                    Divider().padding(.leading, 56)
                    row("Preferences", systemImage: "gearshape", screen: .prefs)
                }
            }
        }
    }

    private func row(_ title: String, systemImage: String, screen: Screen) -> some View {
        Button {
            activeScreen = screen
        } label: {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            LillySectionLabel("About")
            LillyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Demo build of nightguard restyled as a Lilly Health™-style companion. Logbook data is stored on this device only. Not affiliated with Eli Lilly and Company; not medical advice.")
                        .font(LillyTheme.body(13))
                        .foregroundColor(LillyTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Clear logbook") { showResetConfirmation = true }
                        .font(LillyTheme.body(14, weight: .semibold))
                        .foregroundColor(LillyTheme.red)
                }
            }
        }
    }
}

fileprivate extension LillyMoreView.Screen {
    @ViewBuilder var rawView: some View {
        switch self {
        case .glucose: MainView()
        case .alarms: AlarmView()
        case .stats: StatsView()
        case .duration: DurationView(selectedTab: .constant(.duration))
        case .prefs: PrefsView()
        }
    }
}

/// Wraps a legacy nightguard screen with a Done bar so it can be dismissed from a full-screen cover.
private struct NightguardScreenHost<Content: View>: View {
    let screen: Content
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                    .font(LillyTheme.body(16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .background(Color.black)
            screen
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

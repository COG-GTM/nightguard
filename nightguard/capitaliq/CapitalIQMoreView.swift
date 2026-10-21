//
//  CapitalIQMoreView.swift
//  nightguard
//
//  "More" tab: saved lists, settings and account. Watchlists live under
//  More › Saved Lists › Watchlists.
//

import SwiftUI

struct CapitalIQMoreView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(destination: SavedListsView()) {
                    Label("Saved Lists", systemImage: "folder")
                }
                .accessibilityIdentifier("more_saved_lists")
                NavigationLink(destination: PlaceholderScreen(title: "Saved Items", message: "Smart Download keeps your saved articles, transcripts and documents available offline.")) {
                    Label("Saved Items", systemImage: "arrow.down.circle")
                }
                NavigationLink(destination: PlaceholderScreen(title: "Manage Alerts", message: "Choose which email alerts are delivered as mobile push notifications.")) {
                    Label("Manage Alerts", systemImage: "bell")
                }
            }
            Section {
                NavigationLink(destination: CapitalIQSettingsView()) {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink(destination: PlaceholderScreen(title: "Help & Support", message: "Contact S&P Global Market Intelligence support 24/7.")) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
            }
            Section {
                Button(role: .destructive) {} label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedListsView: View {
    var body: some View {
        List {
            NavigationLink(destination: WatchlistIndexView()) {
                Label("Watchlists", systemImage: "list.star")
            }
            .accessibilityIdentifier("saved_lists_watchlists")
            NavigationLink(destination: PlaceholderScreen(title: "Screens", message: "Saved screening criteria sync from the desktop Screener.")) {
                Label("Screens", systemImage: "line.3.horizontal.decrease.circle")
            }
            NavigationLink(destination: PlaceholderScreen(title: "Saved Searches", message: "Your saved document and transcript searches.")) {
                Label("Saved Searches", systemImage: "magnifyingglass.circle")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Saved Lists")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CapitalIQSettingsView: View {
    @State private var faceID = true
    @State private var autoLock = "15 minutes"

    var body: some View {
        Form {
            Section("Security") {
                Toggle("Face ID", isOn: $faceID)
                Picker("Auto-Lock", selection: $autoLock) {
                    ForEach(["Immediately", "1 minute", "15 minutes", "1 hour"], id: \.self) { Text($0) }
                }
            }
            Section("About") {
                KeyValueRow(label: "Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlaceholderScreen: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 36)).foregroundColor(CapitalIQTheme.inkMuted)
            Text(message).font(.system(size: 15)).foregroundColor(CapitalIQTheme.inkMuted).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CapitalIQTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

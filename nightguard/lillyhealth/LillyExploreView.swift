//
//  LillyExploreView.swift
//  nightguard
//
//  Explore: health habits, knowledge hub, healthy recipes and guided movement.
//  Static editorial content for the demo shell.
//

import SwiftUI

struct LillyExploreView: View {

    private struct Article: Identifiable {
        let id = UUID()
        let category: String
        let title: String
        let subtitle: String
        let systemImage: String
        let tint: Color
    }

    private let articles: [Article] = [
        Article(category: "Learn", title: "Knowledge Hub",
                subtitle: "How Zepbound® works, what to expect week to week, and questions to bring to your care team.",
                systemImage: "book", tint: Color(red: 0xE8 / 255, green: 0xDF / 255, blue: 0xF7 / 255)),
        Article(category: "Nutrition", title: "Healthy Recipes",
                subtitle: "Protein-forward meals sized for a smaller appetite.",
                systemImage: "leaf", tint: Color(red: 0xE1 / 255, green: 0xF1 / 255, blue: 0xDD / 255)),
        Article(category: "Movement", title: "Guided Workouts",
                subtitle: "Ten-minute strength and mobility sessions to preserve muscle while you lose weight.",
                systemImage: "figure.strengthtraining.traditional", tint: Color(red: 0xFB / 255, green: 0xE7 / 255, blue: 0xD4 / 255)),
        Article(category: "Support", title: "Managing Side Effects",
                subtitle: "Practical tips for nausea, fatigue and appetite changes during titration.",
                systemImage: "heart.text.square", tint: Color(red: 0xF6 / 255, green: 0xE0 / 255, blue: 0xDE / 255)),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Explore")
                        .font(LillyTheme.display(30, weight: .semibold))
                        .foregroundColor(LillyTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    habits

                    ForEach(articles) { article in
                        VStack(alignment: .leading, spacing: 10) {
                            LillySectionLabel(article.category)
                            LillyCard(padding: 0) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ZStack {
                                        article.tint
                                        Image(systemName: article.systemImage)
                                            .font(.system(size: 40, weight: .light))
                                            .foregroundColor(LillyTheme.ink.opacity(0.7))
                                    }
                                    .frame(height: 120)
                                    .clipShape(RoundedCorners(radius: LillyTheme.cornerRadius, corners: [.topLeft, .topRight]))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(article.title)
                                            .font(LillyTheme.display(20, weight: .semibold))
                                            .foregroundColor(LillyTheme.ink)
                                        Text(article.subtitle)
                                            .font(LillyTheme.body(14))
                                            .foregroundColor(LillyTheme.inkMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(16)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(LillyTheme.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var habits: some View {
        LillyCard(padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Health Habits")
                    .font(LillyTheme.display(26, weight: .semibold))
                    .foregroundColor(LillyTheme.ink)
                Text("Set a goal to take charge of your health confidently. Small daily habits are what the logbook is built to reinforce.")
                    .font(LillyTheme.body(15))
                    .foregroundColor(LillyTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Set a Goal") {}
                    .buttonStyle(LillyPrimaryButtonStyle())
                    .padding(.top, 4)
            }
        }
    }
}

struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

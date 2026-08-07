//
//  StatisticsView.swift
//  DariApp
//
//  Uebersichtliche Darstellung der Lernkennzahlen mit Swift Charts.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {

    @Environment(AppSettings.self) private var settings
    @Query private var cards: [Card]
    @Query(sort: \ReviewLog.date, order: .reverse) private var logs: [ReviewLog]

    private var snapshot: StatisticsSnapshot {
        StatisticsCalculator.snapshot(cards: cards, logs: logs)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                metricGrid
                progressChart
                hardestCardsCard
                topTagsCard
            }
            .padding(Spacing.md)
        }
        .background(Palette.background)
        .navigationTitle("Statistik")
    }

    // MARK: - Kennzahlen

    private var metricGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.md) {
            MetricTile(title: "Karten gesamt", value: "\(snapshot.totalCards)", icon: "rectangle.stack", tint: Palette.sage)
            MetricTile(title: "Aktiv", value: "\(snapshot.activeCards)", icon: "checkmark.circle", tint: Palette.turquoise)
            MetricTile(title: "Heute gelernt", value: "\(snapshot.reviewsToday)", icon: "sun.max", tint: Palette.terracotta)
            MetricTile(title: "Serie", value: "\(snapshot.streak) Tage", icon: "flame", tint: Palette.warning)
            MetricTile(title: "Erfolgsquote", value: percent(snapshot.successRate), icon: "target", tint: Palette.sage)
            MetricTile(title: "Ø Antwortzeit", value: seconds(snapshot.averageAnswerTime), icon: "timer", tint: Palette.turquoise)
        }
    }

    // MARK: - Verlauf

    private var progressChart: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Wiederholungen (14 Tage)")
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                if snapshot.reviewsPerDay.allSatisfy({ $0.count == 0 }) {
                    emptyHint("Noch keine Lerndaten vorhanden.")
                } else {
                    Chart(snapshot.reviewsPerDay, id: \.date) { item in
                        BarMark(
                            x: .value("Tag", item.date, unit: .day),
                            y: .value("Anzahl", item.count)
                        )
                        .foregroundStyle(Palette.sage.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 160)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                        }
                    }
                }
            }
        }
    }

    private var hardestCardsCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Schwierigste Woerter")
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                if snapshot.hardestCards.isEmpty {
                    emptyHint("Noch keine gelernten Karten.")
                } else {
                    ForEach(snapshot.hardestCards) { card in
                        HStack {
                            Text(card.primaryGerman).foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(card.primaryPersian)
                                .foregroundStyle(Palette.textSecondary)
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                        .font(DariFont.body)
                    }
                }
            }
        }
    }

    private var topTagsCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Haeufigste Tags")
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                if snapshot.topTags.isEmpty {
                    emptyHint("Noch keine Tags vergeben.")
                } else {
                    FlowLayout {
                        ForEach(snapshot.topTags, id: \.name) { tag in
                            TagChip(title: "\(tag.name) (\(tag.count))")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hilfen

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(DariFont.caption)
            .foregroundStyle(Palette.textSecondary)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func seconds(_ value: TimeInterval) -> String {
        value <= 0 ? "–" : String(format: "%.1fs", value)
    }
}

// MARK: - Kachel

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        CardSurface(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                Text(value)
                    .font(DariFont.title)
                    .foregroundStyle(Palette.textPrimary)
                Text(title)
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack { StatisticsView() }
        .environment(AppSettings())
        .modelContainer(PreviewData.container)
}

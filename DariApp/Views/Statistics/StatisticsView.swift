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

    @State private var cache = SnapshotCache()

    private var snapshot: StatisticsSnapshot {
        cache.snapshot(cards: cards, logs: logs, dailyGoal: settings.dailyGoal)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                metricGrid
                levelCard
                knowledgeCard
                progressChart
                hardestCardsCard
                topTagsCard
                achievementsCard
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
            MetricTile(title: "Heute (Ziel)", value: "\(snapshot.reviewsToday)/\(snapshot.dailyGoal)", icon: "sun.max", tint: Palette.terracotta)
            MetricTile(title: "Serie", value: "\(snapshot.streak) Tage", icon: "flame", tint: Palette.warning)
            MetricTile(title: "Erfolgsquote", value: percent(snapshot.successRate), icon: "target", tint: Palette.sage)
            MetricTile(title: "Ø Antwortzeit", value: seconds(snapshot.averageAnswerTime), icon: "timer", tint: Palette.turquoise)
        }
    }

    // MARK: - Level & Wissensstand

    private var levelCard: some View {
        let level = snapshot.level
        return CardSurface {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Level \(level.level)").font(DariFont.headline).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(level.xp) XP").font(DariFont.caption).foregroundStyle(Palette.textSecondary)
                }
                ProgressView(value: level.fraction).tint(Palette.turquoise)
                Text("Noch \(level.next - level.xp) XP bis Level \(level.level + 1). Punkte gibt es fürs richtige Erinnern – mehr, wenn du schwierige Wörter meisterst.")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var knowledgeCard: some View {
        let snap = snapshot
        let total = max(snap.knownNew + snap.knownLearning + snap.knownSolid, 1)
        return CardSurface {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Wissensstand").font(DariFont.headline).foregroundStyle(Palette.textPrimary)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Palette.sage.frame(width: geo.size.width * CGFloat(snap.knownSolid) / CGFloat(total))
                        Palette.turquoise.frame(width: geo.size.width * CGFloat(snap.knownLearning) / CGFloat(total))
                        Palette.sand
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .frame(height: 14)
                HStack(spacing: Spacing.md) {
                    legend(Palette.sage, "Gefestigt \(snap.knownSolid)")
                    legend(Palette.turquoise, "Lernend \(snap.knownLearning)")
                    legend(Palette.sand, "Neu \(snap.knownNew)")
                }
            }
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).font(DariFont.caption).foregroundStyle(Palette.textSecondary)
        }
    }

    private var achievementsCard: some View {
        let snap = snapshot
        let unlocked = Gamification.achievements.filter { $0.isUnlocked(snap) }.count
        return CardSurface {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Meilensteine (\(unlocked)/\(Gamification.achievements.count))")
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3), spacing: Spacing.sm) {
                    ForEach(Gamification.achievements) { item in
                        let on = item.isUnlocked(snap)
                        VStack(spacing: 4) {
                            Image(systemName: item.icon).font(.title3).foregroundStyle(on ? Palette.sage : Palette.textSecondary)
                            Text(item.name).font(.caption2).multilineTextAlignment(.center).foregroundStyle(Palette.textPrimary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(Spacing.xs)
                        .background(on ? Palette.sage.opacity(0.18) : Palette.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
                        .opacity(on ? 1 : 0.5)
                        .accessibilityLabel("\(item.name): \(item.detail)")
                    }
                }
            }
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
                Text("Schwierigste Wörter")
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

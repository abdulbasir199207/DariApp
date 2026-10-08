//
//  TodayView.swift
//  DariApp
//
//  Startseite: zeigt Tagesziel, Serie und Level und bietet immer einen klaren
//  naechsten Schritt („Heute lernen", „Schwierige Woerter", „Weiterlernen").
//

import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(AppHealth.self) private var health

    @Query private var cards: [Card]
    @Query private var logs: [ReviewLog]
    @AppStorage("zara.lastExternalBackup") private var lastBackup: Double = 0

    @State private var launch: PracticeLaunch?
    @State private var startVocab = false
    @State private var showEditor = false

    private var snapshot: StatisticsSnapshot {
        StatisticsCalculator.snapshot(cards: cards, logs: logs, dailyGoal: settings.dailyGoal)
    }

    var body: some View {
        let snap = snapshot
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let error = health.lastSaveError { banner(error, tint: Palette.terracotta) }
                if needsBackup(snap) { backupBanner }
                goalCard(snap)
                heroButton(snap)
                Text("Weitere Möglichkeiten")
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xs)
                tiles(snap)
            }
            .padding(Spacing.md)
        }
        .background(Palette.background)
        .navigationTitle("Heute")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CatMark().frame(width: 30, height: 30)
            }
        }
        .navigationDestination(item: $launch) { PracticeSessionContainer(launch: $0) }
        .navigationDestination(isPresented: $startVocab) {
            LearnSessionView(
                configuration: LearnSessionViewModel.Configuration(
                    mode: settings.defaultMode, direction: settings.defaultDirection, limit: settings.dailyGoal),
                candidates: cards.filter(\.isActive),
                allCards: cards)
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { CardEditorView(context: context) }
        }
    }

    // MARK: Karten

    private func goalCard(_ snap: StatisticsSnapshot) -> some View {
        CardSurface {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle().stroke(Palette.surfaceSecondary, lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: snap.goalFraction)
                        .stroke(Palette.sage, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(snap.reviewsToday)/\(snap.dailyGoal)")
                        .font(DariFont.headline)
                        .foregroundStyle(Palette.textPrimary)
                }
                .frame(width: 84, height: 84)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tagesziel \(snap.reviewsToday) von \(snap.dailyGoal)")

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(snap.goalReached ? "Tagesziel erreicht!" : "Tagesziel")
                        .font(DariFont.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(snap.streak > 0
                         ? "\(snap.streak) \(snap.streak == 1 ? "Tag" : "Tage") in Folge"
                         : "Lerne heute, um eine Serie zu starten")
                        .font(DariFont.caption)
                        .foregroundStyle(Palette.textSecondary)
                    HStack {
                        Text("Level \(snap.level.level)").font(DariFont.caption.bold())
                        Text("\(snap.level.xp - snap.level.base)/\(snap.level.next - snap.level.base) XP")
                            .font(DariFont.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    ProgressView(value: snap.level.fraction).tint(Palette.turquoise)
                }
            }
        }
    }

    private func heroButton(_ snap: StatisticsSnapshot) -> some View {
        let suggestion = nextStep(snap)
        return Button {
            suggestion.action()
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(suggestion.title).font(DariFont.title)
                Text(suggestion.subtitle).font(DariFont.body).opacity(0.92)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(Palette.sage)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
            .dariShadow()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.hero")
    }

    private struct Suggestion {
        let title: String
        let subtitle: String
        let action: () -> Void
    }

    private func nextStep(_ snap: StatisticsSnapshot) -> Suggestion {
        if snap.totalCards == 0 {
            return Suggestion(title: "Erste Karte anlegen", subtitle: "Lege dein erstes Wort an – dann geht es los.") { showEditor = true }
        }
        if snap.dueCount > 0 {
            return Suggestion(title: "Heute lernen",
                              subtitle: "\(snap.dueCount) \(snap.dueCount == 1 ? "Karte ist" : "Karten sind") fällig") { startVocab = true }
        }
        if snap.weakCount > 0 {
            return Suggestion(title: "Schwierige Wörter üben",
                              subtitle: "\(snap.weakCount) Wörter brauchen noch Wiederholung") { launch = PracticeLaunch(plan: .weak, direction: settings.defaultDirection) }
        }
        return Suggestion(title: "Weiterlernen", subtitle: "Alles Fällige ist erledigt – festige weitere Wörter.") { startVocab = true }
    }

    private func tiles(_ snap: StatisticsSnapshot) -> some View {
        let columns = [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)]
        return LazyVGrid(columns: columns, spacing: Spacing.sm) {
            Button { launch = PracticeLaunch(plan: .mix, direction: settings.defaultDirection) } label: {
                PracticeTileLabel(icon: "timer", title: "5-Minuten-Spiel", subtitle: "Abwechslungsreiche Mischung", isEnabled: snap.totalCards > 0)
            }
            .disabled(snap.totalCards == 0)
            .accessibilityIdentifier("today.mix")
            Button { launch = PracticeLaunch(plan: .weak, direction: settings.defaultDirection) } label: {
                PracticeTileLabel(icon: "scope", title: "Schwierige Wörter",
                                  subtitle: snap.weakCount > 0 ? "Gezielt wiederholen" : "Noch keine – gut so!",
                                  badge: snap.weakCount, isEnabled: snap.weakCount > 0)
            }
            .disabled(snap.weakCount == 0)
            Button { launch = PracticeLaunch(plan: .cloze, direction: settings.defaultDirection) } label: {
                PracticeTileLabel(icon: "text.badge.checkmark", title: "Sätze üben", subtitle: "Lückentext mit Beispielsätzen")
            }
            NavigationLink { GrammarSetupView() } label: {
                PracticeTileLabel(icon: "character.book.closed", title: "Grammatik", subtitle: "Persisch & Deutsch")
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Hinweise

    private func needsBackup(_ snap: StatisticsSnapshot) -> Bool {
        guard snap.totalCards >= 5, snap.totalReviews >= 10 else { return false }
        return lastBackup == 0 || Date().timeIntervalSince1970 - lastBackup > 7 * 86_400
    }

    private var backupBanner: some View {
        NavigationLink { BackupView() } label: {
            HStack {
                Text(lastBackup == 0 ? "Noch kein Backup. Dein Fortschritt liegt nur auf diesem Gerät."
                                     : "Letztes Backup ist über eine Woche her.")
                    .font(DariFont.body)
                    .multilineTextAlignment(.leading)
                Spacer()
                Text("Sichern").font(DariFont.headline).foregroundStyle(Palette.warning)
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(Spacing.md)
            .background(Palette.warning.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func banner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(DariFont.body)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(tint.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environment(AppSettings())
        .environment(AppHealth.shared)
        .modelContainer(PreviewData.container)
}

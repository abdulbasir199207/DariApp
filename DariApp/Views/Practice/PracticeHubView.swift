//
//  PracticeHubView.swift
//  DariApp
//
//  „Üben": Uebersicht aller Lernformen – Vokabeln, Spiele, Saetze & Grammatik.
//  Die gewaehlte Richtung (DE→FA / FA→DE / gemischt) gilt fuer alle Uebungen.
//

import SwiftUI
import SwiftData

struct PracticeHubView: View {

    @Environment(AppSettings.self) private var settings
    @Query private var cards: [Card]

    @State private var direction: QueryDirection?
    @State private var launch: PracticeLaunch?

    private var activeCards: [Card] { cards.filter(\.isActive) }

    var body: some View {
        let speech = SpeechService.shared
        let weak = Adaptive.weakCards(cards).count
        let distinctPairs = ExerciseFactory(rng: SystemRandomNumberGenerator()).makeMatchRound(candidates: activeCards, count: 5).count
        let audioCards = activeCards.filter(\.hasAudio).count
        let anySound = speech.canSpeak(.persian) || speech.canSpeak(.german) || audioCards > 0
        let listenOK = activeCards.count >= 2 && anySound
        let speakOK = !activeCards.isEmpty && anySound

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Richtung")
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                Picker("Richtung", selection: Binding(
                    get: { direction ?? settings.defaultDirection },
                    set: { direction = $0 }
                )) {
                    ForEach(QueryDirection.allCases) { d in Text(d.title.replacingOccurrences(of: "Deutsch", with: "DE").replacingOccurrences(of: "Persisch", with: "FA")).tag(d) }
                }
                .pickerStyle(.segmented)

                section("Vokabeln") {
                    NavigationLink { LearnView() } label: {
                        PracticeTileLabel(icon: "rectangle.on.rectangle.angled", title: "Karten lernen",
                                          subtitle: "Modus, Richtung & Tags wählen", isEnabled: !activeCards.isEmpty)
                    }
                    .accessibilityIdentifier("hub.learn")
                    tile(.weak, "scope", "Schwierige Wörter", weak > 0 ? "Gezielt wiederholen" : "Noch keine – gut so!", enabled: weak > 0, badge: weak)
                }
                section("Spiele") {
                    tile(.match, "arrow.left.arrow.right", "Zuordnung", distinctPairs >= 3 ? "Wörter einander zuordnen" : "Mind. 3 Karten nötig", enabled: distinctPairs >= 3)
                    tile(.listen, "ear", "Hören", listenOK ? "Hören & Bedeutung wählen" : "Keine Sprachausgabe verfügbar", enabled: listenOK)
                    tile(.speak, "mic", "Aussprache", speakOK ? "Nachsprechen & vergleichen" : "Mikrofon/Sprachausgabe fehlt", enabled: speakOK)
                    tile(.mix, "timer", "5-Minuten-Spiel", "Abwechslungsreiche Mischung", enabled: !activeCards.isEmpty)
                }
                section("Sätze & Grammatik") {
                    tile(.cloze, "text.badge.checkmark", "Lückentext", "Fehlendes Wort einsetzen")
                    tile(.build, "arrow.left.and.right.text.vertical", "Satzbildung", "Wörter ordnen")
                    tile(.translate, "pencil.line", "Übersetzen", "Kurze Sätze schreiben")
                    NavigationLink { GrammarSetupView() } label: {
                        PracticeTileLabel(icon: "character.book.closed", title: "Grammatik", subtitle: "Persisch & Deutsch")
                    }
                    .accessibilityIdentifier("hub.grammar")
                }
                Text("Alle Übungen passen die Wiederholung an deine Fehler an.")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.sm)
            }
            .padding(Spacing.md)
        }
        .background(Palette.background)
        .navigationTitle("Üben")
        .navigationDestination(item: $launch) { PracticeSessionContainer(launch: $0) }
    }

    // MARK: Bausteine

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(DariFont.headline)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Spacing.xs)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                content()
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(_ plan: PracticePlan, _ icon: String, _ title: String, _ subtitle: String, enabled: Bool = true, badge: Int = 0) -> some View {
        Button {
            launch = PracticeLaunch(plan: plan, direction: direction ?? settings.defaultDirection)
        } label: {
            PracticeTileLabel(icon: icon, title: title, subtitle: subtitle, badge: badge, isEnabled: enabled)
        }
        .disabled(!enabled)
        .accessibilityIdentifier("hub.\(plan.id)")
    }
}

// MARK: - Grammatik-Auswahl

struct GrammarSetupView: View {

    @State private var language: ExerciseLanguage = .persian
    @State private var topic: String?
    @State private var launch: PracticeLaunch?

    private let library = ContentLibrary.shared

    private var pool: [GrammarItem] {
        library.grammar.filter { $0.exerciseLanguage == language && (topic == nil || $0.topic == topic) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Sprache").font(DariFont.headline)
                Picker("Sprache", selection: $language) {
                    Text("Persisch lernen").tag(ExerciseLanguage.persian)
                    Text("Deutsch lernen").tag(ExerciseLanguage.german)
                }
                .pickerStyle(.segmented)
                .onChange(of: language) { _, _ in topic = nil }

                Text("Thema").font(DariFont.headline).padding(.top, Spacing.xs)
                FlowLayout(spacing: Spacing.xs) {
                    Button { topic = nil } label: { TagChip(title: "Alle Themen", isSelected: topic == nil) }
                    ForEach(library.grammarTopics(for: language), id: \.self) { name in
                        Button { topic = name } label: { TagChip(title: name, isSelected: topic == name) }
                    }
                }
                .buttonStyle(.plain)

                CardSurface {
                    Label("\(pool.count) Aufgaben\(language == .german ? " · Erklärungen auch auf Persisch" : "")",
                          systemImage: "info.circle")
                        .font(DariFont.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                Button("Üben starten") {
                    launch = PracticeLaunch(plan: .grammar(language: language, topic: topic), direction: .mixed)
                }
                .buttonStyle(.dariPrimary)
                .disabled(pool.isEmpty)
                .accessibilityIdentifier("grammar.start")
            }
            .padding(Spacing.md)
        }
        .background(Palette.background)
        .navigationTitle("Grammatik")
        .navigationDestination(item: $launch) { PracticeSessionContainer(launch: $0) }
    }
}

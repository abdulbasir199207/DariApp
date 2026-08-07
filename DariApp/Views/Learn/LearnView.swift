//
//  LearnView.swift
//  DariApp
//
//  Startbildschirm des Lernens: Auswahl von Modus, Abfragerichtung und
//  Tag-Filter. Von hier startet eine Session (Navigation via NavigationStack).
//

import SwiftUI
import SwiftData

struct LearnView: View {

    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query private var cards: [Card]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var mode: LearningMode?
    @State private var direction: QueryDirection?
    @State private var selectedTagNames: Set<String> = []
    @State private var startSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                modeSection
                directionSection
                tagSection
                dueInfo
            }
            .padding(Spacing.md)
        }
        .background(Palette.background)
        .navigationTitle("Lernen")
        .safeAreaInset(edge: .bottom) { startButton }
        .navigationDestination(isPresented: $startSession) {
            LearnSessionView(configuration: sessionConfiguration,
                             candidates: filteredCandidates,
                             allCards: cards)
        }
        .onAppear {
            if mode == nil { mode = settings.defaultMode }
            if direction == nil { direction = settings.defaultDirection }
        }
    }

    // MARK: - Abschnitte

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Bereit zum Lernen?")
                .font(DariFont.largeTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("\(dueCount) faellige Karten heute")
                .font(DariFont.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionTitle("Modus")
            ForEach(LearningMode.allCases) { m in
                SelectionRow(
                    title: m.title,
                    systemImage: m.systemImage,
                    isSelected: mode == m
                ) { mode = m }
            }
        }
    }

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionTitle("Richtung")
            Picker("Richtung", selection: Binding(
                get: { direction ?? .mixed },
                set: { direction = $0 }
            )) {
                ForEach(QueryDirection.allCases) { d in
                    Text(d.title).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionTitle("Tags")
            if tags.isEmpty {
                Text("Keine Tags vorhanden – es werden alle Karten gelernt.")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                FlowLayout(spacing: Spacing.xs) {
                    Button { selectedTagNames.removeAll() } label: {
                        TagChip(title: "Alle", isSelected: selectedTagNames.isEmpty)
                    }
                    .buttonStyle(.plain)
                    ForEach(tags) { tag in
                        Button { toggleTag(tag.name) } label: {
                            TagChip(title: tag.name, isSelected: selectedTagNames.contains(tag.name))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dueInfo: some View {
        CardSurface {
            HStack {
                Image(systemName: "info.circle").foregroundStyle(Palette.sage)
                Text("Auswahl: \(filteredCandidates.count) Karten")
                    .font(DariFont.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var startButton: some View {
        Button {
            startSession = true
        } label: {
            Text("Lernen starten")
        }
        .buttonStyle(.dariPrimary)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .disabled(filteredCandidates.isEmpty)
        .background(.ultraThinMaterial)
    }

    // MARK: - Hilfen

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(DariFont.headline)
            .foregroundStyle(Palette.textPrimary)
    }

    private func toggleTag(_ name: String) {
        if selectedTagNames.contains(name) {
            selectedTagNames.remove(name)
        } else {
            selectedTagNames.insert(name)
        }
    }

    private var sessionConfiguration: LearnSessionViewModel.Configuration {
        LearnSessionViewModel.Configuration(
            mode: mode ?? settings.defaultMode,
            direction: direction ?? settings.defaultDirection,
            limit: settings.dailyGoal
        )
    }

    /// Karten passend zum Tag-Filter (leere Auswahl = alle aktiven Karten).
    private var filteredCandidates: [Card] {
        let active = cards.filter(\.isActive)
        guard !selectedTagNames.isEmpty else { return active }
        return active.filter { card in
            !selectedTagNames.isDisjoint(with: Set(card.tags.map(\.name)))
        }
    }

    private var dueCount: Int {
        cards.filter { $0.isDue() }.count
    }
}

/// Auswahlzeile fuer den Modus.
private struct SelectionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? .white : Palette.sage)
                Text(title)
                    .foregroundStyle(isSelected ? .white : Palette.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.white)
                }
            }
            .font(DariFont.body)
            .padding(Spacing.sm)
            .background(isSelected ? Palette.sage : Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { LearnView() }
        .environment(AppSettings())
        .modelContainer(PreviewData.container)
}

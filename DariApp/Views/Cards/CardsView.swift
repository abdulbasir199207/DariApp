//
//  CardsView.swift
//  DariApp
//
//  Kartenverwaltung: Liste aller Karten mit Suche (Deutsch, Persisch,
//  Lautschrift, Tags), Wischaktionen (Loeschen, Favorit, Aktiv/Inaktiv)
//  und Zugang zum Editor.
//

import SwiftUI
import SwiftData

struct CardsView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Card.updatedAt, order: .reverse) private var cards: [Card]

    @State private var searchText = ""
    @State private var editorTarget: EditorTarget?

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Karten")
        .background(Palette.background)
        .searchable(text: $searchText, prompt: "Suchen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editorTarget = .new } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            NavigationStack {
                switch target {
                case .new:
                    CardEditorView(context: context)
                case .edit(let card):
                    CardEditorView(card: card, context: context)
                }
            }
        }
    }

    // MARK: - Liste

    private var list: some View {
        List {
            ForEach(filteredCards) { card in
                Button { editorTarget = .edit(card) } label: {
                    CardRow(card: card)
                }
                .listRowBackground(Palette.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { delete(card) } label: {
                        Label("Loeschen", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button { toggleActive(card) } label: {
                        Label(card.isActive ? "Deaktivieren" : "Aktivieren",
                              systemImage: card.isActive ? "pause" : "play")
                    }
                    .tint(Palette.warning)
                    Button { toggleFavorite(card) } label: {
                        Label("Favorit", systemImage: card.isFavorite ? "star.slash" : "star")
                    }
                    .tint(Palette.turquoise)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch keine Karten", systemImage: "rectangle.stack.badge.plus")
        } description: {
            Text("Lege deine erste Karte an, um mit dem Lernen zu beginnen.")
        } actions: {
            Button("Karte anlegen") { editorTarget = .new }
                .buttonStyle(.dariPrimary)
                .frame(maxWidth: 240)
        }
    }

    // MARK: - Filter

    private var filteredCards: [Card] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return cards }
        let persianQuery = AnswerChecker.normalize(query, isPersian: true)
        return cards.filter { card in
            let german = card.germanTranslations.joined(separator: " ").lowercased()
            let persian = card.persianTranslations
                .map { AnswerChecker.normalize($0, isPersian: true) }
                .joined(separator: " ")
            let translit = card.transliteration.lowercased()
            let tags = card.tags.map(\.name).joined(separator: " ").lowercased()
            return german.contains(query)
                || persian.contains(persianQuery)
                || translit.contains(query)
                || tags.contains(query)
        }
    }

    // MARK: - Aktionen

    private func delete(_ card: Card) {
        if let name = card.audioFileName {
            AudioFileStore().delete(name)
        }
        context.delete(card)
        try? context.save()
    }

    private func toggleActive(_ card: Card) {
        card.isActive.toggle()
        card.updatedAt = Date()
        try? context.save()
    }

    private func toggleFavorite(_ card: Card) {
        card.isFavorite.toggle()
        try? context.save()
    }
}

/// Ziel des Editor-Sheets (neu oder bearbeiten).
private enum EditorTarget: Identifiable {
    case new
    case edit(Card)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let card): return card.id.uuidString
        }
    }
}

// MARK: - Zeile

private struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(card.germanTranslations.joined(separator: ", "))
                    .font(DariFont.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(card.persianTranslations.joined(separator: "، "))
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.textSecondary)
                    .environment(\.layoutDirection, .rightToLeft)
                if !card.tags.isEmpty {
                    Text(card.tags.map(\.name).joined(separator: " · "))
                        .font(DariFont.caption)
                        .foregroundStyle(Palette.sage)
                }
            }
            Spacer()
            VStack(spacing: Spacing.xs) {
                if card.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(Palette.turquoise)
                }
                if !card.isActive {
                    Image(systemName: "pause.circle").foregroundStyle(Palette.textSecondary)
                }
                if card.hasAudio {
                    Image(systemName: "waveform").foregroundStyle(Palette.sage)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { CardsView() }
        .environment(AppSettings())
        .modelContainer(PreviewData.container)
}

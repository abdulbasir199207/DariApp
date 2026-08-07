//
//  Tag.swift
//  DariApp
//
//  SwiftData-Modell eines Tags. Tags ersetzen klassische Decks:
//  frei eingebbar, mehrere pro Karte, Many-to-Many zu `Card`.
//

import Foundation
import SwiftData

@Model
final class Tag {

    /// Eindeutiger, normalisierter Name. Dient auch der Duplikatvermeidung.
    @Attribute(.unique) var name: String = ""

    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// Gegenrichtung der Many-to-Many-Beziehung (Inverse liegt an `Card.tags`).
    var cards: [Card] = []

    init(name: String) {
        self.id = UUID()
        self.name = Tag.normalize(name)
        self.createdAt = Date()
    }
}

extension Tag {

    /// Anzahl der (auch inaktiven) verknuepften Karten.
    var cardCount: Int { cards.count }

    /// Normalisiert einen Tag-Namen: getrimmt, Kleinbuchstaben-unabhaengig
    /// wird beim Vergleich behandelt – hier nur Whitespace entfernt, damit
    /// die Original-Schreibweise erhalten bleibt.
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

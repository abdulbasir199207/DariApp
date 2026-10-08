//
//  Card.swift
//  DariApp
//
//  SwiftData-Modell einer Lernkarte.
//
//  Designentscheidungen:
//  - Mehrere Uebersetzungen je Seite werden als `[String]` gespeichert.
//    Fuer eine Ein-Personen-Offline-App ist das ausreichend, vermeidet
//    unnoetige Zusatz-Entities und bleibt performant.
//  - Alle gespeicherten Properties besitzen Default-Werte. Das ist
//    Voraussetzung fuer problemlose, automatische SwiftData-Migrationen.
//  - Lern-/FSRS-Daten liegen direkt am Modell. Die reine Historie
//    (fuer Statistiken) liegt getrennt in `ReviewLog`.
//

import Foundation
import SwiftData

@Model
final class Card {

    // MARK: Identitaet & Inhalt

    var id: UUID = UUID()

    /// Deutsche Uebersetzungen (mind. eine gueltige Eingabe erwartet).
    var germanTranslations: [String] = []

    /// Persische Uebersetzungen in persischer Schrift.
    var persianTranslations: [String] = []

    /// Lautschrift – reine Lesehilfe, wird niemals abgefragt.
    var transliteration: String = ""

    /// Tags ersetzen klassische Decks (Many-to-Many, Inverse an `Tag.cards`).
    @Relationship(inverse: \Tag.cards)
    var tags: [Tag] = []

    /// Dateiname der lokalen Audioaufnahme (m4a) im Audio-Verzeichnis.
    /// `nil`, wenn keine Aufnahme existiert.
    var audioFileName: String?

    // MARK: Status

    var isFavorite: Bool = false

    /// Deaktivierte Karten bleiben erhalten, erscheinen aber nicht beim Lernen.
    var isActive: Bool = true

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Lerninformationen (FSRS)

    var correctCount: Int = 0
    var wrongCount: Int = 0

    /// FSRS-Schwierigkeit (1...10).
    var difficulty: Double = 0

    /// FSRS-Stabilitaet in Tagen (Gedaechtnis-Halbwertszeit).
    var stability: Double = 0

    var lastReview: Date?
    var nextReview: Date?

    /// Zuletzt gemessene Antwortzeit in Sekunden.
    var lastAnswerTime: TimeInterval = 0

    /// Zuletzt geplantes Wiederholungsintervall in Tagen.
    var interval: Int = 0

    /// Anzahl erfolgreicher Wiederholungen.
    var reps: Int = 0

    /// Anzahl "Rueckfaelle" (vergessen im Review-Zustand).
    var lapses: Int = 0

    /// Aktueller FSRS-Zustand.
    var state: CardState = CardState.new

    // MARK: Zusatzdaten (ZARA)

    /// Fehler in Spielen und Uebungswiederholungen. Fliesst in die Schwaeche-Bewertung ein,
    /// aendert aber nicht den FSRS-Termin.
    var miss: Int = 0

    /// Optionaler Beispielsatz (fuer Lueckentexte aus eigenen Woertern).
    var exampleGerman: String = ""
    var examplePersian: String = ""

    // MARK: Init

    init(
        germanTranslations: [String] = [],
        persianTranslations: [String] = [],
        transliteration: String = "",
        tags: [Tag] = []
    ) {
        self.id = UUID()
        self.germanTranslations = germanTranslations
        self.persianTranslations = persianTranslations
        self.transliteration = transliteration
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Abgeleitete Eigenschaften (nicht persistiert)

extension Card {

    /// Primaere deutsche Anzeige (erste Uebersetzung) mit Fallback.
    var primaryGerman: String { germanTranslations.first ?? "" }

    /// Primaere persische Anzeige (erste Uebersetzung) mit Fallback.
    var primaryPersian: String { persianTranslations.first ?? "" }

    var hasAudio: Bool { audioFileName != nil }

    /// Ist die Karte aktuell zur Wiederholung faellig?
    func isDue(asOf date: Date = .now) -> Bool {
        guard isActive else { return false }
        guard let nextReview else { return true } // neue Karte
        return nextReview <= date
    }
}

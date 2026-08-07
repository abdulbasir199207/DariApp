//
//  Enums.swift
//  DariApp
//
//  Zentrale, app-weit genutzte Aufzählungstypen.
//  Bewusst in einer Datei gebündelt, da sie klein sind und
//  querschnittlich in Models, ViewModels und Views verwendet werden.
//

import Foundation

// MARK: - CardState

/// Zustand einer Karte im Spaced-Repetition-Lebenszyklus (FSRS).
enum CardState: Int, Codable, CaseIterable, Sendable {
    /// Karte wurde noch nie gelernt.
    case new = 0
    /// Karte befindet sich in der initialen Lernphase.
    case learning = 1
    /// Karte ist im regulaeren Wiederholungszyklus.
    case review = 2
    /// Karte wurde vergessen und wird neu gelernt.
    case relearning = 3
}

// MARK: - FSRSRating

/// Vier-stufige Bewertung einer Antwort, wie sie der FSRS-Algorithmus erwartet.
/// Die Rohwerte 1...4 entsprechen der FSRS-Konvention.
enum FSRSRating: Int, Codable, CaseIterable, Sendable {
    case again = 1   // vergessen / komplett falsch
    case hard = 2    // mit Muehe / kleiner Tippfehler
    case good = 3    // korrekt
    case easy = 4    // muehelos & schnell korrekt
}

// MARK: - AnswerQuality

/// Ergebnis der Antwortpruefung im Schreib- oder Multiple-Choice-Modus.
/// Wird anschliessend in ein `FSRSRating` uebersetzt.
enum AnswerQuality: Sendable {
    case perfect   // exakt richtig
    case typo      // kleiner Tippfehler (1 Editieroperation)
    case wrong     // komplett falsch

    /// Uebersetzt die reine Korrektheit (plus optional Antwortzeit)
    /// in eine FSRS-Bewertung.
    /// - Parameter fast: Wurde die Antwort deutlich schneller als der
    ///   Referenzwert gegeben? Nur relevant fuer `perfect`.
    func rating(fast: Bool) -> FSRSRating {
        switch self {
        case .perfect: return fast ? .easy : .good
        case .typo:    return .hard
        case .wrong:   return .again
        }
    }
}

// MARK: - LearningMode

/// Die drei Lernmodi der App.
enum LearningMode: Int, Codable, CaseIterable, Identifiable, Sendable {
    case flip = 0            // Karte umdrehen (Selbsteinschaetzung)
    case multipleChoice = 1  // Vier Auswahlmoeglichkeiten
    case writing = 2         // Antwort eintippen

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .flip: return "Umdrehen"
        case .multipleChoice: return "Multiple Choice"
        case .writing: return "Schreiben"
        }
    }

    var systemImage: String {
        switch self {
        case .flip: return "rectangle.on.rectangle.angled"
        case .multipleChoice: return "list.bullet"
        case .writing: return "pencil.line"
        }
    }
}

// MARK: - QueryDirection

/// Abfragerichtung eines Lerndurchgangs.
enum QueryDirection: Int, Codable, CaseIterable, Identifiable, Sendable {
    case germanToPersian = 0
    case persianToGerman = 1
    case mixed = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .germanToPersian: return "Deutsch → Persisch"
        case .persianToGerman: return "Persisch → Deutsch"
        case .mixed: return "Gemischt"
        }
    }

    /// Loest die tatsaechliche Richtung fuer eine einzelne Karte auf.
    /// Bei `.mixed` wird pro Karte zufaellig entschieden.
    func resolved(using generator: inout some RandomNumberGenerator) -> ResolvedDirection {
        switch self {
        case .germanToPersian: return .germanToPersian
        case .persianToGerman: return .persianToGerman
        case .mixed: return Bool.random(using: &generator) ? .germanToPersian : .persianToGerman
        }
    }
}

/// Eine konkret aufgeloeste Richtung (nie `.mixed`).
enum ResolvedDirection: Sendable {
    case germanToPersian
    case persianToGerman

    /// Wird auf der Rueckseite persische Schrift abgefragt?
    var answerIsPersian: Bool { self == .germanToPersian }
}

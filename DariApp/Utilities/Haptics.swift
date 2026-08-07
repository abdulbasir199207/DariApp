//
//  Haptics.swift
//  DariApp
//
//  Duennes Wrapper um UIKit-Haptik. Zentralisiert das Feedback, damit
//  Lern-Interaktionen (richtig/falsch, Umdrehen) sich konsistent anfuehlen.
//

import UIKit

@MainActor
enum Haptics {

    /// Leichter Tap – z. B. Karte umdrehen, Auswahl.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Erfolgs-Feedback (perfekte/richtige Antwort).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warnung (kleiner Tippfehler).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Fehler (falsche Antwort).
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Passendes Feedback zur Antwortqualitaet.
    static func feedback(for quality: AnswerQuality) {
        switch quality {
        case .perfect: success()
        case .typo: warning()
        case .wrong: error()
        }
    }
}

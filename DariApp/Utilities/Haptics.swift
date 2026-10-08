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

    /// Vom Nutzer in den Einstellungen abschaltbar.
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettings.Keys.haptics) as? Bool ?? true
    }

    /// Leichter Tap – z. B. Karte umdrehen, Auswahl.
    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Erfolgs-Feedback (perfekte/richtige Antwort).
    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warnung (kleiner Tippfehler).
    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Fehler (falsche Antwort).
    static func error() {
        guard isEnabled else { return }
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

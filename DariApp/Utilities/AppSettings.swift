//
//  AppSettings.swift
//  DariApp
//
//  Zentrale, beobachtbare Benutzereinstellungen. Nutzt das Observation-
//  Framework (@Observable) und persistiert nach UserDefaults. Wird per
//  Environment injiziert (Dependency Injection), sodass jede View lesen
//  und schreiben kann, ohne globale Singletons zu referenzieren.
//

import SwiftUI
import Observation

/// Farbschema-Praeferenz der App.
enum AppearancePreference: Int, CaseIterable, Identifiable, Sendable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppSettings {

    // MARK: Persistierte Werte

    var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var defaultMode: LearningMode {
        didSet { defaults.set(defaultMode.rawValue, forKey: Keys.defaultMode) }
    }

    var defaultDirection: QueryDirection {
        didSet { defaults.set(defaultDirection.rawValue, forKey: Keys.defaultDirection) }
    }

    /// Tägliches Lernziel (Anzahl Karten).
    var dailyGoal: Int {
        didSet { defaults.set(dailyGoal, forKey: Keys.dailyGoal) }
    }

    /// Ob Animationen aktiv sind.
    var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }

    // MARK: Init

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = AppearancePreference(rawValue: defaults.integer(forKey: Keys.appearance)) ?? .system
        self.defaultMode = LearningMode(rawValue: defaults.integer(forKey: Keys.defaultMode)) ?? .flip
        self.defaultDirection = QueryDirection(rawValue: defaults.integer(forKey: Keys.defaultDirection)) ?? .mixed
        self.dailyGoal = defaults.object(forKey: Keys.dailyGoal) as? Int ?? 20
        self.animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
    }

    private enum Keys {
        static let appearance = "settings.appearance"
        static let defaultMode = "settings.defaultMode"
        static let defaultDirection = "settings.defaultDirection"
        static let dailyGoal = "settings.dailyGoal"
        static let animationsEnabled = "settings.animationsEnabled"
    }
}

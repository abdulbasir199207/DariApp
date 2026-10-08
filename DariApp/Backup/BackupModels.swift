//
//  BackupModels.swift
//  DariApp
//
//  Austauschformat „zara-backup" (Version 3) – identisch zur Web-Version, damit
//  Backups zwischen PWA und iOS-App in beide Richtungen eingelesen werden koennen.
//  Zeitangaben sind Millisekunden seit 1970 (JavaScript-Konvention).
//  Auch Backups der PWA-Version 2.0 (nackte Datenstruktur) werden gelesen.
//

import Foundation

struct ZaraBackup: Codable {
    var format: String
    var formatVersion: Int
    var source: String?
    var appVersion: String?
    var createdAt: Double?
    var data: BackupData
    var audio: [String: BackupAudio]?
}

struct BackupAudio: Codable {
    var type: String?
    var b64: String
}

struct BackupData: Codable {
    var schemaVersion: Int?
    var cards: [BackupCard]
    var logs: [BackupLog]?
    var sent: [String: BackupItemStat]?
    var settings: BackupSettings?
}

struct BackupCard: Codable {
    var id: String
    var de: [String]
    var fa: [String]
    var translit: String?
    var tags: [String]?
    var audio: Bool?
    var active: Bool?
    var fav: Bool?
    var state: String?
    var s: Double?
    var d: Double?
    var interval: Int?
    var reps: Int?
    var lapses: Int?
    var correct: Int?
    var wrong: Int?
    var miss: Int?
    var lastReview: Double?
    var nextReview: Double?
    var lastTime: Double?
    var createdAt: Double?
    var updatedAt: Double?
    var exDe: String?
    var exFa: String?
}

struct BackupLog: Codable {
    var date: Double
    var rating: Int?
    var time: Double?
    var mode: String?
    var cardId: String?
    var itemId: String?
    var p: Int?
    var wk: Int?
}

struct BackupItemStat: Codable {
    var box: Int?
    var due: Double?
    var ok: Int?
    var bad: Int?
    var last: Double?
}

struct BackupSettings: Codable {
    var appearance: String?
    var defaultMode: String?
    var defaultDirection: String?
    var dailyGoal: Int?
    var animations: Bool?
    var haptics: Bool?
}

// MARK: - Zuordnung der Zustaende

extension CardState {
    var backupName: String {
        switch self {
        case .new: return "new"
        case .learning: return "learning"
        case .review: return "review"
        case .relearning: return "relearning"
        }
    }
    init(backupName: String?) {
        switch backupName {
        case "learning": self = .learning
        case "review": self = .review
        case "relearning": self = .relearning
        default: self = .new
        }
    }
}

extension LearningMode {
    var backupName: String {
        switch self {
        case .flip: return "flip"
        case .multipleChoice: return "mc"
        case .writing: return "write"
        }
    }
    init?(backupName: String) {
        switch backupName {
        case "flip": self = .flip
        case "mc": self = .multipleChoice
        case "write": self = .writing
        default: return nil
        }
    }
}

extension QueryDirection {
    var backupName: String {
        switch self {
        case .germanToPersian: return "g2p"
        case .persianToGerman: return "p2g"
        case .mixed: return "mixed"
        }
    }
    init?(backupName: String) {
        switch backupName {
        case "g2p": self = .germanToPersian
        case "p2g": self = .persianToGerman
        case "mixed": self = .mixed
        default: return nil
        }
    }
}

extension AppearancePreference {
    var backupName: String {
        switch self {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        }
    }
    init?(backupName: String) {
        switch backupName {
        case "system": self = .system
        case "light": self = .light
        case "dark": self = .dark
        default: return nil
        }
    }
}

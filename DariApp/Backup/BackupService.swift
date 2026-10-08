//
//  BackupService.swift
//  DariApp
//
//  Export, Pruefung und Wiederherstellung von Backups („zara-backup", Version 3).
//  Regeln:
//  - Vor jeder Wiederherstellung legt der Aufrufer eine Sicherheitskopie an.
//  - Die Wiederherstellung ist „alles oder nichts": bei einem Fehler wird der
//    gesamte Vorgang zurueckgerollt (`ModelContext.rollback()`).
//  - „Zusammenfuehren" verliert nie etwas: fehlende Karten kommen hinzu, bei
//    Konflikten gewinnt jeweils der neuere Stand (Inhalt bzw. Lernfortschritt).
//

import Foundation
import SwiftData
import CryptoKit

enum RestoreMode: Sendable {
    case replace
    case merge
}

struct ParsedBackup {
    var data: BackupData
    var audio: [String: BackupAudio]
    var createdAt: Date?
    var source: String
    var isLegacy: Bool
    var cardCount: Int { data.cards.count }
    var logCount: Int { data.logs?.count ?? 0 }
    var tagCount: Int { Set(data.cards.flatMap { $0.tags ?? [] }).count }
}

struct RestoreSummary: Sendable, Equatable {
    var cards = 0
    var logs = 0
    var added = 0
    var updated = 0
    var audioRestored = 0
}

enum BackupError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}

@MainActor
struct BackupService {

    static let formatName = "zara-backup"
    static let formatVersion = 3

    let context: ModelContext
    let settings: AppSettings
    let audioStore: AudioFileStore

    init(context: ModelContext, settings: AppSettings, audioStore: AudioFileStore = AudioFileStore()) {
        self.context = context
        self.settings = settings
        self.audioStore = audioStore
    }

    // MARK: - Export

    func makeBackup(includeAudio: Bool, now: Date = .now) throws -> Data {
        let cards = try context.fetch(FetchDescriptor<Card>(sortBy: [SortDescriptor(\.createdAt)]))
        let logs = try context.fetch(FetchDescriptor<ReviewLog>(sortBy: [SortDescriptor(\.date)]))
        let stats = try context.fetch(FetchDescriptor<ItemStat>())

        func ms(_ date: Date) -> Double { (date.timeIntervalSince1970 * 1000).rounded() }
        func id(_ uuid: UUID) -> String { uuid.uuidString.lowercased() }

        let cardDTOs = cards.map { card in
            BackupCard(
                id: id(card.id), de: card.germanTranslations, fa: card.persianTranslations,
                translit: card.transliteration, tags: card.tags.map(\.name).sorted(),
                audio: card.hasAudio, active: card.isActive, fav: card.isFavorite,
                state: card.state.backupName, s: card.stability, d: card.difficulty,
                interval: card.interval, reps: card.reps, lapses: card.lapses,
                correct: card.correctCount, wrong: card.wrongCount, miss: card.miss,
                lastReview: card.lastReview.map(ms), nextReview: card.nextReview.map(ms),
                lastTime: card.lastAnswerTime, createdAt: ms(card.createdAt), updatedAt: ms(card.updatedAt),
                exDe: card.exampleGerman, exFa: card.examplePersian)
        }
        let logDTOs = logs.map { log in
            BackupLog(
                date: ms(log.date), rating: log.rating.rawValue, time: log.answerTime,
                mode: log.exercise.isEmpty ? log.mode.backupName : log.exercise,
                cardId: log.card.map { id($0.id) }, itemId: log.itemID,
                p: log.isPractice ? 1 : nil, wk: log.wasWeak ? 1 : nil)
        }
        var sent: [String: BackupItemStat] = [:]
        for stat in stats {
            sent[stat.itemID] = BackupItemStat(
                box: stat.box, due: ms(stat.due), ok: stat.okCount, bad: stat.badCount, last: ms(stat.last))
        }
        let settingsDTO = BackupSettings(
            appearance: settings.appearance.backupName, defaultMode: settings.defaultMode.backupName,
            defaultDirection: settings.defaultDirection.backupName, dailyGoal: settings.dailyGoal,
            animations: settings.animationsEnabled, haptics: settings.hapticsEnabled)

        var audio: [String: BackupAudio]?
        if includeAudio {
            var map: [String: BackupAudio] = [:]
            for card in cards {
                guard let name = card.audioFileName, audioStore.exists(name),
                      let bytes = try? Data(contentsOf: audioStore.url(for: name)) else { continue }
                map[id(card.id)] = BackupAudio(type: "audio/mp4", b64: bytes.base64EncodedString())
            }
            audio = map
        }

        let backup = ZaraBackup(
            format: Self.formatName, formatVersion: Self.formatVersion, source: "ios-native",
            appVersion: Self.appVersionString, createdAt: ms(now),
            data: BackupData(schemaVersion: 3, cards: cardDTOs, logs: logDTOs, sent: sent, settings: settingsDTO),
            audio: audio)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try encoder.encode(backup)
    }

    static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    static func fileName(now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "zara-backup-\(formatter.string(from: now)).json"
    }

    // MARK: - Pruefen

    static func parse(_ data: Data) -> Result<ParsedBackup, BackupError> {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(ZaraBackup.self, from: data), envelope.format == formatName {
            if envelope.formatVersion > formatVersion {
                return .failure(.invalid("Dieses Backup stammt aus einer neueren ZARA-Version. Bitte ZARA aktualisieren."))
            }
            if (envelope.data.schemaVersion ?? 3) > formatVersion {
                return .failure(.invalid("Dieses Backup stammt aus einer neueren ZARA-Version. Bitte ZARA aktualisieren."))
            }
            return .success(ParsedBackup(
                data: envelope.data, audio: envelope.audio ?? [:],
                createdAt: envelope.createdAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                source: envelope.source ?? "zara-web", isLegacy: false))
        }
        // Backup der PWA-Version 2.0: die Datenstruktur selbst.
        if let legacy = try? decoder.decode(BackupData.self, from: data) {
            return .success(ParsedBackup(data: legacy, audio: [:], createdAt: nil, source: "zara-web", isLegacy: true))
        }
        return .failure(.invalid("Das ist kein gueltiges ZARA-Backup (Datei unvollstaendig oder beschaedigt)."))
    }

    // MARK: - Wiederherstellen

    /// Gleiche Eingabe-ID ergibt immer dieselbe UUID (PWA-IDs sind keine UUIDs).
    static func stableUUID(from text: String) -> UUID {
        if let uuid = UUID(uuidString: text) { return uuid }
        var bytes = Array(SHA256.hash(data: Data(("zara:" + text).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Wendet ein geprueftes Backup an. Bei einem Fehler bleibt alles unveraendert.
    @discardableResult
    func apply(_ parsed: ParsedBackup, mode: RestoreMode) throws -> RestoreSummary {
        var summary = RestoreSummary()
        var writtenAudio: [URL] = []
        do {
            if mode == .replace {
                for log in try context.fetch(FetchDescriptor<ReviewLog>()) { context.delete(log) }
                for card in try context.fetch(FetchDescriptor<Card>()) { context.delete(card) }
                for stat in try context.fetch(FetchDescriptor<ItemStat>()) { context.delete(stat) }
                for tag in try context.fetch(FetchDescriptor<Tag>()) { context.delete(tag) }
                try context.save()
            }

            // Vorhandenes indexieren (leer bei „ersetzen").
            var tagsByName: [String: Tag] = [:]
            for tag in try context.fetch(FetchDescriptor<Tag>()) { tagsByName[tag.name] = tag }
            var cardsByID: [UUID: Card] = [:]
            for card in try context.fetch(FetchDescriptor<Card>()) { cardsByID[card.id] = card }

            func tag(named raw: String) -> Tag {
                let name = Tag.normalize(raw)
                if let existing = tagsByName[name] { return existing }
                let created = Tag(name: name)
                context.insert(created)
                tagsByName[name] = created
                return created
            }
            func date(_ ms: Double?) -> Date? { ms.map { Date(timeIntervalSince1970: $0 / 1000) } }

            for dto in parsed.data.cards {
                let uuid = Self.stableUUID(from: dto.id)
                let german = dto.de.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                let persian = dto.fa.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if german.isEmpty && persian.isEmpty { continue }

                let isNew = cardsByID[uuid] == nil
                let card = cardsByID[uuid] ?? Card()
                if isNew {
                    card.id = uuid
                    context.insert(card)
                    cardsByID[uuid] = card
                    summary.added += 1
                }
                let incomingUpdated = date(dto.updatedAt) ?? date(dto.createdAt) ?? Date()
                let contentIsNewer = isNew || incomingUpdated > card.updatedAt
                if contentIsNewer {
                    card.germanTranslations = german
                    card.persianTranslations = persian
                    card.transliteration = dto.translit ?? ""
                    card.tags = (dto.tags ?? []).map(tag(named:)).filter { !$0.name.isEmpty }
                    card.isActive = dto.active ?? true
                    card.isFavorite = dto.fav ?? false
                    card.exampleGerman = dto.exDe ?? ""
                    card.examplePersian = dto.exFa ?? ""
                    card.createdAt = date(dto.createdAt) ?? card.createdAt
                    card.updatedAt = incomingUpdated
                    if !isNew { summary.updated += 1 }
                }
                let incomingReview = date(dto.lastReview)
                let learningIsNewer = isNew || (incomingReview ?? .distantPast) > (card.lastReview ?? .distantPast)
                if learningIsNewer {
                    card.state = CardState(backupName: dto.state)
                    card.stability = max(dto.s ?? 0, 0)
                    card.difficulty = dto.d ?? 0
                    card.interval = max(dto.interval ?? 0, 0)
                    card.reps = max(dto.reps ?? 0, 0)
                    card.lapses = max(dto.lapses ?? 0, 0)
                    card.correctCount = max(dto.correct ?? 0, 0)
                    card.wrongCount = max(dto.wrong ?? 0, 0)
                    card.miss = max(dto.miss ?? 0, 0)
                    card.lastReview = incomingReview
                    card.nextReview = date(dto.nextReview)
                    card.lastAnswerTime = max(dto.lastTime ?? 0, 0)
                }
                // Aufnahme uebernehmen, wenn mitgeliefert und noch keine vorhanden.
                if card.audioFileName == nil || !audioStore.exists(card.audioFileName ?? ""),
                   let clip = parsed.audio[dto.id], let bytes = Data(base64Encoded: clip.b64),
                   !(clip.type ?? "").contains("webm"), !(clip.type ?? "").contains("ogg") {
                    let name = audioStore.newFileName()
                    let url = audioStore.url(for: name)
                    try bytes.write(to: url, options: .atomic)
                    writtenAudio.append(url)
                    card.audioFileName = name
                    summary.audioRestored += 1
                }
            }

            // Verlauf
            func logKey(date: Double, cardID: String, itemID: String, rating: Int, mode: String) -> String {
                "\(Int64(date))|\(cardID)|\(itemID)|\(rating)|\(mode)"
            }
            var knownLogs = Set<String>()
            if mode == .merge {
                for log in try context.fetch(FetchDescriptor<ReviewLog>()) {
                    let ms = (log.date.timeIntervalSince1970 * 1000).rounded()
                    knownLogs.insert(logKey(
                        date: ms, cardID: log.card.map { $0.id.uuidString.lowercased() } ?? "",
                        itemID: log.itemID ?? "", rating: log.rating.rawValue,
                        mode: log.exercise.isEmpty ? log.mode.backupName : log.exercise))
                }
            }
            for dto in parsed.data.logs ?? [] {
                let cardUUID = dto.cardId.map { Self.stableUUID(from: $0) }
                let rating = FSRSRating(rawValue: dto.rating ?? 3) ?? .good
                let modeName = dto.mode ?? "flip"
                let key = logKey(
                    date: dto.date, cardID: cardUUID.map { $0.uuidString.lowercased() } ?? "",
                    itemID: dto.itemId ?? "", rating: rating.rawValue, mode: modeName)
                if knownLogs.contains(key) { continue }
                knownLogs.insert(key)
                let learning = LearningMode(backupName: modeName)
                let log = ReviewLog(
                    card: cardUUID.flatMap { cardsByID[$0] }, rating: rating, answerTime: max(dto.time ?? 0, 0),
                    mode: learning ?? .flip, exercise: learning == nil ? modeName : "", itemID: dto.itemId,
                    isPractice: (dto.p ?? 0) != 0, wasWeak: (dto.wk ?? 0) != 0,
                    date: Date(timeIntervalSince1970: dto.date / 1000))
                context.insert(log)
                summary.logs += 1
            }

            // Satz-/Grammatik-Lernstaende
            var statsByID: [String: ItemStat] = [:]
            for stat in try context.fetch(FetchDescriptor<ItemStat>()) { statsByID[stat.itemID] = stat }
            for (itemID, dto) in parsed.data.sent ?? [:] {
                let incomingLast = date(dto.last) ?? .distantPast
                let stat: ItemStat
                if let existing = statsByID[itemID] {
                    stat = existing
                } else {
                    stat = ItemStat(itemID: itemID)
                    context.insert(stat)
                    statsByID[itemID] = stat
                }
                if stat.last <= incomingLast {
                    stat.box = min(max(dto.box ?? 0, 0), ItemStat.boxDays.count - 1)
                    stat.due = date(dto.due) ?? .distantPast
                    stat.okCount = max(dto.ok ?? 0, 0)
                    stat.badCount = max(dto.bad ?? 0, 0)
                    stat.last = incomingLast
                }
            }

            try context.save()
        } catch {
            context.rollback()
            for url in writtenAudio { try? FileManager.default.removeItem(at: url) }
            throw error
        }

        // Einstellungen nur beim Ersetzen uebernehmen.
        if mode == .replace, let s = parsed.data.settings {
            if let v = s.appearance.flatMap(AppearancePreference.init(backupName:)) { settings.appearance = v }
            if let v = s.defaultMode.flatMap(LearningMode.init(backupName:)) { settings.defaultMode = v }
            if let v = s.defaultDirection.flatMap(QueryDirection.init(backupName:)) { settings.defaultDirection = v }
            if let v = s.dailyGoal { settings.dailyGoal = min(max(v, 5), 200) }
            if let v = s.animations { settings.animationsEnabled = v }
            if let v = s.haptics { settings.hapticsEnabled = v }
        }
        summary.cards = (try? context.fetchCount(FetchDescriptor<Card>())) ?? 0
        return summary
    }
}

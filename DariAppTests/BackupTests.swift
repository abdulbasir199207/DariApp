//
//  BackupTests.swift
//  DariAppTests
//
//  Datensicherheit: Export/Import verlustfrei, Kompatibilitaet mit der Web-Version
//  (inkl. alter Backups), Zusammenfuehren, Schnappschuesse der Datenbank.
//

import Testing
import Foundation
import SwiftData
@testable import DariApp

@MainActor
struct BackupTests {

    // Beispiel eines Backups der Web-Version (zara-backup v3, PWA-IDs sind keine UUIDs).
    private let webBackup = #"""
    {"format":"zara-backup","formatVersion":3,"source":"zara-web","appVersion":"3.0","createdAt":1791482388544,
     "counts":{"cards":2,"logs":3},"checksum":"deadbeef",
     "data":{"schemaVersion":3,"cards":[
       {"id":"mtifs800dtxnhn","de":["Haus","Gebäude"],"fa":["خانه","منزل"],"translit":"khâne","tags":["Alltag","Test"],"audio":false,"active":true,"fav":true,
        "state":"review","s":4.5,"d":5.1,"interval":5,"reps":3,"lapses":1,"correct":2,"wrong":1,"miss":2,"lastReview":1788339615000,"nextReview":1788771615000,
        "lastTime":3.2,"createdAt":1788000000000,"updatedAt":1788339615000,"exDe":"Das Haus ist groß.","exFa":"خانه بزرگ است."},
       {"id":"abc","de":["Wasser"],"fa":["آب"],"translit":"âb","tags":[],"audio":false,"active":false,"fav":false,"state":"new","s":0,"d":0,"interval":0,"reps":0,
        "lapses":0,"correct":0,"wrong":0,"lastReview":null,"nextReview":null,"lastTime":0,"createdAt":1788000000000,"updatedAt":1788000000000}],
     "logs":[{"date":1788339615000,"rating":3,"time":3.2,"mode":"mc","cardId":"mtifs800dtxnhn"},
             {"date":1788339700000,"rating":1,"time":2,"mode":"match","cardId":"abc","wk":1},
             {"date":1788339800000,"rating":3,"time":4,"mode":"grammar","itemId":"g01","p":1}],
     "logArchive":{},"sent":{"g01":{"box":2,"due":1788900000000,"ok":2,"bad":0,"last":1788339800000}},
     "settings":{"appearance":"dark","defaultMode":"mc","defaultDirection":"g2p","dailyGoal":30,"animations":false,"haptics":false},
     "meta":{"createdAt":1788000000000}}}
    """#

    private let legacyBackup = #"""
    {"cards":[{"id":"x1","de":["Brot"],"fa":["نان"],"translit":"nân","tags":["Alltag"],"audio":false,"active":true,"fav":false,"state":"new","s":0,"d":0,
               "interval":0,"reps":0,"lapses":0,"correct":0,"wrong":0,"lastReview":null,"nextReview":null,"lastTime":0,"createdAt":1700000000000,"updatedAt":1700000000000}],
     "logs":[],"settings":{"appearance":"light","defaultMode":"flip","defaultDirection":"mixed","dailyGoal":20,"animations":true}}
    """#

    private func parsed(_ json: String) throws -> ParsedBackup {
        switch BackupService.parse(Data(json.utf8)) {
        case .success(let p): return p
        case .failure(let e): throw e
        }
    }

    @Test("Backup der Web-Version wird vollstaendig uebernommen")
    func importWebBackup() throws {
        let env = TestEnv()
        let service = BackupService(context: env.context, settings: env.settings)
        let summary = try service.apply(try parsed(webBackup), mode: .replace)
        #expect(summary.cards == 2)

        let cards = env.fetch(Card.self)
        let house = try #require(cards.first { $0.germanTranslations.first == "Haus" })
        #expect(house.id == BackupService.stableUUID(from: "mtifs800dtxnhn"))
        #expect(house.germanTranslations == ["Haus", "Gebäude"])
        #expect(house.persianTranslations == ["خانه", "منزل"])
        #expect(Set(house.tags.map(\.name)) == ["Alltag", "Test"])
        #expect(house.isFavorite && house.isActive)
        #expect(house.state == .review && house.reps == 3 && house.lapses == 1 && house.miss == 2)
        #expect(abs(house.stability - 4.5) < 0.0001)
        #expect(abs((house.lastReview?.timeIntervalSince1970 ?? 0) - 1_788_339_615) < 0.001)
        #expect(house.examplePersian == "خانه بزرگ است.")
        let water = try #require(cards.first { $0.germanTranslations.first == "Wasser" })
        #expect(!water.isActive && water.lastReview == nil && water.state == .new)

        let logs = env.fetch(ReviewLog.self)
        #expect(logs.count == 3)
        #expect(logs.contains { $0.exercise.isEmpty && $0.mode == .multipleChoice && $0.card?.id == house.id })
        #expect(logs.contains { $0.exercise == "match" && $0.wasWeak && $0.rating == .again })
        #expect(logs.contains { $0.exercise == "grammar" && $0.itemID == "g01" && $0.isPractice })

        let stat = try #require(env.fetch(ItemStat.self).first)
        #expect(stat.itemID == "g01" && stat.box == 2 && stat.okCount == 2)

        #expect(env.settings.appearance == .dark)
        #expect(env.settings.defaultMode == .multipleChoice)
        #expect(env.settings.defaultDirection == .germanToPersian)
        #expect(env.settings.dailyGoal == 30)
        #expect(!env.settings.animationsEnabled && !env.settings.hapticsEnabled)
    }

    @Test("Backup der Web-Version 2.0 (nackte Datenstruktur) wird gelesen")
    func importLegacy() throws {
        let p = try parsed(legacyBackup)
        #expect(p.isLegacy && p.cardCount == 1)
        let env = TestEnv()
        try BackupService(context: env.context, settings: env.settings).apply(p, mode: .replace)
        #expect(env.fetch(Card.self).first?.germanTranslations == ["Brot"])
    }

    @Test("Export → Import ist verlustfrei")
    func roundTrip() throws {
        let source = TestEnv()
        let cards = source.addSampleCards(6)
        let recorder = AnswerRecorder(context: source.context)
        for (i, card) in cards.enumerated() {
            recorder.recordCard(card, rating: i % 2 == 0 ? .good : .again, time: Double(i) + 0.5, mode: .writing)
        }
        recorder.recordCard(cards[0], rating: .again, time: 1, exercise: "match", useFSRS: false)
        recorder.recordItem(itemID: "s03", ok: true, time: 2, exercise: "build")
        cards[1].exampleGerman = "Beispiel"; cards[1].examplePersian = "نمونه"
        try source.context.save()
        source.settings.dailyGoal = 45

        let data = try BackupService(context: source.context, settings: source.settings).makeBackup(includeAudio: false)
        let target = TestEnv()
        try BackupService(context: target.context, settings: target.settings).apply(try parsed(String(decoding: data, as: UTF8.self)), mode: .replace)

        let a = source.fetch(Card.self).sorted { $0.id.uuidString < $1.id.uuidString }
        let b = target.fetch(Card.self).sorted { $0.id.uuidString < $1.id.uuidString }
        #expect(a.count == b.count)
        for (x, y) in zip(a, b) {
            #expect(x.id == y.id)
            #expect(x.germanTranslations == y.germanTranslations && x.persianTranslations == y.persianTranslations)
            #expect(Set(x.tags.map(\.name)) == Set(y.tags.map(\.name)))
            #expect(x.state == y.state && x.reps == y.reps && x.wrongCount == y.wrongCount && x.correctCount == y.correctCount && x.miss == y.miss)
            #expect(abs(x.stability - y.stability) < 1e-9 && abs(x.difficulty - y.difficulty) < 1e-9)
            #expect(abs((x.nextReview?.timeIntervalSince1970 ?? 0) - (y.nextReview?.timeIntervalSince1970 ?? 0)) < 0.002)
            #expect(x.exampleGerman == y.exampleGerman && x.examplePersian == y.examplePersian)
        }
        #expect(source.fetch(ReviewLog.self).count == target.fetch(ReviewLog.self).count)
        #expect(target.fetch(ItemStat.self).first?.itemID == "s03")
        #expect(target.settings.dailyGoal == 45)
    }

    @Test("Zusammenfuehren: nichts geht verloren, neuere Staende gewinnen, zweimal ist harmlos")
    func merge() throws {
        let env = TestEnv()
        let existing = env.addCard(["Haus"], ["خانه"])
        existing.id = BackupService.stableUUID(from: "mtifs800dtxnhn")
        existing.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)     // aelter als das Backup
        let own = env.addCard(["Eigene Karte"], ["کارت"])
        try env.context.save()

        let service = BackupService(context: env.context, settings: env.settings)
        let p = try parsed(webBackup)
        let first = try service.apply(p, mode: .merge)
        #expect(env.fetch(Card.self).count == 3)                    // eigene + Haus + Wasser
        #expect(first.added == 1 && first.updated == 1)
        #expect(existing.germanTranslations == ["Haus", "Gebäude"]) // neuerer Inhalt
        #expect(existing.reps == 3)                                  // neuerer Lernstand
        #expect(env.fetch(Card.self).contains { $0.id == own.id })
        let logsAfterFirst = env.fetch(ReviewLog.self).count
        #expect(logsAfterFirst == 3)
        try service.apply(p, mode: .merge)
        #expect(env.fetch(ReviewLog.self).count == logsAfterFirst)  // keine Duplikate
        #expect(env.fetch(Card.self).count == 3)
        #expect(env.fetch(ItemStat.self).count == 1)
    }

    @Test("Ungueltige oder zu neue Backups werden abgelehnt")
    func invalid() {
        #expect(throws: Never.self) { _ = BackupService.parse(Data()) }
        if case .success = BackupService.parse(Data("kein json".utf8)) { Issue.record("Text darf kein Backup sein") }
        if case .success = BackupService.parse(Data("[]".utf8)) { Issue.record("Array darf kein Backup sein") }
        if case .success = BackupService.parse(Data(#"{"foo":1}"#.utf8)) { Issue.record("Fremdes JSON") }
        let future = #"{"format":"zara-backup","formatVersion":99,"data":{"cards":[]}}"#
        if case .success = BackupService.parse(Data(future.utf8)) { Issue.record("Zu neue Version") }
    }

    @Test("Aus PWA-IDs entstehen stabile, eindeutige UUIDs; echte UUIDs bleiben erhalten")
    func stableIDs() {
        let a = BackupService.stableUUID(from: "mtifs800dtxnhn")
        #expect(a == BackupService.stableUUID(from: "mtifs800dtxnhn"))
        #expect(a != BackupService.stableUUID(from: "mtifs800dtxnho"))
        let real = UUID()
        #expect(BackupService.stableUUID(from: real.uuidString) == real)
        #expect(BackupService.stableUUID(from: real.uuidString.lowercased()) == real)
    }
}

// MARK: - Datenbank-Schnappschuesse

struct StoreSafetyTests {

    private func makeRoot() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "zara-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeStore(in root: URL, content: String = "daten") throws -> URL {
        let store = root.appending(path: "default.store")
        try Data(content.utf8).write(to: store)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: store.path + "-wal"))
        try Data("shm".utf8).write(to: URL(fileURLWithPath: store.path + "-shm"))
        return store
    }

    @Test("Schnappschuss kopiert alle Store-Dateien und laesst sich zurueckspielen")
    func snapshotAndRestore() throws {
        let work = makeRoot(); defer { try? FileManager.default.removeItem(at: work) }
        let safety = StoreSafety(root: work.appending(path: "backups"))
        let store = try makeStore(in: work, content: "original")

        let folder = try #require(try safety.snapshotStore(at: store, reason: "auto"))
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "default.store-wal").path))
        let list = safety.listSnapshots()
        #expect(list.count == 1 && list[0].reason == "auto")

        // Store „kaputtgehen" lassen, dann zurueckspielen.
        try Data("kaputt".utf8).write(to: store)
        try safety.restore(list[0], to: store)
        #expect(String(decoding: try Data(contentsOf: store), as: UTF8.self) == "original")
        // Der defekte Stand wurde beiseitegelegt, nicht geloescht.
        let aside = safety.listSnapshots().first { $0.reason == "replaced" }
        let asideFile = aside?.folder.appending(path: "default.store")
        #expect(asideFile.flatMap { try? Data(contentsOf: $0) }.map { String(decoding: $0, as: UTF8.self) } == "kaputt")
    }

    @Test("Ohne Store wird nichts kopiert")
    func noStore() throws {
        let work = makeRoot(); defer { try? FileManager.default.removeItem(at: work) }
        let safety = StoreSafety(root: work.appending(path: "backups"))
        #expect(try safety.snapshotStore(at: work.appending(path: "fehlt.store"), reason: "auto") == nil)
        #expect(safety.listSnapshots().isEmpty)
    }

    @Test("Aufraeumen: 7 automatische, 5 sonstige – 'replaced' bleibt immer erhalten")
    func pruning() throws {
        let work = makeRoot(); defer { try? FileManager.default.removeItem(at: work) }
        let safety = StoreSafety(root: work.appending(path: "backups"))
        let store = try makeStore(in: work)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<10 { try safety.snapshotStore(at: store, reason: "auto", now: base.addingTimeInterval(Double(i) * 3600)) }
        for i in 0..<8 { try safety.snapshotStore(at: store, reason: "update", now: base.addingTimeInterval(Double(100 + i) * 3600)) }
        try safety.moveAside(storeURL: store, now: base.addingTimeInterval(1_000_000))
        let list = safety.listSnapshots()
        #expect(list.filter { $0.reason == "auto" }.count == 7)
        #expect(list.filter { $0.reason == "update" }.count == 5)
        #expect(list.filter { $0.reason == "replaced" }.count == 1)
    }

    @Test("Taegliche JSON-Sicherungen: faellig nach 20 Stunden, begrenzt auf 7")
    func jsonBackups() throws {
        let work = makeRoot(); defer { try? FileManager.default.removeItem(at: work) }
        let safety = StoreSafety(root: work.appending(path: "backups"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(safety.isAutoJSONDue(now: base))
        for i in 0..<10 { try safety.writeJSONBackup(Data("{}".utf8), reason: "auto", now: base.addingTimeInterval(Double(i) * 86_400)) }
        #expect(safety.listJSONBackups().count == 7)
        let last = base.addingTimeInterval(9 * 86_400)
        #expect(!safety.isAutoJSONDue(now: last.addingTimeInterval(3600)))
        #expect(safety.isAutoJSONDue(now: last.addingTimeInterval(21 * 3600)))
    }
}

//
//  EngineTests.swift
//  DariAppTests
//
//  FSRS-Korrektur, Antwortpruefung (Persisch/Deutsch), adaptives Lernen,
//  Punkte/Level und das Verbuchen von Antworten. Entspricht den Tests der Web-Version.
//

import Testing
import Foundation
import SwiftData
@testable import DariApp

// MARK: - FSRS

struct FSRSCorrectionTests {

    let fsrs = FSRS()

    @Test("FSRS-4.5: Anfangsschwierigkeit D0 (Nochmal/Schwer/Gut/Leicht)")
    func initialDifficulty() {
        let d = FSRSRating.allCases.map { fsrs.initialDifficulty($0) }
        #expect(abs(d[0] - 7.6214) < 0.001)
        #expect(abs(d[1] - 6.3916) < 0.001)
        #expect(abs(d[2] - 5.1618) < 0.001)
        #expect(abs(d[3] - 3.9320) < 0.001)
        #expect(d[0] > d[1] && d[1] > d[2] && d[2] > d[3])
    }

    @Test("Neue Karte mit 'Gut' startet nicht bei Schwierigkeit 1")
    func goodIsNotEasiest() {
        let r = fsrs.schedule(stability: 0, difficulty: 0, state: .new, elapsedDays: 0, rating: .good)
        #expect(r.difficulty > 4)
        #expect(r.state == .review)
    }

    @Test("Schwierigkeit bleibt in 1…10; 'Nochmal' erhoeht, 'Leicht' senkt")
    func difficultyBounds() {
        var hard = 5.0, easy = 5.0
        for _ in 0..<40 { hard = fsrs.nextDifficulty(hard, rating: .again); easy = fsrs.nextDifficulty(easy, rating: .easy) }
        #expect(hard <= 10 && hard > 5)
        #expect(easy >= 1 && easy < 5)
    }

    @Test("replayDifficulty ist deterministisch")
    func replay() {
        #expect(fsrs.replayDifficulty([]) == nil)
        #expect(fsrs.replayDifficulty([.good]) == fsrs.initialDifficulty(.good))
        let manual = fsrs.nextDifficulty(fsrs.nextDifficulty(fsrs.initialDifficulty(.good), rating: .again), rating: .good)
        #expect(fsrs.replayDifficulty([.good, .again, .good]) == manual)
    }
}

// MARK: - Antwortpruefung

struct AnswerCheckerExtendedTests {

    @Test("Deutsch: Satzzeichen, Umlaut-Umschrift, ß")
    func german() {
        func ev(_ i: String, _ s: [String]) -> AnswerQuality { AnswerChecker.evaluate(input: i, against: s, isPersian: false) }
        #expect(ev("Haus.", ["Haus"]) == .perfect)
        #expect(ev("Gebaeude", ["Gebäude"]) == .perfect)
        #expect(ev("Strasse", ["Straße"]) == .perfect)
        #expect(ev("Haos", ["Haus"]) == .typo)
        #expect(ev("Tag", ["Tor"]) == .wrong)
    }

    @Test("Fehlender Artikel ist nur ein Tippfehler")
    func article() {
        #expect(AnswerChecker.evaluate(input: "Haus", against: ["das Haus"], isPersian: false) == .typo)
        #expect(AnswerChecker.evaluate(input: "das Haus", against: ["das Haus"], isPersian: false) == .perfect)
    }

    @Test("Persisch: Halbleerzeichen, Diakritika und Ziffern werden vereinheitlicht (auf Skalar-Ebene)")
    func persianNormalization() {
        func ev(_ i: String, _ s: [String]) -> AnswerQuality { AnswerChecker.evaluate(input: i, against: s, isPersian: true) }
        #expect(ev("كتاب", ["کتاب"]) == .perfect)
        #expect(ev("میخورم", ["می\u{200C}خورم"]) == .perfect)
        #expect(ev("می\u{200C}خورم", ["میخورم"]) == .perfect)
        #expect(ev("ک\u{0650}تاب", ["کتاب"]) == .perfect)
        #expect(ev("خانه.", ["خانه"]) == .perfect)
        #expect(ev("۱۲۳", ["123"]) == .perfect)
        #expect(ev("١٢٣", ["۱۲۳"]) == .perfect)
    }

    @Test("„اب“ statt „آب“ ist nur ein Tippfehler")
    func madda() {
        #expect(AnswerChecker.evaluate(input: "اب", against: ["آب"], isPersian: true) == .typo)
        #expect(AnswerChecker.evaluate(input: "آب", against: ["آب"], isPersian: true) == .perfect)
    }

    @Test("Sätze: Toleranz waechst mit der Laenge")
    func sentences() {
        let solution = "من فارسی یاد می\u{200C}گیرم."
        #expect(AnswerChecker.evaluateSentence(input: "من فارسی یاد میگیرم", against: [solution], isPersian: true) == .perfect)
        #expect(AnswerChecker.evaluateSentence(input: "من فارسی یاد میگیریم", against: [solution], isPersian: true) == .typo)
        #expect(AnswerChecker.evaluateSentence(input: "تو چای می\u{200C}نوشی", against: [solution], isPersian: true) == .wrong)
        #expect(AnswerChecker.evaluateSentence(input: "ich lerne persisch", against: ["Ich lerne Persisch."], isPersian: false) == .perfect)
    }
}

// MARK: - Adaptiv, Punkte, Verbuchen

@MainActor
struct AdaptiveAndRecordingTests {

    @Test("Schwierige Woerter werden erkannt und sortiert")
    func weakWords() {
        let now = Date()
        let good = Card(germanTranslations: ["a"], persianTranslations: ["ب"])
        good.reps = 6; good.difficulty = 3; good.stability = 30; good.lastReview = now.addingTimeInterval(-2 * 86_400)
        let bad = Card(germanTranslations: ["b"], persianTranslations: ["پ"])
        bad.reps = 5; bad.wrongCount = 3; bad.difficulty = 8; bad.lapses = 2; bad.miss = 1
        bad.stability = 2; bad.lastReview = now.addingTimeInterval(-3 * 86_400)
        let fresh = Card(germanTranslations: ["c"], persianTranslations: ["ت"])

        #expect(Adaptive.weakScore(bad, now: now) > Adaptive.weakScore(good, now: now))
        #expect(!Adaptive.isWeak(good, now: now))
        #expect(Adaptive.isWeak(bad, now: now))
        #expect(!Adaptive.isWeak(fresh, now: now))
        #expect(Adaptive.weakCards([good, bad, fresh], now: now).map(\.id) == [bad.id])
    }

    @Test("Punkte: richtig > mit Muehe > falsch; schwierige Woerter mehr; Wiederholung halb")
    func xp() {
        #expect(Gamification.xp(rating: .easy, wasWeak: false, isPractice: false) == 12)
        #expect(Gamification.xp(rating: .good, wasWeak: false, isPractice: false) == 10)
        #expect(Gamification.xp(rating: .hard, wasWeak: false, isPractice: false) == 6)
        #expect(Gamification.xp(rating: .again, wasWeak: false, isPractice: false) == 2)
        #expect(Gamification.xp(rating: .good, wasWeak: true, isPractice: false) == 15)
        #expect(Gamification.xp(rating: .good, wasWeak: false, isPractice: true) == 5)
    }

    @Test("Level: ab 50 XP Level 2, ab 200 XP Level 3")
    func levels() {
        #expect(Gamification.level(forXP: 0).level == 1)
        #expect(Gamification.level(forXP: 49).level == 1)
        #expect(Gamification.level(forXP: 50).level == 2)
        #expect(Gamification.level(forXP: 200).level == 3)
        let info = Gamification.level(forXP: 75)
        #expect(info.base == 50 && info.next == 200)
        #expect(abs(info.fraction - 25.0 / 150.0) < 0.001)
    }

    @Test("Karte verbuchen: FSRS plant neu, Verlauf wird geschrieben")
    func recordCard() {
        let env = TestEnv()
        let card = env.addCard(["a"], ["ب"])
        let recorder = AnswerRecorder(context: env.context)
        let log = recorder.recordCard(card, rating: .good, time: 2, mode: .multipleChoice)
        #expect(card.reps == 1)
        #expect(card.state == .review)
        #expect(card.nextReview != nil)
        #expect(log.exercise.isEmpty && !log.isPractice)
        #expect(env.fetch(ReviewLog.self).count == 1)
    }

    @Test("Uebungswiederholung und reine Spiele aendern den FSRS-Plan nicht")
    func practiceDoesNotReschedule() {
        let env = TestEnv()
        let card = env.addCard(["a"], ["ب"])
        let recorder = AnswerRecorder(context: env.context)
        recorder.recordCard(card, rating: .good, time: 1)
        let due = card.nextReview, reps = card.reps
        recorder.recordCard(card, rating: .again, time: 1, practice: true)
        recorder.recordCard(card, rating: .again, time: 1, exercise: "match", useFSRS: false)
        #expect(card.reps == reps)
        #expect(card.nextReview == due)
        #expect(card.miss == 2)
        let logs = env.fetch(ReviewLog.self)
        #expect(logs.count == 3)
        #expect(logs.filter(\.isPractice).count == 1)
    }

    @Test("Leitner: richtig steigt, falsch faellt zurueck; Wiederholung aendert nichts")
    func leitner() {
        let env = TestEnv()
        let recorder = AnswerRecorder(context: env.context)
        recorder.recordItem(itemID: "s01", ok: true, time: 1, exercise: "cloze")
        recorder.recordItem(itemID: "s01", ok: true, time: 1, exercise: "cloze")
        #expect(env.fetch(ItemStat.self).first?.box == 2)
        recorder.recordItem(itemID: "s01", ok: false, time: 1, exercise: "cloze", practice: true)
        #expect(env.fetch(ItemStat.self).first?.box == 2)
        recorder.recordItem(itemID: "s01", ok: false, time: 1, exercise: "cloze")
        #expect(env.fetch(ItemStat.self).first?.box == 0)
        #expect(env.fetch(ItemStat.self).count == 1)
    }
}

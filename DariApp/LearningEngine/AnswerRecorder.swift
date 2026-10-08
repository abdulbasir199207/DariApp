//
//  AnswerRecorder.swift
//  DariApp
//
//  Verbucht Antworten: FSRS-Planung der Karte, Verlaufseintrag, Leitner-Stand
//  von Satz-/Grammatikaufgaben. Gemeinsam genutzt von Vokabel-Lektionen und
//  allen Uebungen/Spielen (gleiche Regeln wie in der Web-Version).
//

import Foundation
import SwiftData

@MainActor
struct AnswerRecorder {

    let context: ModelContext
    let fsrs: FSRS

    init(context: ModelContext, fsrs: FSRS = FSRS()) {
        self.context = context
        self.fsrs = fsrs
    }

    /// Verbucht die Antwort auf eine Vokabelkarte.
    /// - Parameters:
    ///   - practice: Uebungswiederholung nach einem Fehler – aendert den FSRS-Plan nicht.
    ///   - useFSRS: `false` fuer reine Spiele (Zuordnung, Aussprache): Fehler fliessen nur
    ///     in die Schwaeche-Bewertung ein.
    @discardableResult
    func recordCard(
        _ card: Card,
        rating: FSRSRating,
        time: TimeInterval,
        mode: LearningMode = .flip,
        exercise: String = "",
        practice: Bool = false,
        useFSRS: Bool = true,
        now: Date = .now
    ) -> ReviewLog {
        let wasWeak = Adaptive.isWeak(card, now: now)
        if useFSRS && !practice {
            let result = fsrs.schedule(card: card, rating: rating, reviewDate: now)
            card.stability = result.stability
            card.difficulty = result.difficulty
            card.state = result.state
            card.interval = result.intervalDays
            card.lastReview = now
            card.nextReview = result.due
            card.lastAnswerTime = time
            card.reps += 1
            if rating == .again {
                card.wrongCount += 1
                if card.state == .relearning { card.lapses += 1 }
            } else {
                card.correctCount += 1
            }
        } else if rating == .again {
            card.miss += 1
        }
        let log = ReviewLog(
            card: card, rating: rating, answerTime: time, mode: mode, exercise: exercise,
            isPractice: practice, wasWeak: wasWeak, date: now)
        context.insert(log)
        return log
    }

    /// Verbucht eine Satz- oder Grammatikaufgabe.
    @discardableResult
    func recordItem(
        itemID: String,
        ok: Bool,
        rating: FSRSRating? = nil,
        time: TimeInterval,
        exercise: String,
        practice: Bool = false,
        now: Date = .now
    ) -> ReviewLog {
        if !practice { itemStat(for: itemID).register(ok: ok, at: now) }
        let log = ReviewLog(
            card: nil, rating: ok ? (rating ?? .good) : .again, answerTime: time, mode: .flip,
            exercise: exercise, itemID: itemID, isPractice: practice, date: now)
        context.insert(log)
        return log
    }

    func itemStat(for itemID: String) -> ItemStat {
        let id = itemID
        var descriptor = FetchDescriptor<ItemStat>(predicate: #Predicate { $0.itemID == id })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first { return existing }
        let stat = ItemStat(itemID: id)
        context.insert(stat)
        return stat
    }
}

//
//  SessionTests.swift
//  DariAppTests
//
//  Ablauf der Lerneinheiten: Wiederholung nach Fehlern, Zuordnung, Satzbildung,
//  Multiple Choice, Schreiben. Mit In-Memory-SwiftData.
//

import Testing
import Foundation
import SwiftData
@testable import DariApp

@MainActor
struct SessionTests {

    @Test("Vokabel-Lektion: falsche Karte kommt als Uebung noch einmal, ohne den Plan zu aendern")
    func learnSessionRetry() {
        let env = TestEnv()
        let cards = env.addSampleCards(4)
        let vm = LearnSessionViewModel(
            config: .init(mode: .flip, direction: .germanToPersian, limit: nil),
            candidates: cards, allCards: cards, context: env.context)
        #expect(vm.totalCount == 4)
        let failing = vm.currentCard
        vm.rate(.again)
        #expect(vm.totalCount == 5)                      // Wiederholung eingeplant
        var retries = 0
        while !vm.isFinished {
            if vm.isRetry { retries += 1; #expect(vm.currentCard?.id == failing?.id) }
            vm.rate(.good)
        }
        #expect(retries == 1)
        #expect(failing?.reps == 1)                      // Wiederholung aendert FSRS nicht
        let logs = env.fetch(ReviewLog.self)
        #expect(logs.count == 5)
        #expect(logs.filter(\.isPractice).count == 1)
        #expect(vm.xpGained > 0)
    }

    @Test("Multiple Choice: Optionen enthalten die richtige Antwort; Auswahl wird verbucht")
    func multipleChoice() {
        let env = TestEnv()
        let cards = env.addSampleCards(6)
        let vm = LearnSessionViewModel(
            config: .init(mode: .multipleChoice, direction: .persianToGerman, limit: 3),
            candidates: cards, allCards: cards, context: env.context)
        #expect(vm.choices.count == 4)
        #expect(vm.choices[vm.correctChoiceIndex] == vm.answerText)
        vm.selectChoice(vm.correctChoiceIndex)
        #expect(vm.lastQuality == .perfect)
        #expect(vm.currentCard?.reps == 1)
    }

    @Test("Uebungseinheit: falsche Auswahl plant eine Wiederholung nach drei Aufgaben")
    func practiceChoiceRetry() {
        let env = TestEnv()
        let cards = env.addSampleCards(8)
        let steps = cards.prefix(5).map { PracticeStep(kind: .choice(cardID: $0.id, direction: .germanToPersian)) }
        let vm = PracticeSessionViewModel(title: "Test", steps: steps, cards: cards, context: env.context)
        let first = cards[0]
        let set = vm.state.choices!
        vm.choose((set.correctIndex + 1) % set.options.count)         // falsch
        #expect(vm.state.quality == .wrong)
        #expect(vm.steps.count == 6)
        #expect(vm.steps[4].isRetry)                                  // index 0 + 1 + 3
        while !vm.isFinished {
            if let s = vm.state.choices, vm.state.selected == nil { vm.choose(s.correctIndex) }
            vm.next()
        }
        let logs = env.fetch(ReviewLog.self).filter { $0.card?.id == first.id }
        #expect(logs.count == 2)
        #expect(logs.filter(\.isPractice).count == 1)
        #expect(first.reps == 1)
        #expect(vm.answeredCount == 6)
    }

    @Test("Zuordnung: Fehlversuche werden gezaehlt, am Ende wird verbucht (ohne FSRS)")
    func matching() throws {
        let env = TestEnv()
        let cards = env.addSampleCards(5)
        let ids = cards.map(\.id)
        let round = MatchRound(cardIDs: ids, left: ids, right: ids.reversed(), direction: .germanToPersian)
        let vm = PracticeSessionViewModel(title: "Zuordnung", steps: [PracticeStep(kind: .match(round))], cards: cards, context: env.context)

        vm.pickMatch(left: ids[0]); vm.pickMatch(right: ids[1])       // falsch
        #expect(vm.state.match?.errors == 1)
        #expect(vm.state.match?.shake != nil)
        vm.clearShake()
        #expect(vm.state.match?.shake == nil)
        for id in ids { vm.pickMatch(left: id); vm.pickMatch(right: id) }
        let match = try #require(vm.state.match)
        #expect(match.finished && match.done.count == 5)

        let logs = env.fetch(ReviewLog.self)
        #expect(logs.count == 5 && logs.allSatisfy { $0.exercise == "match" })
        #expect(logs.filter { $0.rating == .again }.count == 2)       // die beiden verwechselten Karten
        #expect(cards.allSatisfy { $0.reps == 0 })                    // FSRS unveraendert
        #expect(cards[0].miss == 1 && cards[1].miss == 1)
    }

    @Test("Satzbildung: richtige Reihenfolge wird erkannt und im Leitner-Kasten verbucht")
    func building() throws {
        let env = TestEnv()
        env.addSampleCards(4)
        let step = PracticeStep(kind: .build(sentenceID: "s05", direction: .germanToPersian))
        let vm = PracticeSessionViewModel(title: "Satzbildung", steps: [step], cards: env.fetch(Card.self), context: env.context)
        let build = try #require(vm.state.build)
        var used = Set<Int>()
        for word in build.solution {
            let position = try #require(build.tokens.indices.first { build.tokens[$0].text == word && !used.contains($0) })
            used.insert(position)
            vm.place(position)
        }
        vm.checkBuild()
        #expect(vm.state.buildCorrect == true)
        #expect(env.fetch(ItemStat.self).first?.itemID == "s05")
        #expect(env.fetch(ItemStat.self).first?.box == 1)
    }

    @Test("Schreiben: Tippfehler wird erkannt (hard), Antwort verbucht")
    func writing() {
        let env = TestEnv()
        let cards = env.addSampleCards(4)
        let step = PracticeStep(kind: .write(cardID: cards[0].id, direction: .persianToGerman))
        let vm = PracticeSessionViewModel(title: "Schreiben", steps: [step], cards: cards, context: env.context)
        vm.state.input = "Haos"                       // Tippfehler fuer „Haus"
        vm.submitText()
        #expect(vm.state.quality == .typo)
        #expect(cards[0].reps == 1)
        #expect(env.fetch(ReviewLog.self).first?.rating == .hard)
    }

    @Test("Grammatik: Antwort wird verbucht und gemerkt")
    func grammar() throws {
        let env = TestEnv()
        let item = try #require(ContentLibrary.shared.grammar.first)
        let vm = PracticeSessionViewModel(
            title: "Grammatik", steps: [PracticeStep(kind: .grammar(itemID: item.id))], cards: [], context: env.context)
        let q = try #require(vm.state.grammar)
        vm.choose(q.choices.correctIndex)
        #expect(vm.state.quality == .perfect)
        #expect(env.fetch(ItemStat.self).first?.itemID == item.id)
        #expect(env.fetch(ReviewLog.self).first?.exercise == "grammar")
    }
}

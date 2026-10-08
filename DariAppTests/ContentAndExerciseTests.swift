//
//  ContentAndExerciseTests.swift
//  DariAppTests
//
//  Prueft die eingebauten Inhalte (Saetze, Grammatik) und die Aufgaben-Generatoren.
//

import Testing
import Foundation
import SwiftData
@testable import DariApp

// MARK: - Inhalte

struct ContentTests {

    let library = ContentLibrary.shared

    @Test("Bibliothek ist geladen")
    func loaded() {
        #expect(library.version == 1)
        #expect(library.sentences.count >= 50)
        #expect(library.grammar.count >= 60)
    }

    @Test("Saetze: IDs eindeutig, Wortarten passen zu den Woertern, Luecken sinnvoll")
    func sentences() {
        var ids = Set<String>()
        let blankChars = Set(library.blankPos)
        for s in library.sentences {
            #expect(ids.insert(s.id).inserted, "doppelte ID \(s.id)")
            #expect(s.germanPos.count == s.germanTokens.count, "\(s.id): deutsche Wortarten")
            #expect(s.persianPos.count == s.persianTokens.count, "\(s.id): persische Wortarten")
            #expect(!s.transliteration.isEmpty)
            #expect(s.persianTokens.allSatisfy { $0.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) } }, "\(s.id)")
            for (blanks, pos, count) in [(s.germanBlanks, s.positions(.german), s.germanTokens.count),
                                         (s.persianBlanks, s.positions(.persian), s.persianTokens.count)] {
                if let blanks {
                    for i in blanks { #expect(i >= 0 && i < count && blankChars.contains(pos[i]), "\(s.id): Luecke \(i)") }
                } else {
                    #expect(pos.contains { blankChars.contains($0) }, "\(s.id): keine moegliche Luecke")
                }
            }
        }
    }

    @Test("Grammatik: richtige Antwort zuerst, keine doppelten Optionen, Erklaerungen vorhanden")
    func grammar() {
        var ids = Set<String>()
        for g in library.grammar {
            #expect(ids.insert(g.id).inserted)
            #expect((3...4).contains(g.answers.count), "\(g.id)")
            #expect(Set(g.answers.map { AnswerChecker.normalize($0, isPersian: true) }).count == g.answers.count, "\(g.id): doppelte Optionen")
            #expect(g.explanation.count > 5)
            if g.exerciseLanguage == .german { #expect(!g.explanationPersian.isEmpty, "\(g.id): persische Erklaerung fehlt") }
        }
        #expect(library.grammarTopics(for: .persian).count >= 8)
        #expect(library.grammarTopics(for: .german).count >= 5)
    }
}

// MARK: - Generatoren

@MainActor
struct ExerciseFactoryTests {

    private func factory(_ seed: UInt64 = 1) -> ExerciseFactory<SeededGenerator> {
        ExerciseFactory(rng: SeededGenerator(seed: seed))
    }

    @Test("Lueckentext: Antwort in den Optionen, genau eine Luecke, keine doppelten Optionen, Gross-/Kleinschreibung verraet nichts")
    func cloze() {
        var f = factory(7)
        for sentence in ContentLibrary.shared.sentences {
            for language in [ExerciseLanguage.persian, .german] {
                for _ in 0..<4 {
                    let c = f.makeCloze(sentence: sentence, language: language)
                    #expect(c.choices.options[c.choices.correctIndex] == c.answer)
                    #expect(c.tokens.filter { $0 == nil }.count == 1)
                    #expect(Set(c.choices.options.map { AnswerChecker.normalize($0, isPersian: true) }).count == c.choices.options.count, "\(sentence.id)")
                    #expect(c.choices.options.count >= 3, "\(sentence.id)/\(language.rawValue)")
                    if language == .german, let first = c.answer.first {
                        let upper = String(first) != String(first).lowercased()
                        #expect(c.choices.options.allSatisfy { o in o.first.map { (String($0) != String($0).lowercased()) == upper } ?? false }, "\(sentence.id): Schreibweise verraet die Antwort \(c.choices.options)")
                    }
                }
            }
        }
    }

    @Test("Satzbildung: Loesung wird akzeptiert, Umkehrung nicht, gemischt ungleich Loesung")
    func build() {
        var f = factory(3)
        for sentence in ContentLibrary.shared.sentences {
            for direction in [ResolvedDirection.germanToPersian, .persianToGerman] {
                let b = f.makeBuild(sentence: sentence, direction: direction)
                #expect(b.isCorrect(b.solution))
                if b.solution.count > 1 {
                    #expect(b.tokens.map(\.text) != b.solution, "\(sentence.id) bereits geordnet")
                    let reversed = Array(b.solution.reversed())
                    if reversed != b.solution { #expect(!b.isCorrect(reversed)) }
                }
                #expect(b.tokens.map(\.text).sorted() == b.solution.sorted())
            }
        }
    }

    @Test("Uebersetzen: die Musterloesung ist perfekt")
    func translate() {
        let f = factory()
        for sentence in ContentLibrary.shared.sentences {
            for direction in [ResolvedDirection.germanToPersian, .persianToGerman] {
                let t = f.makeTranslate(sentence: sentence, direction: direction)
                #expect(AnswerChecker.evaluateSentence(input: t.solutions[0], against: t.solutions, isPersian: t.answerLanguage == .persian) == .perfect)
            }
        }
    }

    @Test("Grammatik: richtige Antwort bleibt auffindbar")
    func grammar() {
        var f = factory(11)
        for item in ContentLibrary.shared.grammar {
            let q = f.makeGrammar(item: item)
            #expect(q.choices.options[q.choices.correctIndex] == item.answers[0])
            #expect(q.choices.options.count == item.answers.count)
        }
    }

    @Test("Multiple Choice: richtige Antwort + Ablenker ohne Synonyme, auch bei sehr wenigen Karten")
    func choices() {
        for n in [1, 2, 3, 4, 10] {
            let env = TestEnv()
            let cards = env.addSampleCards(n)
            cards[0].persianTranslations.append("همنام")
            var f = factory(5)
            for card in cards {
                for language in [ExerciseLanguage.persian, .german] {
                    let set = f.makeCardChoices(card: card, answerLanguage: language, cards: cards)
                    let own = language == .persian ? card.persianTranslations : card.germanTranslations
                    #expect(set.options[set.correctIndex] == own[0])
                    #expect(set.options.filter { own.contains($0) }.count == 1)
                    #expect(set.options.count >= (n >= 4 ? 4 : 3), "n=\(n): \(set.options.count)")
                }
            }
            withExtendedLifetime(env) {}
        }
    }

    @Test("Zuordnung: nur eindeutige Paare, hoechstens 5")
    func match() {
        let env = TestEnv()
        var cards = env.addSampleCards(8)
        cards.append(env.addCard(["Haus"], ["خانه"]))      // Duplikat
        let round = factory().makeMatchRound(candidates: cards, count: 5)
        #expect(round.count == 5)
        #expect(Set(round.map(\.primaryGerman)).count == 5)
        withExtendedLifetime(env) {}
    }

    @Test("Luecke aus eigenem Beispielsatz")
    func cardCloze() {
        let env = TestEnv()
        let cards = env.addSampleCards(6)
        let cat = env.addCard(["Katze"], ["گربه"])
        cat.examplePersian = "من یک گربه دارم."
        cat.exampleGerman = "Ich habe eine Katze."
        var f = factory(2)
        let data = f.makeCardCloze(card: cat, cards: cards + [cat])
        #expect(data?.answer == "گربه")
        #expect(data?.trail == "")
        #expect(data?.choices.options.count == 4)
        #expect(data?.hint == "Ich habe eine Katze.")
        // Wort fehlt im Satz -> kein Luecken-Text
        cat.examplePersian = "من یک سگ دارم."
        #expect(f.makeCardCloze(card: cat, cards: cards + [cat]) == nil)
        withExtendedLifetime(env) {}
    }

    @Test("Plaene: schwierige Woerter, Hoeren nur wenn moeglich, Wiederholung nach Fehler")
    func plans() {
        let env = TestEnv()
        let cards = env.addSampleCards(8)
        cards[0].reps = 4; cards[0].wrongCount = 3; cards[0].difficulty = 8; cards[0].lapses = 2
        var f = factory(4)
        let weak = f.planWeak(cards: cards, direction: .mixed)
        #expect(weak.count == 1 && weak[0].isWeak)

        // Hoeren: ohne jede Sprachausgabe/Aufnahme keine Aufgaben, mit deutscher Stimme alle
        #expect(f.planListen(cards: cards, direction: .persianToGerman, count: 5, canSpeakPersian: false, canSpeakGerman: false).isEmpty)
        cards[3].audioFileName = "x.m4a"
        let onlyAudio = f.planListen(cards: cards, direction: .persianToGerman, count: 5, canSpeakPersian: false, canSpeakGerman: false)
        #expect(onlyAudio.count == 1)
        #expect(f.planListen(cards: cards, direction: .mixed, count: 5, canSpeakPersian: false, canSpeakGerman: true).count == 5)

        var steps = f.planWeak(cards: cards, direction: .germanToPersian)
        ExerciseFactory<SeededGenerator>.requeue(&steps, after: 0)
        #expect(steps.count == 2 && steps[1].isRetry)
        withExtendedLifetime(env) {}
    }

    @Test("Mix-Plan enthaelt verschiedene Aufgabentypen")
    func mix() {
        let env = TestEnv()
        let cards = env.addSampleCards(10)
        var f = factory(9)
        let steps = f.planMix(cards: cards, stats: [:], direction: .mixed, canSpeakPersian: false, canSpeakGerman: true)
        var kinds = Set<String>()
        for s in steps {
            switch s.kind {
            case .choice: kinds.insert("choice")
            case .write: kinds.insert("write")
            case .match: kinds.insert("match")
            case .listen: kinds.insert("listen")
            case .cloze, .cardCloze: kinds.insert("cloze")
            case .build: kinds.insert("build")
            case .translate: kinds.insert("translate")
            case .grammar: kinds.insert("grammar")
            case .speak: kinds.insert("speak")
            }
        }
        #expect(kinds.count >= 6, "\(kinds)")
        withExtendedLifetime(env) {}
    }
}

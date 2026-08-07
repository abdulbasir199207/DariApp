//
//  FSRSTests.swift
//  DariAppTests
//
//  Unit-Tests fuer den FSRS-Lernalgorithmus. Der Scheduler ist rein
//  funktional und laesst sich daher ohne SwiftData vollstaendig pruefen.
//

import Testing
import Foundation
@testable import DariApp

struct FSRSTests {

    let fsrs = FSRS()

    @Test("Neue Karte erhaelt positive Stabilitaet und Intervall")
    func newCardScheduling() {
        let result = fsrs.schedule(
            stability: 0, difficulty: 0, state: .new,
            elapsedDays: 0, rating: .good
        )
        #expect(result.stability > 0)
        #expect(result.intervalDays >= 1)
        #expect(result.state == .review)
        #expect(result.difficulty >= 1 && result.difficulty <= 10)
    }

    @Test("Neue Karte mit 'Nochmal' geht in den Lernzustand")
    func newCardAgain() {
        let result = fsrs.schedule(
            stability: 0, difficulty: 0, state: .new,
            elapsedDays: 0, rating: .again
        )
        #expect(result.state == .learning)
    }

    @Test("'Leicht' erzeugt laengeres Intervall als 'Gut'")
    func easyBeatsGood() {
        let good = fsrs.schedule(stability: 10, difficulty: 5, state: .review, elapsedDays: 10, rating: .good)
        let easy = fsrs.schedule(stability: 10, difficulty: 5, state: .review, elapsedDays: 10, rating: .easy)
        #expect(easy.intervalDays >= good.intervalDays)
    }

    @Test("'Nochmal' im Review fuehrt zu Relearning und kleinerer Stabilitaet")
    func forgettingReducesStability() {
        let result = fsrs.schedule(stability: 20, difficulty: 5, state: .review, elapsedDays: 15, rating: .again)
        #expect(result.state == .relearning)
        #expect(result.stability < 20)
    }

    @Test("Abrufwahrscheinlichkeit faellt mit der Zeit")
    func retrievabilityDecreases() {
        let r0 = fsrs.retrievability(elapsedDays: 0, stability: 10)
        let r5 = fsrs.retrievability(elapsedDays: 5, stability: 10)
        let r20 = fsrs.retrievability(elapsedDays: 20, stability: 10)
        #expect(r0 > r5)
        #expect(r5 > r20)
        #expect(r0 <= 1.0)
    }

    @Test("Intervall respektiert die Obergrenze")
    func intervalRespectsMaximum() {
        let params = FSRSParameters(weights: FSRSParameters.default.weights, requestRetention: 0.9, maximumIntervalDays: 30)
        let engine = FSRS(parameters: params)
        let result = engine.schedule(stability: 5000, difficulty: 3, state: .review, elapsedDays: 1, rating: .easy)
        #expect(result.intervalDays <= 30)
    }
}

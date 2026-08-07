//
//  FSRSParameters.swift
//  DariApp
//
//  Konfigurierbare Parameter des FSRS-Algorithmus.
//  Die 17 Gewichte entsprechen den offiziellen FSRS-4.5-Defaultwerten
//  (aus grossen Anki-Datensaetzen optimiert). Fuer eine Einzelperson sind
//  die Defaults ein sehr guter Ausgangspunkt.
//

import Foundation

struct FSRSParameters: Sendable, Equatable {

    /// 17 Modellgewichte (w0...w16).
    var weights: [Double]

    /// Gewuenschte Ziel-Retention (0...1). 0.9 = 90 % Abrufwahrscheinlichkeit
    /// zum geplanten Wiederholungszeitpunkt – guter Standard.
    var requestRetention: Double

    /// Obergrenze fuer Intervalle in Tagen (verhindert unrealistisch lange
    /// Abstaende bei einer aktiv genutzten Lern-App).
    var maximumIntervalDays: Int

    static let `default` = FSRSParameters(
        weights: [
            0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975,
            0.0310, 1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246,
            1.5870, 0.2272, 2.8755
        ],
        requestRetention: 0.90,
        maximumIntervalDays: 365
    )
}

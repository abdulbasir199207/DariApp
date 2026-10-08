//
//  ItemStat.swift
//  DariApp
//
//  Lernstand einer Satz- oder Grammatikaufgabe (einfaches Leitner-System,
//  Kaesten 0...5). Fehler setzen die Aufgabe zurueck, richtige Antworten
//  schieben sie in groessere Abstaende.
//

import Foundation
import SwiftData

@Model
final class ItemStat {

    @Attribute(.unique) var itemID: String = ""
    var box: Int = 0
    var due: Date = Date.distantPast
    var okCount: Int = 0
    var badCount: Int = 0
    var last: Date = Date.distantPast

    init(itemID: String) {
        self.itemID = itemID
    }
}

extension ItemStat {

    /// Abstaende je Kasten in Tagen.
    static let boxDays: [Int] = [0, 1, 2, 4, 8, 16]

    /// Verbucht ein Ergebnis und plant die naechste Wiederholung.
    func register(ok: Bool, at date: Date = .now, calendar: Calendar = .current) {
        if ok {
            okCount += 1
            box = min(box + 1, ItemStat.boxDays.count - 1)
        } else {
            badCount += 1
            box = 0
        }
        due = calendar.date(byAdding: .day, value: ItemStat.boxDays[box], to: date) ?? date
        last = date
    }
}

//
//  AudioFileStore.swift
//  DariApp
//
//  Verwaltet die physischen Audiodateien im App-Sandbox-Verzeichnis.
//  Getrennt von Aufnahme/Wiedergabe, damit die Dateiverwaltung isoliert
//  testbar bleibt und die Karte nur den Dateinamen speichert.
//

import Foundation

struct AudioFileStore: Sendable {

    /// Unterverzeichnis in Documents fuer alle Aufnahmen.
    private let directoryName = "Audio"

    /// Basisverzeichnis (Documents/Audio), wird bei Bedarf angelegt.
    var directory: URL {
        let documents = URL.documentsDirectory
        let dir = documents.appending(path: directoryName, directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Vollstaendige URL zu einem gespeicherten Dateinamen.
    func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    /// Erzeugt einen neuen, eindeutigen Dateinamen (m4a).
    func newFileName() -> String {
        "\(UUID().uuidString).m4a"
    }

    /// Prueft, ob eine Datei existiert.
    func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    /// Loescht eine Aufnahme (idempotent).
    func delete(_ fileName: String) {
        let target = url(for: fileName)
        try? FileManager.default.removeItem(at: target)
    }
}

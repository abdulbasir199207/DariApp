# ZARA – Architektur

ZARA (internes Projekt: „DariApp") ist eine Sprachlern-App für **Persisch ↔ Deutsch**.
Es gibt zwei Ausprägungen mit gleichem Datenformat und gleichen Lernregeln:

| | Native iOS-App (`DariApp/`) | Web-App / PWA (`WebApp/`) |
|---|---|---|
| Technik | Swift 6, SwiftUI, SwiftData, iOS 26 | ein HTML-Dokument, entsteht aus `WebApp/src/` |
| Daten | SwiftData (SQLite) + UserDefaults | `localStorage` + IndexedDB |
| Bauen | GitHub Actions (kein Mac nötig) | `node WebApp/build.mjs` |
| Austausch | Backup-Format `zara-backup` v3 (JSON) – in beide Richtungen kompatibel | |

Bundle-ID (`com.dari.DariApp`), Projekt-/Modulname (`DariApp`) und die Adresse der Web-App
bleiben **unverändert**, damit bestehende Daten bei Updates erhalten bleiben. Nur der
Anzeigename ist „ZARA".

## Grundprinzipien

1. **Datensicherheit vor allem anderen.** Nie überschreiben, ohne dass eine Kopie existiert
   (Details unten).
2. **MVVM**: Views deklarativ, Logik in ViewModels (`@Observable`) und zustandslosen
   Engine-Typen. Alles Fachliche (FSRS, Antwortprüfung, Planer, Generatoren, Backup) ist
   ohne UI testbar.
3. **Eine Quelle für Inhalte**: Sätze und Grammatik stehen in `WebApp/src/js/30-content.js`;
   `WebApp/tools/export-content.mjs` erzeugt daraus `DariApp/Resources/zara-content.json`.
4. **Gleiche Lernregeln in beiden Apps** (FSRS 4.5, Schwäche-Bewertung, XP/Level, Leitner).

## Native App – Ordner (`DariApp/`)

| Ordner | Inhalt |
|---|---|
| `App/` | Einstieg, `RootView` (5 Tabs), `ModelContainerFactory` (kein `fatalError`) |
| `Models/` | `Card`, `Tag`, `ReviewLog`, `ItemStat`, Enums |
| `LearningEngine/` | `FSRS`, `Adaptive` (schwierige Wörter), `ReviewScheduler`, `AnswerRecorder`, `Gamification` |
| `Content/` | `ContentLibrary` (Sätze, Grammatik aus JSON) |
| `Practice/` | `ExerciseFactory`: Aufgaben-Generatoren und Übungspläne |
| `ViewModels/` | Lern-Sitzung (Karten), Übungs-Sitzung (alle Aufgabentypen), Statistik, Karteneditor |
| `Backup/` | `BackupService` (Export/Import), `StoreSafety` (Datenbank-Schnappschüsse), Austauschformat |
| `Views/` | Heute, Üben, Karten, Statistik, Mehr/Backup, Wiederherstellung |
| `Audio/` | Aufnahme/Wiedergabe, Sprachausgabe (TTS) |
| `Components/`, `DesignSystem/` | Wiederverwendbare Bausteine, Farben, Typografie, Katzen-Logo |

### Tabs
**Heute** (Tagesziel, Serie, Level, klarer nächster Schritt) · **Üben** (Vokabeln, Spiele, Sätze &
Grammatik) · **Karten** · **Statistik** · **Mehr** (Einstellungen, Daten & Backup).

### Lernfunktionen
- Karten lernen: Umdrehen, Multiple Choice, Schreiben – beide Richtungen und gemischt.
- Schwierige Wörter (adaptiv), Zuordnung, Hören (Sprachausgabe/eigene Aufnahmen),
  Aussprache (Selbstvergleich), 5-Minuten-Spiel.
- Lückentext (Bibliothek **und** eigene Beispielsätze), Satzbildung, Übersetzen.
- Grammatik: Persisch (Pronomen, „sein", Gegenwart, Vergangenheit, Verneinung, Wortstellung,
  Plural, Unbestimmtheit & را, Fragewörter, Besitz, Ezafe) und Deutsch (Artikel, Verbendungen,
  Perfekt, Wortstellung, Verneinung, Plural, Akkusativ – mit persischen Erklärungen).
- Gamification mit Lernnutzen: XP nur fürs richtige Erinnern (mehr für schwierige Wörter),
  Level, Tagesziel, Serie, Meilensteine.

### Adaptives Lernen
`Adaptive.weakScore` kombiniert Fehlerquote, FSRS-Schwierigkeit, Rückfälle, Spiel-Fehler und
Vergessenswahrscheinlichkeit. Der Planer bevorzugt schwache Karten; falsch beantwortete Aufgaben
kommen nach drei Aufgaben als Übung wieder (ändert den FSRS-Plan nicht, halbe Punkte).
Sätze/Grammatik: Leitner-Kästen (`ItemStat`).

## Datensicherheit

**Native App**
- `ModelContainerFactory` kopiert vor dem Öffnen die Datenbank (`default.store`, `-wal`, `-shm`)
  – nach jedem App-Update und täglich – nach `Application Support/ZARA-Backups/store/`.
- Scheitert das Öffnen, startet die App in `RecoveryView` statt abzustürzen: Sicherung
  zurückspielen oder „neu beginnen" – defekte Dateien werden nur **beiseitegelegt**.
- Täglich ein lesbares JSON-Backup (`…/json/`), nur wenn Daten vorhanden sind.
- Speicherfehler werden nicht mehr verschluckt (`ModelContext.saveReporting`), die Startseite
  warnt und verweist auf das Backup.
- Backup einspielen: Prüfung, Vorschau, **vorher automatische Sicherung**, „Ersetzen" oder
  „Zusammenführen" (nichts geht verloren), alles-oder-nichts mit Rollback, **Rückgängig**.
- Audio: Eine Aufnahme wird erst beim Speichern der Karte ersetzt/gelöscht („Abbrechen" verliert nichts).

**Web-App** (`WebApp/src/js/40-storage.js`, `45-backup.js`)
- Schema-Versionen + Migrationen; die v2→v3-Migration verändert keine Termine/Stabilität.
- Defekte Daten werden nie überschrieben: Quarantäne, letzter guter Stand, sonst
  Wiederherstellungs-Bildschirm (Speichern gesperrt).
- Schnappschüsse in IndexedDB (täglich, vor Migration/Wiederherstellung/Löschen), Rücklese-Prüfung
  bei jedem Schreiben, `storage.persist()`.
- Backup mit Prüfsumme und optionalen Aufnahmen, Vorschau, Ersetzen/Zusammenführen, Rückgängig.

## Austauschformat `zara-backup` v3
Zeitangaben in Millisekunden; Karten: `id, de[], fa[], translit, tags[], audio, active, fav, state,
s, d, interval, reps, lapses, correct, wrong, miss, lastReview, nextReview, lastTime, createdAt,
updatedAt, exDe, exFa`; `logs[]`, `sent{}` (Leitner), `settings{}`, optional `audio{id→base64}`.
PWA-IDs (keine UUIDs) werden deterministisch auf UUIDs abgebildet; wiederholtes Einspielen ist
idempotent. Auch Backups der Web-App 2.0 werden gelesen.

## Tests
- Native: `DariAppTests/` (Swift Testing, In-Memory-SwiftData) und `DariAppUITests/` laufen bei
  jedem Push im Simulator (GitHub Actions). Ergebnisse und Bildschirmfotos landen im Zweig `ci-logs`.
- Web: `cd WebApp && npm test` (Logik, Migration, Backup – inkl. echter 2.0-Daten aus
  `tests/fixtures`), End-to-End im Browser mit `tests/driver.js` (`tests/serve.mjs`).

## Bauen und Installieren
1. Push auf `main` (oder `zara-update`) → GitHub Actions baut die **unsignierte** `ZARA-unsigned.ipa`
   (Artefakt „ZARA-unsigned-ipa").
2. Mit Sideloadly/AltStore auf dem iPhone signieren und installieren (Bundle-ID unverändert →
   Update behält die Daten).
3. Web-App: `node WebApp/build.mjs` → `WebApp/ZARA.html` an **dieselbe** Artifact-Adresse veröffentlichen.

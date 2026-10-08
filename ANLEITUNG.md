# ZARA auf dem iPhone – Schritt für Schritt

ZARA gibt es in zwei Formen. Beide verstehen dasselbe Backup-Format, du kannst also jederzeit
wechseln oder beide parallel nutzen.

| | Web-App (läuft schon) | Native iPhone-App |
|---|---|---|
| Installation | Link öffnen, „Zum Home-Bildschirm" | `ZARA-unsigned.ipa` per Sideloadly installieren |
| Aktualisieren | wird automatisch neu geladen | neue `.ipa` bauen lassen und erneut installieren |
| Besonderheit | sofort nutzbar | läuft eigenständig, Daten in der App-Datenbank |

## A) Web-App aktualisieren (ohne etwas zu verlieren)

1. **Zuerst ein Backup sichern:** ZARA → Mehr → „Backup sichern" → „In Dateien sichern".
2. Öffne die ZARA-Seite (derselbe Link wie bisher) und lade sie neu. In „Mehr" steht unten
   **Version 3.0**. Beim ersten Start sichert ZARA deine Daten automatisch (Vor-Update-Kopie) und
   aktualisiert sie. Deine Karten, Termine und Einstellungen bleiben unverändert.
3. Name und Symbol auf dem Home-Bildschirm ändern sich nicht von selbst (das macht iOS beim
   Hinzufügen). Willst du das ZARA-Katzen-Symbol: Backup sichern → altes Symbol löschen →
   Seite im Browser öffnen → „Zum Home-Bildschirm" → in ZARA „Backup wiederherstellen".

## B) Native App bauen und installieren

1. Auf GitHub (Repository **DariApp**) → **Actions** → den neuesten grünen Lauf öffnen →
   unten bei **Artifacts** „ZARA-unsigned-ipa" herunterladen und entpacken → `ZARA-unsigned.ipa`.
   (Der Lauf wird bei jedem Push auf `main` automatisch gestartet. Er führt vorher alle Tests aus.)
2. **Sideloadly** (Windows) öffnen, das iPhone per Kabel verbinden, `ZARA-unsigned.ipa` hineinziehen,
   mit deiner Apple-ID installieren. Die App-Kennung (`com.dari.DariApp`) bleibt gleich, deshalb
   behält ein späteres Update alle Daten.
3. Auf dem iPhone: Einstellungen → Allgemein → VPN & Geräteverwaltung → Entwickler-App vertrauen.
   Mit einer kostenlosen Apple-ID läuft die App 7 Tage; danach in Sideloadly erneut installieren
   (die Daten bleiben erhalten – vorher trotzdem ein Backup sichern).
4. **Daten aus der Web-App übernehmen:** In der Web-App Backup sichern (Datei), die Datei aufs
   iPhone legen (Dateien-App), in ZARA → Mehr → Daten & Backup → „Backup-Datei einspielen".

## Datensicherheit in Kurzform

- ZARA legt täglich eine automatische Sicherung an und vor jedem Update, jeder Wiederherstellung
  und jedem Löschen. Fehlerhafte Daten werden nie überschrieben.
- Sichere trotzdem regelmäßig ein Backup in „Dateien" oder iCloud Drive – ZARA erinnert dich daran.
- Geht beim Start etwas schief, zeigt ZARA einen Wiederherstellungs-Bildschirm statt abzustürzen.

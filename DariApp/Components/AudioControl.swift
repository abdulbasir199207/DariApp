//
//  AudioControl.swift
//  DariApp
//
//  UI-Baustein fuer Aufnahme, Wiedergabe und Loeschen der Karten-Audiodatei.
//  Kapselt die Interaktion mit `AudioRecorder`; die Karte kennt nur den
//  Dateinamen (Binding).
//

import SwiftUI

struct AudioControl: View {
    let audio: AudioRecorder
    @Binding var fileName: String?

    var body: some View {
        HStack(spacing: Spacing.md) {
            switch audio.state {
            case .recording:
                Button(role: .destructive) {
                    audio.stopRecording()
                } label: {
                    Label("Aufnahme stoppen", systemImage: "stop.circle.fill")
                }
            default:
                Button {
                    Task { await record() }
                } label: {
                    Label(fileName == nil ? "Aufnehmen" : "Neu aufnehmen",
                          systemImage: "mic.circle.fill")
                }
            }

            if let fileName, audio.state != .recording {
                Button {
                    if audio.state == .playing {
                        audio.stopPlayback()
                    } else {
                        audio.play(fileName: fileName)
                    }
                } label: {
                    Image(systemName: audio.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.turquoise)
                }

                Button(role: .destructive) {
                    delete(fileName)
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .font(DariFont.body)
        .tint(Palette.sage)
        .task(id: audio.permissionDenied) { }
        .overlay(alignment: .bottomLeading) {
            if audio.permissionDenied {
                Text("Mikrofonzugriff verweigert – in den iOS-Einstellungen erlauben.")
                    .font(DariFont.caption)
                    .foregroundStyle(Palette.error)
            }
        }
    }

    private func record() async {
        // Vorherige Aufnahme entfernen, wenn neu aufgenommen wird.
        if let old = fileName {
            audio.deleteRecording(fileName: old)
        }
        let created = await audio.startRecording()
        if let created {
            fileName = created
        }
    }

    private func delete(_ name: String) {
        audio.deleteRecording(fileName: name)
        fileName = nil
    }
}

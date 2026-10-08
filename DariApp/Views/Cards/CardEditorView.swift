//
//  CardEditorView.swift
//  DariApp
//
//  Komfortabler Karteneditor: mehrere deutsche/persische Begriffe,
//  Lautschrift, Tags mit Vorschlaegen, Audioaufnahme, Aktiv/Favorit.
//  Vor dem Speichern erfolgt eine Duplikatwarnung.
//

import SwiftUI
import SwiftData

struct CardEditorView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Alle bestehenden Tags fuer Vorschlaege.
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var viewModel: CardEditorViewModel
    @State private var audio = AudioRecorder()
    @State private var newTagText = ""
    @State private var showDuplicateAlert = false

    init(card: Card? = nil, context: ModelContext) {
        _viewModel = State(initialValue: CardEditorViewModel(context: context, card: card))
    }

    var body: some View {
        Form {
            germanSection
            persianSection
            transliterationSection
            exampleSection
            tagsSection
            audioSection
            statusSection
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle(viewModel.isEditing ? "Karte bearbeiten" : "Neue Karte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { attemptSave() }
                    .disabled(!viewModel.canSave)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { viewModel.discardChanges(); dismiss() }
            }
        }
        .alert("Aehnliche Karten gefunden", isPresented: $showDuplicateAlert) {
            Button("Trotzdem speichern") { viewModel.save(); dismiss() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text(duplicateMessage)
        }
    }

    // MARK: - Abschnitte

    private var germanSection: some View {
        Section("Deutsch") {
            MultiTermEditor(
                terms: $viewModel.germanTerms,
                placeholder: "Deutscher Begriff",
                isPersian: false
            )
        }
    }

    private var persianSection: some View {
        Section("Persisch") {
            MultiTermEditor(
                terms: $viewModel.persianTerms,
                placeholder: "واژه فارسی",
                isPersian: true
            )
        }
    }

    private var transliterationSection: some View {
        Section("Lautschrift (nur Hilfe)") {
            TextField("z. B. khâne", text: $viewModel.transliteration)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private var exampleSection: some View {
        Section {
            TextField("جملهٔ نمونه", text: $viewModel.examplePersian)
                .environment(\.layoutDirection, .rightToLeft)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField("Deutsche Übersetzung", text: $viewModel.exampleGerman)
        } header: {
            Text("Beispielsatz (optional)")
        } footer: {
            Text("Für Lückentexte aus deinen eigenen Wörtern – das persische Wort muss im Satz vorkommen.")
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            if !viewModel.tagNames.isEmpty {
                FlowLayout(spacing: Spacing.xs) {
                    ForEach(viewModel.tagNames, id: \.self) { name in
                        TagChip(title: name, onRemove: { removeTag(name) })
                    }
                }
            }
            HStack {
                TextField("Tag hinzufuegen", text: $newTagText)
                    .onSubmit { addTag(newTagText) }
                Button {
                    addTag(newTagText)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(suggestedTags, id: \.self) { name in
                            Button { addTag(name) } label: { TagChip(title: name) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var audioSection: some View {
        Section("Audio (Persisch)") {
            AudioControl(
                audio: audio, fileName: $viewModel.audioFileName,
                onObsolete: { viewModel.audioReplaced(old: $0) },
                onRecorded: { viewModel.audioRecorded($0) })
        }
    }

    private var statusSection: some View {
        Section {
            Toggle("Aktiv", isOn: $viewModel.isActive)
            Toggle("Favorit", isOn: $viewModel.isFavorite)
        }
    }

    // MARK: - Logik

    private var suggestedTags: [String] {
        let current = Set(viewModel.tagNames.map(Tag.normalize))
        let query = newTagText.trimmingCharacters(in: .whitespaces).lowercased()
        return allTags
            .map(\.name)
            .filter { !current.contains($0) }
            .filter { query.isEmpty || $0.lowercased().contains(query) }
            .prefix(8)
            .map { $0 }
    }

    private func addTag(_ raw: String) {
        let name = Tag.normalize(raw)
        guard !name.isEmpty else { return }
        if !viewModel.tagNames.contains(where: { Tag.normalize($0) == name }) {
            viewModel.tagNames.append(name)
        }
        newTagText = ""
    }

    private func removeTag(_ name: String) {
        viewModel.tagNames.removeAll { $0 == name }
    }

    private func attemptSave() {
        if viewModel.checkForDuplicates() {
            showDuplicateAlert = true
        } else {
            viewModel.save()
            dismiss()
        }
    }

    private var duplicateMessage: String {
        let terms = viewModel.duplicateWarning
            .prefix(3)
            .map { $0.primaryGerman + " / " + $0.primaryPersian }
            .joined(separator: "\n")
        return "Es existieren bereits aehnliche Karten:\n\(terms)"
    }
}

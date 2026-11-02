import SwiftData
import SwiftUI
import MyRussianCore

/// A notebook page for one word: Russian → meaning → confidence → my pronunciation → my recordings → notes.
struct WordDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let word: VocabularyWord

    @State private var editingWord = false
    @State private var noteEditor: NoteEditorTarget?
    @State private var confirmingDelete = false
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 52

    enum NoteEditorTarget: Identifiable {
        case new
        case edit(PronunciationNote)
        var id: String {
            switch self {
            case .new: "new"
            case let .edit(note): note.id.uuidString
            }
        }
    }

    private var service: VocabularyService { VocabularyService(context: context, audioStore: app.audioStore) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                WordPhotoBox(word: word)
                confidence
                pronunciation
                RecordingsSection(word: word)
                notesSection
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Word", systemImage: "pencil") { editingWord = true }
                    Button("Delete Word", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .accessibilityIdentifier("detail.more")
            }
        }
        .sheet(isPresented: $editingWord) { EditWordSheet(word: word) }
        .sheet(item: $noteEditor) { target in
            switch target {
            case .new: PronunciationNoteEditor(word: word, note: nil)
            case let .edit(note): PronunciationNoteEditor(word: word, note: note)
            }
        }
        .confirmationDialog("Delete “\(word.russian)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Word", role: .destructive) {
                app.player.stop()
                service.delete(word)
                dismiss()
            }
        } message: {
            Text("Its pronunciation notes and recordings will be deleted too.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(word.russian)
                .font(.system(size: wordSize, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.5)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("detail.russian")
            Text(word.meaning)
                .font(.title3)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Menu {
                Picker("Topic", selection: Binding(get: { word.topic }, set: { service.setTopic($0, for: word) })) {
                    Text("None").tag(VocabularyTopic?.none)
                    ForEach(VocabularyTopic.allCases) { item in
                        Label(item.title, systemImage: item.systemImage).tag(Optional(item))
                    }
                }
            } label: {
                Label(word.topic?.title ?? "Add topic", systemImage: word.topic?.systemImage ?? "tag")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12), in: .capsule)
            }
            .padding(.top, 4)
            .accessibilityIdentifier("detail.topic")
            Text("Added \(word.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var confidence: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Confidence", systemImage: "gauge.with.dots.needle.33percent")
            ConfidencePicker(selection: Binding(get: { word.confidence },
                                                set: { service.setConfidence($0, for: word) }))
            Text(word.confidence.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
    }

    private var pronunciation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardHeader(title: "My pronunciation", systemImage: "mouth")
                Button("Add", systemImage: "plus") { noteEditor = .new }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .accessibilityLabel("Add pronunciation note")
                    .accessibilityIdentifier("detail.addPronunciation")
            }
            let notes = word.sortedPronunciationNotes
            if notes.isEmpty {
                Button { noteEditor = .new } label: {
                    Label("Add how you remember the sound, e.g. 🇫🇷 Kadé", systemImage: "plus.bubble")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            } else {
                VStack(spacing: 10) {
                    ForEach(notes) { note in
                        PronunciationNoteCard(note: note)
                            .onTapGesture { noteEditor = .edit(note) }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { noteEditor = .edit(note) }
                                Button("Delete", systemImage: "trash", role: .destructive) { service.deleteNote(note) }
                            }
                            .accessibilityAction(named: "Edit") { noteEditor = .edit(note) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardHeader(title: "Notes", systemImage: "note.text")
                Button("Edit") { editingWord = true }
                    .font(.subheadline)
            }
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    if word.example.isEmpty && word.notes.isEmpty {
                        Text("Add an example sentence or anything that helps you remember.")
                            .foregroundStyle(.secondary)
                    }
                    if !word.example.isEmpty {
                        Text(word.example)
                            .font(Theme.russian(.title3, weight: .regular))
                            .italic()
                            .textSelection(.enabled)
                    }
                    if !word.notes.isEmpty {
                        Text(word.notes).textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct PronunciationNoteCard: View {
    let note: PronunciationNote

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(note.flag)
                .font(.largeTitle)
                .accessibilityLabel(note.language.name)
            VStack(alignment: .leading, spacing: 4) {
                // Shown exactly as typed.
                Text(verbatim: note.text)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                Text(note.language.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let explanation = note.explanation {
                    Text(verbatim: explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .contentShape(.rect)
    }
}

/// Add or edit a phonetic mnemonic. Autocorrect and capitalisation are off: the text is saved verbatim.
struct PronunciationNoteEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let word: VocabularyWord
    let note: PronunciationNote?

    @State private var text: String
    @State private var language: ReferenceLanguage
    @State private var explanation: String
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    init(word: VocabularyWord, note: PronunciationNote?) {
        self.word = word
        self.note = note
        _text = State(initialValue: note?.text ?? "")
        _language = State(initialValue: note?.language ?? .french)
        _explanation = State(initialValue: note?.explanation ?? "")
    }

    private var service: VocabularyService { VocabularyService(context: context, audioStore: app.audioStore) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(word.russian)
                        .font(Theme.russian(.title))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
                Section("Sounds like, in…") {
                    LanguagePicker(selection: $language)
                }
                Section {
                    TextField("e.g. Kadé", text: $text)
                        .font(.title2)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.default)
                        .focused($focused)
                        .accessibilityIdentifier("pronunciation.text")
                    TextField("Explanation (optional)", text: $explanation, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)
                } header: {
                    Text("My spelling")
                } footer: {
                    Text("Saved exactly as you type it. It’s a personal memory aid, not a transliteration.")
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                if let note {
                    Section {
                        Button("Delete Note", systemImage: "trash", role: .destructive) {
                            service.deleteNote(note)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(note == nil ? "Pronunciation" : "Edit Pronunciation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(text.allSatisfy(\.isWhitespace))
                        .accessibilityIdentifier("pronunciation.save")
                }
            }
            .onAppear {
                if note == nil {
                    language = ReferenceLanguage.suggested(recentlyUsed: service.recentLanguages())
                }
                focused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        do {
            let explanationText = explanation.allSatisfy(\.isWhitespace) ? nil : explanation
            if let note {
                try service.updateNote(note, text: text, language: language, explanation: explanationText)
            } else {
                service.addNote(try PronunciationNoteDraft(text: text, language: language, explanation: explanationText), to: word)
            }
            dismiss()
        } catch {
            errorMessage = "Enter your spelling first."
        }
    }
}

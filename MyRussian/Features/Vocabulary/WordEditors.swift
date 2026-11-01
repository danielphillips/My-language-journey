import SwiftData
import SwiftUI
import MyRussianCore

/// Quick capture: Russian, meaning, confidence and an optional phonetic mnemonic in one sheet.
struct AddWordSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var russian = ""
    @State private var meaning = ""
    @State private var confidence: ConfidenceLevel = .learning
    @State private var topic: VocabularyTopic?
    @State private var pronunciation = ""
    @State private var language: ReferenceLanguage = .french
    @State private var errorMessage: String?
    @State private var saved = 0
    @FocusState private var focus: Field?

    private enum Field { case russian, meaning, pronunciation }

    private var service: VocabularyService { VocabularyService(context: context, audioStore: app.audioStore) }

    private var duplicate: DuplicateCheck<UUID> {
        guard !russian.isEmpty, !meaning.isEmpty else { return .unique }
        return service.duplicateCheck(russian: russian, meaning: meaning)
    }

    private var canSave: Bool {
        !VocabularyText.cleanedForStorage(russian).isEmpty
            && !VocabularyText.cleanedForStorage(meaning).isEmpty
            && !duplicate.blocksSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Russian", text: $russian, prompt: Text("слово"))
                        .font(Theme.russian(.title))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .russian)
                        .submitLabel(.next)
                        .onSubmit { focus = .meaning }
                        .accessibilityIdentifier("addWord.russian")
                    TextField("English meaning", text: $meaning)
                        .focused($focus, equals: .meaning)
                        .submitLabel(.next)
                        .onSubmit { focus = .pronunciation }
                        .accessibilityIdentifier("addWord.meaning")
                } footer: {
                    duplicateFooter
                }

                Section("Confidence") {
                    ConfidencePicker(selection: $confidence)
                }

                Section {
                    Picker("Topic", selection: $topic) {
                        Text("None").tag(VocabularyTopic?.none)
                        ForEach(VocabularyTopic.allCases) { item in
                            Label(item.title, systemImage: item.systemImage).tag(Optional(item))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("addWord.topic")
                }

                Section {
                    LanguagePicker(selection: $language)
                    TextField("How you’d spell it", text: $pronunciation)
                        .font(.title3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .pronunciation)
                        .accessibilityIdentifier("addWord.pronunciation")
                } header: {
                    Text("My pronunciation (optional)")
                } footer: {
                    Text("Your own spelling, kept exactly as you type it.")
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
            .navigationTitle("New Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("addWord.save")
                }
            }
            .onAppear {
                language = ReferenceLanguage.suggested(recentlyUsed: service.recentLanguages())
                focus = .russian
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    @ViewBuilder
    private var duplicateFooter: some View {
        switch duplicate {
        case .unique:
            EmptyView()
        case .duplicate:
            Label("Already in your vocabulary with this meaning.", systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
        case let .sameWordDifferentMeaning(ids):
            let others = service.allWords().filter { ids.contains($0.id) }.map(\.meaning).joined(separator: ", ")
            Label("You also have this word as “\(others)”. It will be saved as a separate meaning.",
                  systemImage: "info.circle")
        }
    }

    private func save() {
        do {
            let note = pronunciation.allSatisfy(\.isWhitespace)
                ? nil
                : try PronunciationNoteDraft(text: pronunciation, language: language)
            try service.addWord(russian: russian, meaning: meaning, confidence: confidence, pronunciation: note, topic: topic)
            saved += 1
            dismiss()
        } catch let error as VocabularyServiceError {
            errorMessage = error.message
        } catch {
            errorMessage = "This word couldn’t be saved."
        }
    }
}

struct EditWordSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let word: VocabularyWord

    @State private var russian: String
    @State private var meaning: String
    @State private var example: String
    @State private var notes: String
    @State private var topic: VocabularyTopic?
    @State private var errorMessage: String?

    init(word: VocabularyWord) {
        self.word = word
        _topic = State(initialValue: word.topic)
        _russian = State(initialValue: word.russian)
        _meaning = State(initialValue: word.meaning)
        _example = State(initialValue: word.example)
        _notes = State(initialValue: word.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("Russian", text: $russian)
                        .font(Theme.russian(.title2))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("English meaning", text: $meaning)
                    Picker("Topic", selection: $topic) {
                        Text("None").tag(VocabularyTopic?.none)
                        ForEach(VocabularyTopic.allCases) { item in
                            Label(item.title, systemImage: item.systemImage).tag(Optional(item))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Example sentence") {
                    TextField("Optional", text: $example, axis: .vertical)
                        .font(Theme.russian(.body, weight: .regular))
                        .lineLimit(1...4)
                        .accessibilityIdentifier("editWord.example")
                }
                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...8)
                        .accessibilityIdentifier("editWord.notes")
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        do {
                            let service = VocabularyService(context: context, audioStore: app.audioStore)
                            try service.update(word, russian: russian, meaning: meaning, example: example, notes: notes)
                            service.setTopic(topic, for: word)
                            dismiss()
                        } catch let error as VocabularyServiceError {
                            errorMessage = error.message
                        } catch {
                            errorMessage = "Changes couldn’t be saved."
                        }
                    }
                    .accessibilityIdentifier("editWord.save")
                }
            }
        }
    }
}

/// Four-level confidence control. Large hit targets; selected state exposed to accessibility.
struct ConfidencePicker: View {
    @Binding var selection: ConfidenceLevel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ConfidenceLevel.allCases) { level in
                let isSelected = selection == level
                Button {
                    withAnimation(.snappy) { selection = level }
                } label: {
                    VStack(spacing: 6) {
                        ConfidenceDots(level: level)
                        Text(level.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(isSelected ? level.color : .secondary)
                    .background(isSelected ? level.color.opacity(0.16) : Color.secondary.opacity(0.08),
                                in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(level.title)
                .accessibilityHint(level.explanation)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("confidence.\(level.title.lowercased())")
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Flag buttons for the borrowed sound system.
struct LanguagePicker: View {
    @Binding var selection: ReferenceLanguage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReferenceLanguage.allCases) { language in
                let isSelected = selection == language
                Button {
                    selection = language
                } label: {
                    VStack(spacing: 2) {
                        Text(language.flag).font(.title)
                        Text(language.shortName).font(.caption2.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
                                in: .rect(cornerRadius: 14))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("pronunciation.language.\(language.rawValue)")
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

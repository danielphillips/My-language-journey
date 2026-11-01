import SwiftData
import SwiftUI
import MyRussianCore

/// The running session, shown at the top of Journey while a timer is active.
struct LiveSessionCard: View {
    @Environment(LiveTimerStore.self) private var timerStore
    let onStop: (StudySessionDraft) -> Void
    @State private var confirmingDiscard = false

    private var notes: Binding<String> {
        Binding(get: { timerStore.timer.notes }, set: { timerStore.setNotes($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(timerStore.isRunning ? "Studying" : "Paused",
                      systemImage: timerStore.isRunning ? "record.circle" : "pause.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(timerStore.isRunning ? .red : .secondary)
                    .symbolEffect(.pulse, isActive: timerStore.isRunning)
                Spacer()
                Menu {
                    Picker("Category", selection: Binding(get: { timerStore.timer.category },
                                                          set: { timerStore.setCategory($0) })) {
                        ForEach(StudyCategory.allCases) { category in
                            Label(category.title, systemImage: category.systemImage).tag(category)
                        }
                    }
                } label: {
                    Label(timerStore.timer.category.title, systemImage: timerStore.timer.category.systemImage)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(DurationFormat.clock(timerStore.elapsed(at: context.date)))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("timer.elapsed")
            }

            TextField("Add a note", text: notes, axis: .vertical)
                .lineLimit(1...3)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    if timerStore.isRunning {
                        Button("Pause", systemImage: "pause.fill") { timerStore.pause() }
                            .buttonStyle(.glass)
                            .accessibilityIdentifier("timer.pause")
                    } else {
                        Button("Resume", systemImage: "play.fill") { timerStore.resume() }
                            .buttonStyle(.glass)
                            .accessibilityIdentifier("timer.resume")
                    }
                    Button("Stop & Save", systemImage: "stop.fill") {
                        if let session = timerStore.stop() { onStop(session) }
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("timer.stop")
                    Spacer()
                    Button("Discard", systemImage: "trash", role: .destructive) { confirmingDiscard = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("timer.discard")
                }
                .controlSize(.large)
            }
        }
        .padding(20)
        .glassEffect(.regular.tint(Color.accentColor.opacity(0.12)), in: .rect(cornerRadius: Theme.cardRadius))
        .confirmationDialog("Discard this session?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard Session", role: .destructive) { timerStore.discard() }
        } message: {
            Text("The time won’t be recorded.")
        }
        .sensoryFeedback(.selection, trigger: timerStore.isRunning)
    }
}

/// Pick a category and go: one tap starts the timer.
struct StartSessionSheet: View {
    @Environment(LiveTimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(StudyCategory.allCases) { category in
                        Button {
                            timerStore.start(category: category)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: category.systemImage).font(.title2)
                                Text(category.title).font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                        }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("start.category.\(category.rawValue)")
                    }
                }
                .padding()
            }
            .navigationTitle("What are you studying?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.start, trigger: timerStore.timer.isActive)
    }
}

/// Manual entry, and editing or deleting an existing session.
struct LogSessionSheet: View {
    enum Mode {
        case new(StudySessionDraft?)
        case edit(StudySession)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var minutes: Int
    @State private var finishedAt: Date
    @State private var category: StudyCategory
    @State private var notes: String
    @State private var errorMessage: String?

    private static let quickDurations = [15, 30, 45, 60, 90]

    init(mode: Mode) {
        self.mode = mode
        let draft: StudySessionDraft? = switch mode {
        case let .new(draft): draft
        case let .edit(session): session.draft
        }
        _minutes = State(initialValue: draft.map { max(Int(($0.duration / 60).rounded()), 1) } ?? 30)
        _finishedAt = State(initialValue: draft?.end ?? .now)
        _category = State(initialValue: draft?.category ?? .vocabulary)
        _notes = State(initialValue: draft?.notes ?? "")
    }

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.quickDurations, id: \.self) { value in
                                Chip(title: DurationFormat.short(Double(value) * 60), isSelected: minutes == value) {
                                    minutes = value
                                }
                                .accessibilityIdentifier("log.duration.\(value)")
                            }
                        }
                    }
                    Stepper(value: $minutes, in: 1...(24 * 60), step: 5) {
                        LabeledContent("Duration", value: DurationFormat.short(Double(minutes) * 60))
                    }
                }

                Section("When") {
                    DatePicker("Finished", selection: $finishedAt, in: ...Date.now)
                }

                Section("Category") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(StudyCategory.allCases) { item in
                            Chip(title: item.title, systemImage: item.systemImage, isSelected: category == item) {
                                category = item
                            }
                            .accessibilityIdentifier("log.category.\(item.rawValue)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if case let .edit(session) = mode {
                    Section {
                        Button("Delete Session", systemImage: "trash", role: .destructive) {
                            StudyLog(context: context).delete(session)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Session" : "Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .accessibilityIdentifier("log.save")
                }
            }
            .sensoryFeedback(.error, trigger: errorMessage)
        }
    }

    private func save() {
        let duration = TimeInterval(minutes * 60)
        let draft = StudySessionDraft(start: finishedAt - duration, duration: duration, category: category,
                                      notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        let log = StudyLog(context: context)
        do {
            switch mode {
            case .new: try log.log(draft)
            case let .edit(session): try log.update(session, with: draft)
            }
            dismiss()
        } catch let error as StudySessionValidationError {
            withAnimation { errorMessage = error.message }
        } catch {
            withAnimation { errorMessage = "Something went wrong saving this session." }
        }
    }
}

/// Selectable capsule. Uses a plain style so several can share one form row.
struct Chip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: systemImage == nil ? nil : .infinity)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.snappy, value: isSelected)
    }
}

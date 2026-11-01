import AVFoundation
import Combine
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import MyRussianCore

/// Record, import, play, rename and delete personal recordings for a word.
struct RecordingsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    let word: VocabularyWord

    @State private var importing = false
    @State private var renaming: AudioRecording?
    @State private var errorMessage: String?
    @State private var savedTakes = 0

    private var flow: RecordingFlow { app.recordingFlow }
    private var service: VocabularyService { VocabularyService(context: context, audioStore: app.audioStore) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "My recordings", systemImage: "waveform")

            recorder

            if flow.state == .permissionDenied {
                permissionMessage
            }

            let recordings = word.sortedRecordings
            if !recordings.isEmpty {
                VStack(spacing: 0) {
                    ForEach(recordings) { recording in
                        RecordingRow(recording: recording,
                                     isPlaying: app.player.playingID == recording.id,
                                     isAvailable: service.isAvailable(recording),
                                     onPlay: { app.player.toggle(id: recording.id, url: service.url(for: recording)) },
                                     onRename: { renaming = recording },
                                     onDelete: { delete(recording) })
                        .contextMenu {
                            Button("Rename or Annotate", systemImage: "pencil") { renaming = recording }
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(recording) }
                        }
                        .accessibilityDeleteAction { delete(recording) }
                        if recording.id != recordings.last?.id { Divider().padding(.leading, 60) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            Task { await importClip(result) }
        }
        .sheet(item: $renaming) { recording in
            RenameRecordingSheet(recording: recording)
        }
        .alert("Recording", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: app.player.errorMessage) { _, message in
            if let message {
                errorMessage = message
                app.player.errorMessage = nil
            }
        }
        .onChange(of: flow.state) { _, state in
            if case let .failed(message) = state {
                errorMessage = message
                flow.acknowledgeError()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            app.player.stop()
            save(flow.handleInterruption())
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { save(flow.stop()) }
        }
        .onDisappear {
            app.player.stop()
            save(flow.stop())
        }
        .sensoryFeedback(.success, trigger: savedTakes)
        .sensoryFeedback(.impact(weight: .medium), trigger: flow.isRecording)
    }

    @ViewBuilder
    private var recorder: some View {
        if flow.isRecording {
            HStack(spacing: 14) {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.variableColor.iterative, isActive: true)
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text(DurationFormat.clock(flow.elapsed))
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                Spacer()
                Button("Cancel", systemImage: "xmark") { flow.cancel() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .accessibilityLabel("Cancel recording")
                    .accessibilityIdentifier("recordings.cancel")
                Button("Stop", systemImage: "stop.fill") { save(flow.stop()) }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .accessibilityIdentifier("recordings.stop")
            }
            .padding()
            .glassEffect(.regular.tint(.red.opacity(0.12)), in: .rect(cornerRadius: 18))
        } else {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        app.player.stop()
                        Task { await flow.start() }
                    } label: {
                        Label("Record “\(word.russian)”", systemImage: "mic.fill")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(flow.state == .requestingPermission)
                    .accessibilityIdentifier("recordings.record")

                    Button {
                        importing = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .lineLimit(1)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Import audio file")
                    .accessibilityHint("Choose a short audio clip from Files")
                    .accessibilityIdentifier("recordings.import")
                }
                .controlSize(.large)
            }
        }
    }

    private var permissionMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Microphone access is off", systemImage: "mic.slash")
                .font(.headline)
            Text("Allow microphone access in Settings to record yourself. You can still import audio files.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                flow.acknowledgeError()
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 18))
    }

    private func save(_ result: RecordingResult?) {
        guard let result else { return }
        service.addRecording(result, to: word)
        savedTakes += 1
    }

    private func delete(_ recording: AudioRecording) {
        if app.player.playingID == recording.id { app.player.stop() }
        withAnimation { service.deleteRecording(recording) }
    }

    private func importClip(_ result: Result<URL, Error>) async {
        do {
            let url = try result.get()
            let recording = try await AudioImport.importClip(from: url, store: app.audioStore)
            service.addRecording(recording, to: word, title: url.deletingPathExtension().lastPathComponent)
            savedTakes += 1
        } catch let error as AudioFileStoreError {
            errorMessage = error.message
        } catch {
            errorMessage = "That file couldn’t be imported. Choose a short audio clip."
        }
    }
}

private struct RecordingRow: View {
    let recording: AudioRecording
    let isPlaying: Bool
    let isAvailable: Bool
    let onPlay: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(!isAvailable)
            .accessibilityLabel(isPlaying ? "Stop \(recording.title)" : "Play \(recording.title)")

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .font(.body.weight(.medium))
                if !recording.annotation.isEmpty {
                    Text(recording.annotation).font(.subheadline).foregroundStyle(.secondary)
                }
                if isAvailable {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Label("File missing", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: true)
            }
            Text(DurationFormat.clock(recording.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Menu {
                Button("Rename or Annotate", systemImage: "pencil", action: onRename)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .accessibilityIdentifier("recording.delete")
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 44)
                    .contentShape(.rect)
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Actions for \(recording.title)")
            .accessibilityIdentifier("recording.actions.\(recording.title)")
        }
        .padding(.leading)
        .padding(.trailing, 6)
        .padding(.vertical, 10)
    }
}

private struct RenameRecordingSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let recording: AudioRecording
    @State private var title: String
    @State private var annotation: String

    init(recording: AudioRecording) {
        self.recording = recording
        _title = State(initialValue: recording.title)
        _annotation = State(initialValue: recording.annotation)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Annotation, e.g. “slow, careful stress”", text: $annotation, axis: .vertical)
                    .lineLimit(1...4)
            }
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        VocabularyService(context: context, audioStore: app.audioStore)
                            .rename(recording, title: title, annotation: annotation)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension View {
    /// Adds a destructive accessibility action; visual deletion is via the context menu
    /// because rows live in a scroll view rather than a List.
    func accessibilityDeleteAction(_ action: @escaping () -> Void) -> some View {
        accessibilityAction(named: "Delete", action)
    }
}

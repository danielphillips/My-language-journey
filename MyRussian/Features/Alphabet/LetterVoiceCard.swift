import SwiftUI
import UIKit
import MyRussianCore

/// Record, replay, compare with the synthetic voice, and delete your own pronunciation
/// of the selected letter's name and of its example word.
struct LetterVoiceCard: View {
    let letter: RussianLetter
    let library: LetterAudioLibrary
    let flow: RecordingFlow
    let recordingKind: LetterAudioKind?
    let onRecord: (LetterAudioKind) -> Void
    let onStop: () -> Void
    let onPlayMine: (LetterAudioKind) -> Void
    let onPlayVoice: (LetterAudioKind) -> Void
    let onDelete: (LetterAudioKind) -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("My voice", systemImage: "waveform")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(library.recordedNameCount) of 33 letters")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.gold)
            }

            row(kind: .letterName, title: "Letter", russian: letter.spokenName)
            Divider()
            row(kind: .exampleWord, title: "Example", russian: letter.exampleWord)

            if flow.state == .permissionDenied {
                HStack {
                    Label("Microphone access is off", systemImage: "mic.slash")
                        .font(.footnote)
                    Spacer()
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        flow.acknowledgeError()
                    }
                    .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.85), in: .rect(cornerRadius: 24))
    }

    private func row(kind: LetterAudioKind, title: String, russian: String) -> some View {
        let isRecording = recordingKind == kind && flow.isRecording
        let hasMine = library.has(letter.id, kind)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(russian)
                    .font(Theme.russian(.body))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)

            if isRecording {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text(DurationFormat.clock(flow.elapsed))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.red)
                }
                Button("Stop", systemImage: "stop.fill", action: onStop)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .accessibilityLabel("Stop recording")
                    .accessibilityIdentifier("alphabet.stop.\(kind.rawValue)")
            } else {
                if hasMine {
                    Button("Mine", systemImage: "play.fill") { onPlayMine(kind) }
                        .buttonStyle(.glass)
                        .tint(Theme.gold)
                        .accessibilityLabel("Play my \(title.lowercased())")
                        .accessibilityIdentifier("alphabet.playMine.\(kind.rawValue)")
                }
                Button("Voice", systemImage: "speaker.wave.2") { onPlayVoice(kind) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .accessibilityLabel("Play the synthetic voice")
                    .accessibilityIdentifier("alphabet.playVoice.\(kind.rawValue)")
                Button(hasMine ? "Re-record" : "Record", systemImage: "mic.fill") { onRecord(kind) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .tint(.red)
                    .disabled(flow.isRecording)
                    .accessibilityLabel(hasMine ? "Record my \(title.lowercased()) again" : "Record my \(title.lowercased())")
                    .accessibilityIdentifier("alphabet.record.\(kind.rawValue)")
                if hasMine {
                    Menu {
                        Button("Delete My Recording", systemImage: "trash", role: .destructive) { onDelete(kind) }
                            .accessibilityIdentifier("alphabet.delete.\(kind.rawValue)")
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .frame(width: 30, height: 34)
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Delete my \(title.lowercased()) recording")
                    .accessibilityIdentifier("alphabet.deleteMenu.\(kind.rawValue)")
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: isRecording)
    }
}

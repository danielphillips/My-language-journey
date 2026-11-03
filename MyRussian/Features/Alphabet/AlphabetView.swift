import SwiftData
import SwiftUI
import MyRussianCore

/// Азбука: the 33 letters as a grid of glass tiles. Tap a letter to hear its name.
struct AlphabetView: View {
    @State private var speaker = RussianSpeaker()
    @State private var selected: RussianLetter = RussianAlphabet.letters[0]
    @State private var taps = 0
    @State private var tray = WordTray()
    @State private var verdict: WordVerdict = .empty
    @State private var dictionaryCache: [String: Bool] = [:]
    @Query private var words: [VocabularyWord]
    @Query private var letterRecordings: [LetterRecording]
    @Environment(AppEnvironment.self) private var app
    @Environment(\.modelContext) private var context
    @State private var library = LetterAudioLibrary(recorded: [])
    /// What is being recorded right now (letter and kind), if anything.
    @State private var recordingTarget: LetterAudioKey?

    /// 33 letters in rows of four. A plain (non-lazy) grid: small, and every tile exists for accessibility.
    private let rows: [[RussianLetter]] = stride(from: 0, to: RussianAlphabet.letters.count, by: 4).map {
        Array(RussianAlphabet.letters[$0..<min($0 + 4, RussianAlphabet.letters.count)])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    AlphabetHero(letter: selected,
                                 speaker: speaker,
                                 speakLetter: { speak(selected) },
                                 speakWord: { play(selected, .exampleWord) })

                    LetterVoiceCard(letter: selected,
                                    library: library,
                                    flow: app.recordingFlow,
                                    recordingKind: recordingTarget?.letterID == selected.id ? recordingTarget?.kind : nil,
                                    onRecord: { kind in startRecording(selected, kind) },
                                    onStop: finishRecording,
                                    onPlayMine: { kind in play(selected, kind) },
                                    onPlayVoice: { kind in play(selected, kind, preferSyntheticVoice: true) },
                                    onDelete: { kind in
                                        letterStore.delete(letterID: selected.id, kind: kind)
                                        refreshLibrary()
                                    })

                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                            ForEach(rows, id: \.first!.id) { row in
                                GridRow {
                                    ForEach(row) { letter in
                                        LetterTile(letter: letter, isSelected: letter == selected,
                                                   isRecorded: library.hasRecordedName(letter.id), onTap: {
                                            if app.recordingFlow.isRecording { finishRecording() }
                                            selected = letter
                                            speak(letter)
                                        }, onLongPress: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { tray.append(letter) }
                                        })
                                        .equatable()
                                    }
                                    // Keep the last row's tiles the same width as the others.
                                    ForEach(row.count..<4, id: \.self) { _ in Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                                }
                            }
                    }

                    Legend()

                    Label("Tap to hear a letter · Long-press to spell a word", systemImage: "hand.tap")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Backdrop(letter: selected))
            .safeAreaInset(edge: .bottom) {
                if !tray.isEmpty {
                    WordTrayBar(tray: tray, verdict: verdict, speaker: speaker,
                                onPlay: { speaker.speak(tray.text) },
                                onBackspace: { withAnimation(.snappy) { tray.removeLast() } },
                                onClear: { withAnimation(.smooth) { tray.clear() } },
                                onRemove: { id in withAnimation(.snappy) { tray.remove(id) } })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: tray.isEmpty)
            .sensoryFeedback(.impact(weight: .medium), trigger: tray.items.count) { old, new in new > old }
            .sensoryFeedback(.success, trigger: verdict.isCorrect) { old, new in new && !old }
            .navigationTitle("Alphabet")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: taps)
            .onAppear {
                speaker.prepare()
                refreshLibrary()
            }
            .onDisappear {
                finishRecording()
                speaker.stop()
            }
            .onChange(of: letterRecordings.map(\.id)) { refreshLibrary() }
            .onChange(of: tray.text) { updateVerdict() }
            .onChange(of: words.count) { updateVerdict() }
        }
    }

    /// Runs only when the tray's letters (or your vocabulary) change, never on every redraw.
    private func updateVerdict() {
        var cache = dictionaryCache
        verdict = WordChecker.verdict(for: tray.text,
                                      vocabulary: words.map { KnownWord(russian: $0.russian, meaning: $0.meaning) },
                                      isDictionaryWord: { word in
                                          if let known = cache[word] { return known }
                                          let found = RussianDictionary.contains(word)
                                          cache[word] = found
                                          return found
                                      })
        dictionaryCache = cache
    }

    private func speak(_ letter: RussianLetter) {
        taps += 1
        play(letter, .letterName)
    }

    private var letterStore: LetterRecordingStore {
        LetterRecordingStore(context: context, audioStore: app.audioStore)
    }

    private func refreshLibrary() {
        library = letterStore.library()
    }

    /// Your own recording by default when you have one; otherwise (or on request) the synthetic voice.
    private func play(_ letter: RussianLetter, _ kind: LetterAudioKind, preferSyntheticVoice: Bool = false) {
        let text = kind == .letterName ? letter.spokenName : letter.exampleWord
        if library.playback(for: letter.id, kind, preferSyntheticVoice: preferSyntheticVoice) == .personal,
           let mine = letterStore.recording(letterID: letter.id, kind: kind) {
            speaker.playRecording(at: app.audioStore.url(for: mine.relativePath), label: text)
        } else {
            speaker.speak(text, slow: kind == .letterName)
        }
    }

    private func startRecording(_ letter: RussianLetter, _ kind: LetterAudioKind) {
        speaker.stop()
        app.player.stop()
        recordingTarget = LetterAudioKey(letterID: letter.id, kind: kind)
        Task { await app.recordingFlow.start() }
    }

    /// Stops any recording in progress and saves it to the letter it was started for.
    private func finishRecording() {
        guard let target = recordingTarget else { return }
        recordingTarget = nil
        guard let result = app.recordingFlow.stop() else { return }
        letterStore.save(result, letterID: target.letterID, kind: target.kind)
        refreshLibrary()
    }
}

// MARK: - Hero

private struct AlphabetHero: View {
    let letter: RussianLetter
    let speaker: RussianSpeaker
    let speakLetter: () -> Void
    let speakWord: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 96

    private var isSpeaking: Bool { speaker.speakingText != nil }

    private var kindName: String {
        switch letter.kind {
        case .vowel: "гласная · vowel"
        case .consonant: "согласная · consonant"
        case .sign: "знак · sign"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Button(action: speakLetter) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(letter.uppercase)
                        .font(.system(size: glyphSize, weight: .semibold, design: .serif))
                    Text(letter.lowercase)
                        .font(.system(size: glyphSize * 0.55, weight: .regular, design: .serif))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: letter)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(letter.uppercase), \(letter.spokenName)")
            .accessibilityHint("Plays the letter")

            VStack(alignment: .leading, spacing: 6) {
                Text(kindName)
                    .font(Theme.russian(.caption, weight: .medium))
                    .foregroundStyle(.tint)
                    .textCase(.lowercase)

                HStack(spacing: 8) {
                    Text(letter.spokenName)
                        .font(Theme.russian(.title2))
                        .accessibilityIdentifier("alphabet.hero.name")
                    Button(action: speakLetter) {
                        Image(systemName: "speaker.wave.2.fill")
                            .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                            .font(.subheadline)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Play \(letter.spokenName)")
                }

                Text(letter.soundHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: speakWord) {
                    HStack(spacing: 6) {
                        Text(letter.exampleWord).font(Theme.russian(.body))
                        Text("· \(letter.exampleMeaning)").foregroundStyle(.secondary)
                        Image(systemName: "play.circle.fill").foregroundStyle(.tint)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.1), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityLabel("Example: \(letter.exampleWord), \(letter.exampleMeaning)")
                .accessibilityIdentifier("alphabet.hero.example")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.accentColor.opacity(0.08)), in: .rect(cornerRadius: 32))
        .padding(.top, 4)
    }
}

// MARK: - Tiles

private struct LetterTile: View, Equatable {
    let letter: RussianLetter
    let isSelected: Bool
    /// You've recorded this letter's name: a subtle gold outline.
    let isRecorded: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var pulse = 0
    @State private var lift = 0

    /// Closures are ignored: a tile redraws only when its letter or selection changes.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.letter == rhs.letter && lhs.isSelected == rhs.isSelected && lhs.isRecorded == rhs.isRecorded
    }

    private var tint: Color {
        switch letter.kind {
        case .vowel: .accentColor.opacity(isSelected ? 0.35 : 0.16)
        case .consonant: .primary.opacity(isSelected ? 0.14 : 0.02)
        case .sign: .secondary.opacity(isSelected ? 0.2 : 0.06)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
                Text(letter.uppercase)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                Text(letter.lowercase)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(letter.kind == .sign ? .secondary : .primary)
            .frame(maxWidth: .infinity, minHeight: 82)
            .contentShape(.rect(cornerRadius: 20))
        .gesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    lift += 1
                    onLongPress()
                }
                .exclusively(before: TapGesture().onEnded {
                    pulse += 1
                    onTap()
                })
        )
        .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.gold.opacity(0.75), lineWidth: isRecorded ? 1.2 : 0)
                .padding(isSelected ? 3 : 0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
        }
        .overlay {
            // Ripple on tap.
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor, lineWidth: 2)
                .keyframeAnimator(initialValue: RippleState(), trigger: pulse) { content, state in
                    content.scaleEffect(state.scale).opacity(state.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1.0, duration: 0)
                        SpringKeyframe(1.25, duration: 0.45)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0.7, duration: 0)
                        LinearKeyframe(0, duration: 0.45)
                    }
                }
                .allowsHitTesting(false)
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: lift) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.18, duration: 0.14)
                SpringKeyframe(1.0, duration: 0.35)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(letter.uppercase), \(letter.spokenName)")
        .accessibilityValue(isRecorded ? "Your recording" : "")
        .accessibilityHint("\(letter.kind.title). Double-tap to hear it.")
        .accessibilityAction { onTap() }
        .accessibilityAction(named: "Add to word") { onLongPress() }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("letter.\(letter.lowercase)")
    }
}

private struct RippleState {
    var scale: CGFloat = 1
    var opacity: Double = 0
}

// MARK: - Legend and backdrop

private struct Legend: View {
    var body: some View {
        HStack(spacing: 16) {
            item("Vowels · 10", color: .accentColor.opacity(0.5))
            item("Consonants · 21", color: .primary.opacity(0.25))
            item("Signs · 2", color: .secondary.opacity(0.4))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func item(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
        }
    }
}

/// Soft accent wash with the selected letter as a giant, faint watermark.
private struct Backdrop: View {
    let letter: RussianLetter

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemGroupedBackground)
            LinearGradient(colors: [Color.accentColor.opacity(0.22), .clear],
                           startPoint: .top, endPoint: .center)
            Text(letter.uppercase)
                .font(.system(size: 420, weight: .bold, design: .serif))
                .foregroundStyle(Color.accentColor.opacity(0.06))
                .offset(x: 60, y: -40)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: letter)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AlphabetView()
}

// MARK: - Word tray

/// Floating glass tray for spelling a word from long-pressed letters.
private struct WordTrayBar: View {
    let tray: WordTray
    let verdict: WordVerdict
    let speaker: RussianSpeaker
    let onPlay: () -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void
    let onRemove: (UUID) -> Void

    private var isSpeaking: Bool { speaker.speakingText == tray.text }

    private var status: (text: String, meaning: String?) {
        switch verdict {
        case let .inYourVocabulary(meaning): ("In your vocabulary", meaning)
        case let .exampleWord(meaning): ("Russian word", meaning)
        case .dictionaryWord: ("Russian word", nil)
        case .empty, .unrecognised: ("Long-press letters to keep spelling", nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if verdict.isCorrect {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: tray.text)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Correct word")
                        .accessibilityIdentifier("tray.correct")
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(status.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(verdict.isCorrect ? .green : .secondary)
                    if let meaning = status.meaning {
                        Text(meaning).font(.subheadline)
                    }
                }
                Spacer()
                Button("Clear", systemImage: "xmark", action: onClear)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Clear word")
                    .accessibilityIdentifier("tray.clear")
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: verdict.isCorrect)

            HStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(tray.items) { item in
                            Text(item.letter.lowercase)
                                .font(.system(size: 30, weight: .semibold, design: .serif))
                                .frame(minWidth: 34, minHeight: 50)
                                .padding(.horizontal, 2)
                                .background((verdict.isCorrect ? Color.green : Color.accentColor).opacity(0.14),
                                            in: .rect(cornerRadius: 12))
                                .onTapGesture { onRemove(item.id) }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.2).combined(with: .opacity).combined(with: .offset(y: -36)),
                                    removal: .scale(scale: 0.4).combined(with: .opacity)))
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel(tray.text)
                    .accessibilityHint("Tap a letter to remove it")
                    .accessibilityIdentifier("tray.word")
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.trailing)

                Button("Delete letter", systemImage: "delete.left", action: onBackspace)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityIdentifier("tray.backspace")

                Button(action: onPlay) {
                    Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "play.fill")
                        .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 24)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(verdict.isCorrect ? .green : .accentColor)
                .accessibilityLabel("Play word")
                .accessibilityIdentifier("tray.play")
            }
        }
        .padding(14)
        .glassEffect(.regular.tint((verdict.isCorrect ? Color.green : Color.accentColor).opacity(0.08)),
                     in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.green.opacity(verdict.isCorrect ? 0.6 : 0), lineWidth: 1.5)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

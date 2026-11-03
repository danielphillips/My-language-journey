import SwiftUI
import MyRussianCore

/// Азбука: the 33 letters as a grid of glass tiles. Tap a letter to hear its name.
struct AlphabetView: View {
    @State private var speaker = RussianSpeaker()
    @State private var selected: RussianLetter = RussianAlphabet.letters[0]
    @State private var taps = 0

    /// 33 letters in rows of four. A plain (non-lazy) grid: small, and every tile exists for accessibility.
    private let rows: [[RussianLetter]] = stride(from: 0, to: RussianAlphabet.letters.count, by: 4).map {
        Array(RussianAlphabet.letters[$0..<min($0 + 4, RussianAlphabet.letters.count)])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    AlphabetHero(letter: selected,
                                 isSpeaking: speaker.speakingText != nil,
                                 speakLetter: { speak(selected) },
                                 speakWord: { speaker.speak(selected.exampleWord, slow: false) })

                    GlassEffectContainer(spacing: 10) {
                        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                            ForEach(rows, id: \.first!.id) { row in
                                GridRow {
                                    ForEach(row) { letter in
                                        LetterTile(letter: letter, isSelected: letter == selected) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = letter }
                                            speak(letter)
                                        }
                                    }
                                    // Keep the last row's tiles the same width as the others.
                                    ForEach(row.count..<4, id: \.self) { _ in Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                                }
                            }
                        }
                    }

                    Legend()
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Backdrop(letter: selected))
            .navigationTitle("Alphabet")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: taps)
            .onDisappear { speaker.stop() }
        }
    }

    private func speak(_ letter: RussianLetter) {
        taps += 1
        speaker.speak(letter.spokenName)
    }
}

// MARK: - Hero

private struct AlphabetHero: View {
    let letter: RussianLetter
    let isSpeaking: Bool
    let speakLetter: () -> Void
    let speakWord: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 96

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
                .contentTransition(.interpolate)
                .id(letter.id)
                .transition(.blurReplace)
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
            .animation(.smooth, value: letter)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.accentColor.opacity(0.08)), in: .rect(cornerRadius: 32))
        .padding(.top, 4)
    }
}

// MARK: - Tiles

private struct LetterTile: View {
    let letter: RussianLetter
    let isSelected: Bool
    let action: () -> Void

    @State private var pulse = 0

    private var tint: Color {
        switch letter.kind {
        case .vowel: .accentColor.opacity(isSelected ? 0.35 : 0.16)
        case .consonant: .primary.opacity(isSelected ? 0.14 : 0.02)
        case .sign: .secondary.opacity(isSelected ? 0.2 : 0.06)
        }
    }

    var body: some View {
        Button {
            pulse += 1
            action()
        } label: {
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
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 20))
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
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("\(letter.uppercase), \(letter.spokenName)")
        .accessibilityHint(letter.kind.title)
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
                .id(letter.id)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: letter)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AlphabetView()
}

import Testing
@testable import MyRussianCore

@Suite("Letter audio library")
struct LetterAudioLibraryTests {
    let library = LetterAudioLibrary(recorded: [
        LetterAudioKey(letterID: "ж", kind: .letterName),
        LetterAudioKey(letterID: "ж", kind: .exampleWord),
        LetterAudioKey(letterID: "к", kind: .exampleWord)
    ])

    @Test func yourRecordingPlaysByDefaultWhenYouHaveOne() {
        #expect(library.playback(for: "ж", .letterName) == .personal)
        #expect(library.playback(for: "ж", .exampleWord) == .personal)
    }

    @Test func theSyntheticVoicePlaysWhenThereIsNoRecording() {
        #expect(library.playback(for: "а", .letterName) == .synthesized)
        #expect(library.playback(for: "к", .letterName) == .synthesized, "Only the example word of к is recorded")
    }

    @Test func theSyntheticVoiceCanAlwaysBeChosen() {
        #expect(library.playback(for: "ж", .letterName, preferSyntheticVoice: true) == .synthesized)
    }

    @Test func goldOutlineMarksLettersWhoseNameYouHaveRecorded() {
        #expect(library.hasRecordedName("ж"))
        #expect(!library.hasRecordedName("к"))
        #expect(library.recordedNameCount == 1)
    }

    @Test func recordingKindsHaveStableRawValues() {
        #expect(LetterAudioKind.letterName.rawValue == "letter")
        #expect(LetterAudioKind.exampleWord.rawValue == "example")
    }
}

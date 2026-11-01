# My Russian

A personal Russian learning companion for iPhone: **effort** (study hours towards a TORFL goal), **competence** (an A1 roadmap of milestones) and **vocabulary** (the words you really know, with your own pronunciation mnemonics and recordings).

Native SwiftUI · iOS 26 (Liquid Glass) · SwiftData · Swift Charts · AVFoundation · no backend, no accounts, no dependencies.

## Run it

Requires a Mac with **Xcode 26** or later.

1. Open `MyRussian.xcodeproj`.
2. Select the **MyRussian** scheme and an iPhone simulator (iOS 26), then press **⌘R**.
3. To run on your own iPhone: *Signing & Capabilities* → choose your team (a free Apple ID works for personal installs). You may need to change the bundle identifier `com.danielphillips.MyRussian` to something unique.

## Tests

| Suite | What it covers | How to run |
|---|---|---|
| `Packages/MyRussianCore` (113 tests) | Goals and pace, study timer, statistics (week/day/month splitting), validation and duplicates, milestones, vocabulary rules, pronunciation notes, audio file store, recording flow (fake microphone) | `cd Packages/MyRussianCore && swift test` (macOS or Linux), or **⌘U** in Xcode |
| `MyRussianTests` | SwiftData integration in isolated in‑memory containers, relationships, cascade deletes and audio file cleanup, relaunch persistence, live timer persistence | **⌘U** in Xcode |
| `MyRussianUITests` | Onboarding, A1 goal, logging a session, adding a word, confidence, 🇫🇷 and 🇧🇷 notes, recording a take, persistence after relaunch | **⌘U** in Xcode |

`scripts/tdd.sh "<label>"` runs the core suite and appends the result to [`docs/TDD-LOG.md`](docs/TDD-LOG.md), the red/green evidence for each slice. The git history follows the same red → green → refactor sequence.

## Verification status

This V1 was written in a Linux cloud environment without Xcode.

- ✅ **Verified:** all 113 core tests pass (Swift 6.4.2). `LiveTimerStore` and `DurationFormat` compiled and passed their app tests. All app and test files pass the Swift parser.
- ⚠️ **Unverified:** compiling the SwiftUI, SwiftData and AVFoundation code, the SwiftData integration tests, the UI tests, and the visual design. Expect a few compile fixes on the first Xcode build.

## Structure

```
Packages/MyRussianCore/   Domain logic (Foundation only): fully test-driven
MyRussian/
  App/                    Entry point, launch configuration, preview data
  Persistence/            SwiftData models (CloudKit-ready) and services
  Services/               Live timer store, AVFoundation recorder and player
  DesignSystem/           Theme, cards and formatting
  Features/Journey/       Dashboard, sessions, history, roadmap, goal, onboarding
  Features/Vocabulary/    List, add/edit, word detail, pronunciation, recordings
MyRussianTests/           SwiftData integration tests
MyRussianUITests/         Critical journeys
scripts/                  TDD log runner, Xcode project generator
docs/                     Proposal and TDD evidence
```

The Xcode project uses synchronised folders, so new files are picked up automatically. Regenerate it with `python3 scripts/generate_xcodeproj.py` only when targets or build settings change.

## Design decisions

- **App icon: «От А до Я».** The idiom means "from A to Z". Я is both the last letter of the alphabet and the Russian word for "I/me". The gold ring echoes the Journey effort ring, with a "you are here" dot. It has light, dark and tinted variants, made by `scripts/generate_app_icon.js`.

- **Hours measure effort, not proficiency.** No proficiency percentage is shown. 110 h for A1 is your own planning estimate, and no hour estimates are invented for other levels.
- **Milestones are labelled app‑authored.** Each competency shows the TORFL subtest it prepares for (vocabulary & grammar, reading, listening, writing, speaking). The ~780‑item A1 lexical minimum appears only as a reference.
- **Pronunciation notes are stored exactly as typed.** Autocorrect is off and the text is never trimmed or normalised.
- **Audio lives on disk** in `Application Support/Recordings`. SwiftData stores only relative paths. Deleting a recording or word deletes its files, and a missing file shows "File missing" instead of crashing. Each recording is tagged `personal`, so future native‑speaker `reference` audio can sit alongside it.
- **The timer is timestamp-based** and persisted, so it survives backgrounding and app termination without double-counting.

## Later

- **iCloud sync:** the schema already follows CloudKit's rules. Add the iCloud (CloudKit) capability and change `cloudKitDatabase: .none` to `.automatic` in `AppModelContainer`. This needs a paid Apple Developer account.
- **Swift 6 language mode** for the app target (the core package already uses it).

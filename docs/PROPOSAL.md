# My Russian — V1 proposal

A personal Russian learning companion: **effort** (study hours), **competence** (milestones), **vocabulary** (what I actually know and can use).

Native SwiftUI, iOS 26 only (Liquid Glass), SwiftData, Swift Charts, AVFoundation. No backend, no accounts, no third‑party dependencies.

## 1. Navigation and screens

Two tabs only (`TabView` with `Tab`, system Liquid Glass tab bar):

**Journey**
- Dashboard (scroll view of cards)
  - Goal header: target level (e.g. *A1 · Elementary*), exam month/date, countdown.
  - Effort ring: cumulative hours vs. estimated hours (labelled *indicative estimate*).
  - This week: hours vs. weekly target, small 8‑week bar chart with target rule.
  - Pace: hours/week needed to reach the estimate by the exam vs. recent 4‑week average.
  - Live session card (when a timer is running) with pause/resume/stop.
  - Roadmap summary: per‑competency progress bars, next milestones.
  - Recent sessions.
- Pushed screens: **Study history & insights** (weekly/monthly charts, category breakdown, goal attainment, full session list with edit/delete), **Roadmap** (milestones by competency with 4‑state status), **Goal settings**.
- Sheets: **Start session** (category, timer), **Log session** (manual entry / edit), **Goal editor**, first‑launch **onboarding**.
- Toolbar: `+` menu (Start timer / Log past session), gear → goal settings.

**Vocabulary**
- Header stats: total, Learning / Recognise / Comfortable / Confident (mutually exclusive), active vocabulary (Comfortable + Confident), growth chart, A1 lexical minimum reference (~780, indicative, not coverage).
- Searchable list (Russian, meaning, my pronunciation notes), filter by confidence, sort (recent, updated, А–Я, confidence). Swipe to delete, context menu to change confidence.
- **Add word** sheet: Russian, meaning, confidence, and an inline quick pronunciation note (flag picker + spelling) so a mnemonic can be captured in the same breath.
- **Word detail** (notebook page): large Cyrillic word → meaning → confidence segmented control → *My pronunciation* (flag + exact spelling) → *My recordings* (record/stop, play, rename, delete, import) → example sentence & notes.

## 2. Data model (SwiftData, CloudKit‑ready but sync off)

All attributes have defaults, relationships are optional with explicit inverses, no `.unique` constraints — so CloudKit sync can be switched on later with no migration.

| Model | Key fields |
|---|---|
| `LearningGoal` | level, examYear/examMonth/examDay?, weeklyTargetHours, estimatedHours, createdAt |
| `StudySession` | id, start, duration (s), category, notes |
| `MilestoneRecord` | milestoneID (stable string from catalogue), status |
| `VocabularyWord` | id, russian, meaning, confidence, example, notes, dateAdded, dateUpdated, → notes[], → recordings[] |
| `PronunciationNote` | id, text (stored verbatim), referenceLanguage, explanation, createdAt, → word |
| `AudioRecording` | id, title, annotation, relativePath, duration, createdAt, kind (`personal` / future `reference`), source (`recorded` / `imported`), → word |

Milestone *definitions* live in code (`MilestoneCatalog`); only the user's status is persisted. Running‑timer state is persisted as small Codable JSON so it survives termination.

## 3. Testing architecture

- **`MyRussianCore` Swift package** — Foundation‑only domain logic. Test‑driven with Swift Testing via `swift test`. This runs on Linux, so every RED/GREEN step in this repo is real tool output (`docs/TDD-LOG.md`).
  - Goal/pace maths, study timer state machine (injected timestamps), study statistics incl. week‑boundary splitting, session validation & duplicate detection, milestone catalogue/progress, vocabulary duplicate detection/search/filter/sort/stats, pronunciation note rules, audio file store (temp directories), recording flow (mock recorder + permission).
- **App unit/integration tests (`MyRussianTests`)** — SwiftData with in‑memory `ModelContainer`: persistence, relationships, cascade deletes, recording files removed on delete.
- **UI tests (`MyRussianUITests`)** — XCUITest, launched with `-ui-testing` (isolated on‑disk store, reset on demand, fake recorder) for the critical journeys.
- App/UI tests need Xcode 26 on a Mac; they are written test‑first but **unverified** in this Linux environment.

## 4. Audio approach

- `AudioRecorder` protocol (permission, start(to:), stop → duration, cancel, interruption callback). `AVAudioRecorderService` implements it; tests use a fake.
- `RecordingFlow` (core) drives idle → recording → saved/failed, handles denial, cancellation (temp file deleted) and interruption (take kept if ≥ 0.5 s, otherwise discarded).
- Files: `Application Support/Recordings/<uuid>.m4a` (AAC, mono, 44.1 kHz), excluded from nothing (backed up with the device, never uploaded by the app). SwiftData stores only the **relative path**.
- Import via `.fileImporter` (audio UTTypes): security‑scoped access, size limit, copied into app storage.
- Deleting a recording/word removes the file; missing files show a “File missing” state instead of crashing.
- Audio session: `.playAndRecord` with `.defaultToSpeaker` while recording, `.playback` for listening.

## 5. Vertical slices

1. Harness + **goals** (levels, exam month/date, progress & pace).
2. **Study timer** (start/pause/resume/stop/discard, backgrounding).
3. **Study statistics & validation** (totals, week splitting, breakdown, attainment, duplicates).
4. **Milestones** (catalogue, status, competency progress).
5. **Vocabulary** (duplicate rules, search/filter/sort, stats).
6. **Pronunciation notes** (verbatim text, languages, flags).
7. **Audio** (file store, recording flow).
8. App: SwiftData models + integration tests, Journey UI, Vocabulary UI, audio services, onboarding, UI tests, Xcode project.

## TORFL sources

- Exam structure (five subtests: vocabulary & grammar, reading, listening, writing, speaking): [SPbU Testing Centre](https://testingcenter.spbu.ru/en/exams/russian/torfl.html), [HSE](https://preparatory.hse.ru/en/torfl).
- The ~780‑item A1 lexical minimum is widely cited for the published *Elementary level lexical minimum*; shown in‑app as an indicative reference only.
- Individual milestones are **app‑authored** and labelled as such; competencies are mapped to the TORFL subtest they prepare for.
- 110 h for A1 is the user's own estimate; no hour estimates are invented for other levels (user enters them).

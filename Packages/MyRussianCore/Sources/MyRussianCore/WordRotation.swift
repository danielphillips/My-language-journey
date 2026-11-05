import Foundation

/// The lock-screen widget's random word changes twice a day, at 05:00 and 17:00 local time.
public enum WordRotation {
    public static let morningHour = 5
    public static let eveningHour = 17

    /// The most recent 05:00 or 17:00. Times before 05:00 belong to the previous evening's slot.
    public static func slotStart(containing date: Date, calendar: Calendar) -> Date {
        let morning = at(morningHour, on: date, calendar)
        let evening = at(eveningHour, on: date, calendar)
        if date >= evening { return evening }
        if date >= morning { return morning }
        return at(eveningHour, on: calendar.date(byAdding: .day, value: -1, to: date)!, calendar)
    }

    public static func nextSlotStart(after date: Date, calendar: Calendar) -> Date {
        let start = slotStart(containing: date, calendar: calendar)
        if calendar.component(.hour, from: start) == morningHour {
            return at(eveningHour, on: start, calendar)
        }
        return at(morningHour, on: calendar.date(byAdding: .day, value: 1, to: start)!, calendar)
    }

    /// Consecutive integers for consecutive slots, counted from 1 January 2026.
    public static func slotIndex(for date: Date, calendar: Calendar) -> Int {
        let start = slotStart(containing: date, calendar: calendar)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference),
                                           to: calendar.startOfDay(for: start)).day ?? 0
        return days * 2 + (calendar.component(.hour, from: start) == eveningHour ? 1 : 0)
    }

    private static func at(_ hour: Int, on day: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }
}

/// What the widget shows: a random word that rotates, or one word you picked.
public enum WidgetWordChoice: Equatable, Sendable {
    case random
    case word(id: String)
}

extension WidgetWord {
    /// Learning and Recognise words come up three times as often as Comfortable and Confident ones.
    var rotationWeight: Int {
        switch confidence {
        case ConfidenceLevel.learning.rawValue, ConfidenceLevel.recognise.rawValue: 3
        default: 1
        }
    }
}

extension WidgetSnapshot {
    /// The chosen word if it still exists; otherwise the random word for the slot containing `date`.
    public func word(for choice: WidgetWordChoice, at date: Date, calendar: Calendar) -> WidgetWord? {
        if case let .word(id) = choice, let chosen = words.first(where: { $0.id == id }) {
            return chosen
        }
        return randomWord(forSlot: WordRotation.slotIndex(for: date, calendar: calendar))
    }

    /// Deterministic for a given vocabulary and slot. Words are dealt from a seeded, weighted
    /// "deck" per cycle, so every word appears each cycle and consecutive slots differ when possible.
    public func randomWord(forSlot slot: Int) -> WidgetWord? {
        let ordered = words.sorted { $0.id < $1.id }
        guard !ordered.isEmpty else { return nil }
        if ordered.count == 1 { return ordered[0] }
        if ordered.count == 2 {
            return ordered[((slot % 2) + 2) % 2]
        }

        // A word may not outnumber all the others together, or it could never be spread out.
        let weights = ordered.map(\.rotationWeight)
        let total = weights.reduce(0, +)
        let capped = weights.map { max(1, min($0, total - $0)) }
        let template = ordered.indices.flatMap { Array(repeating: $0, count: capped[$0]) }
        let size = template.count
        let cycle = Int((Double(slot) / Double(size)).rounded(.down))
        let position = slot - cycle * size
        return ordered[Self.deck(template, cycle: cycle)[position]]
    }

    /// The cycle's deck: every card from `template` once, no two equal cards adjacent (when possible),
    /// starting differently from the previous cycle's last card.
    ///
    /// Each cycle's last card is chosen from its own seed, so a deck depends only on its cycle number,
    /// never on a chain of earlier decks.
    private static func deck(_ template: [Int], cycle: Int) -> [Int] {
        let previousLast = boundaryCard(template, cycle: cycle - 1)
        let last = boundaryCard(template, cycle: cycle)

        var remaining: [Int: Int] = [:]
        for card in template { remaining[card, default: 0] += 1 }
        remaining[last]! -= 1

        var random = SplitMix64(seed: seed(cycle, salt: 0xDEC0))
        var deck: [Int] = []
        var previous = previousLast
        let middle = template.count - 1
        for position in 0..<middle {
            let left = middle - position
            let isFinal = position == middle - 1
            var candidates = remaining.filter { $0.value > 0 && $0.key != previous && !(isFinal && $0.key == last) }
                .sorted { $0.key < $1.key }
            // If skipping a card now would leave it more copies than non-adjacent places, it must go now.
            // (Places left after this one: `left - 1`; a card equal to `last` can't take the final one.)
            if let forced = candidates.first(where: { candidate in
                let capacityIfSkipped = candidate.key == last ? (left - 1) / 2 : left / 2
                return candidate.value > capacityIfSkipped
            }) {
                candidates = [forced]
            }
            let card: Int
            if candidates.isEmpty {
                // Nothing avoids a repeat (one word dominates): take any card left.
                card = remaining.filter { $0.value > 0 }.keys.sorted()[0]
            } else {
                let total = candidates.reduce(0) { $0 + $1.value }
                var roll = Int(random.next() % UInt64(total))
                card = candidates.first { roll -= $0.value; return roll < 0 }!.key
            }
            remaining[card]! -= 1
            deck.append(card)
            previous = card
        }
        deck.append(last)
        return deck
    }

    /// The last card of a cycle, from that cycle's seed alone. It's always one of the most frequent
    /// cards: when one word fills half the deck it must sit at the ends, so this keeps every deck dealable.
    private static func boundaryCard(_ template: [Int], cycle: Int) -> Int {
        var counts: [Int: Int] = [:]
        for card in template { counts[card, default: 0] += 1 }
        let highest = counts.values.max()!
        let candidates = counts.filter { $0.value == highest }.keys.sorted()
        var random = SplitMix64(seed: seed(cycle, salt: 0xB0B0))
        return candidates[Int(random.next() % UInt64(candidates.count))]
    }

    private static func seed(_ cycle: Int, salt: UInt64) -> UInt64 {
        UInt64(bitPattern: Int64(cycle)) &* 0x9E37_79B9 &+ salt
    }
}

/// Small, fast, platform-independent seeded generator (Swift's `Hasher` is randomised per launch).
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

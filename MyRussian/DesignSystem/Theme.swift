import SwiftUI
import MyRussianCore

/// Small, deliberate design vocabulary. Content sits on quiet grouped cards;
/// Liquid Glass is reserved for floating controls, as Apple's guidelines intend.
enum Theme {
    static let cardRadius: CGFloat = 26
    static let spacing: CGFloat = 16

    /// Cyrillic is part of the identity: set Russian text in the system serif (New York).
    static func russian(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}

extension ConfidenceLevel {
    var color: Color {
        switch self {
        case .learning: .orange
        case .recognise: .blue
        case .comfortable: .teal
        case .confident: .green
        }
    }
}

extension MilestoneStatus {
    var color: Color {
        switch self {
        case .notStarted: .secondary
        case .learning: .orange
        case .comfortable: .teal
        case .demonstrated: .green
        }
    }
}

extension PaceStatus {
    var title: String {
        switch self {
        case .onTrack: "On track"
        case .behind: "Behind pace"
        case .estimateReached: "Estimate reached"
        case .examDatePassed: "Exam date reached"
        case .noEstimate: "No estimate set"
        }
    }

    var systemImage: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .behind: "arrow.down.right.circle.fill"
        case .estimateReached: "flag.checkered"
        case .examDatePassed: "calendar.badge.checkmark"
        case .noEstimate: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .onTrack, .estimateReached: .green
        case .behind: .orange
        case .examDatePassed, .noEstimate: .secondary
        }
    }
}

/// A quiet content card.
struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.cardRadius))
    }
}

struct CardHeader: View {
    let title: String
    var systemImage: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
            Spacer()
            if let trailing {
                Text(trailing).foregroundStyle(.secondary)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Four-dot confidence indicator.
struct ConfidenceDots: View {
    let level: ConfidenceLevel

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...4, id: \.self) { index in
                Circle()
                    .fill(index <= level.dots ? level.color : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Confidence: \(level.title)")
    }
}

/// Segmented horizontal bar showing proportions, e.g. milestone statuses.
struct SegmentedBar: View {
    struct Segment: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    let segments: [Segment]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let total = max(segments.reduce(0) { $0 + $1.value }, 1)
            HStack(spacing: 2) {
                ForEach(segments.filter { $0.value > 0 }) { segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: max(proxy.size.width * segment.value / total - 2, 2))
                }
            }
        }
        .frame(height: height)
        .background(Color.secondary.opacity(0.15), in: .capsule)
        .clipShape(.capsule)
        .accessibilityHidden(true)
    }
}

/// Russian eyebrow above a title: a small piece of the app's Cyrillic identity.
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.russian(.footnote, weight: .medium))
            .foregroundStyle(.tint)
            .textCase(.lowercase)
    }
}

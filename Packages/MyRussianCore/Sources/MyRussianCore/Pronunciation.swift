import Foundation

/// The sound system borrowed to remember a Russian pronunciation.
/// It never changes the language of the Russian word itself.
public enum ReferenceLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case french = "fr"
    case brazilianPortuguese = "pt-BR"
    case english = "en"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .french: "French"
        case .brazilianPortuguese: "Brazilian Portuguese"
        case .english: "English"
        }
    }

    public var shortName: String {
        switch self {
        case .french: "French"
        case .brazilianPortuguese: "Portuguese"
        case .english: "English"
        }
    }

    public var flag: String {
        switch self {
        case .french: "🇫🇷"
        case .brazilianPortuguese: "🇧🇷"
        case .english: "🇬🇧"
        }
    }

    /// Most recently used first; defaults to French.
    public static func suggested(recentlyUsed: [ReferenceLanguage]) -> ReferenceLanguage {
        recentlyUsed.first ?? .french
    }
}

public enum PronunciationNoteError: Error, Equatable, Sendable {
    case emptyText
}

/// A personal phonetic mnemonic. The spelling is stored exactly as typed:
/// no trimming, case changes or Unicode normalisation, ever.
public struct PronunciationNoteDraft: Equatable, Sendable {
    public let text: String
    public var language: ReferenceLanguage
    public var explanation: String?

    public init(text: String, language: ReferenceLanguage, explanation: String? = nil) throws {
        guard !text.allSatisfy(\.isWhitespace) else { throw PronunciationNoteError.emptyText }
        self.text = text
        self.language = language
        let hasExplanation = explanation.map { !$0.allSatisfy(\.isWhitespace) } ?? false
        self.explanation = hasExplanation ? explanation : nil
    }

    public var flag: String { language.flag }
}

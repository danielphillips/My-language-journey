import Foundation

public struct RussianLetter: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case vowel, consonant, sign

        public var title: String {
            switch self {
            case .vowel: "Vowel"
            case .consonant: "Consonant"
            case .sign: "Sign"
            }
        }
    }

    public let uppercase: String
    public let lowercase: String
    /// The letter's traditional name, as spoken by a Russian voice (e.g. "бэ", "эль").
    public let spokenName: String
    /// Approximate sound for an English speaker. A guide, not phonetics.
    public let soundHint: String
    public let kind: Kind
    public let exampleWord: String
    public let exampleMeaning: String

    public var id: String { lowercase }
}

public enum RussianAlphabet {
    private static func letter(_ upper: String, _ name: String, _ hint: String, _ kind: RussianLetter.Kind,
                               _ word: String, _ meaning: String) -> RussianLetter {
        RussianLetter(uppercase: upper, lowercase: upper.lowercased(), spokenName: name, soundHint: hint,
                      kind: kind, exampleWord: word, exampleMeaning: meaning)
    }

    public static let letters: [RussianLetter] = [
        letter("А", "а", "a as in father", .vowel, "арбуз", "watermelon"),
        letter("Б", "бэ", "b as in bed", .consonant, "брат", "brother"),
        letter("В", "вэ", "v as in van", .consonant, "вода", "water"),
        letter("Г", "гэ", "g as in go", .consonant, "город", "city"),
        letter("Д", "дэ", "d as in dog", .consonant, "дом", "house"),
        letter("Е", "е", "ye as in yes", .vowel, "еда", "food"),
        letter("Ё", "ё", "yo as in yonder", .vowel, "ёж", "hedgehog"),
        letter("Ж", "жэ", "zh as in measure", .consonant, "жук", "beetle"),
        letter("З", "зэ", "z as in zoo", .consonant, "зима", "winter"),
        letter("И", "и", "ee as in meet", .vowel, "игра", "game"),
        letter("Й", "и краткое", "y as in boy", .consonant, "йогурт", "yoghurt"),
        letter("К", "ка", "k as in kite", .consonant, "кот", "cat"),
        letter("Л", "эль", "l as in lamp", .consonant, "луна", "moon"),
        letter("М", "эм", "m as in map", .consonant, "мама", "mum"),
        letter("Н", "эн", "n as in net", .consonant, "нос", "nose"),
        letter("О", "о", "o as in more", .vowel, "окно", "window"),
        letter("П", "пэ", "p as in pen", .consonant, "папа", "dad"),
        letter("Р", "эр", "rolled r", .consonant, "рыба", "fish"),
        letter("С", "эс", "s as in sun", .consonant, "сок", "juice"),
        letter("Т", "тэ", "t as in top", .consonant, "торт", "cake"),
        letter("У", "у", "oo as in boot", .vowel, "утро", "morning"),
        letter("Ф", "эф", "f as in fun", .consonant, "фото", "photo"),
        letter("Х", "ха", "kh as in Scottish loch", .consonant, "хлеб", "bread"),
        letter("Ц", "цэ", "ts as in cats", .consonant, "цирк", "circus"),
        letter("Ч", "че", "ch as in chair", .consonant, "чай", "tea"),
        letter("Ш", "ша", "sh as in shop, but harder", .consonant, "шапка", "hat"),
        letter("Щ", "ща", "a long, soft shsh", .consonant, "щука", "pike"),
        letter("Ъ", "твёрдый знак", "no sound: keeps the sounds apart", .sign, "подъезд", "entrance"),
        letter("Ы", "ы", "like i in ill, said further back", .vowel, "сыр", "cheese"),
        letter("Ь", "мягкий знак", "no sound: softens the letter before", .sign, "соль", "salt"),
        letter("Э", "э", "e as in pet", .vowel, "это", "this"),
        letter("Ю", "ю", "yu as in you", .vowel, "юбка", "skirt"),
        letter("Я", "я", "ya as in yard", .vowel, "яблоко", "apple"),
    ]
}

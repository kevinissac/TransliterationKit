import Foundation

/// The data behind one script: ordered tables (order matters, rules are applied in sequence).
struct SchemeSpec {
    let code: String
    let virama: String
    let inherentVowel: String
    let wordFinalViramaVowel: String
    let vowels: [(String, String)]
    let compounds: [(String, String)]
    let consonants: [(String, String)]
    let modifiers: [(String, String)]
    let finals: [(String, String)]
    let nasal: [(String, String)]
}

public struct TransliterationOptions {
    /// Uppercase each letter that follows whitespace or a digit (the first character of the input is unchanged). Off by default.
    public var capitalize: Bool
    /// Treat the input as HTML: with `capitalize`, only text outside tags is changed, and the first letter of a text node that follows a tag counts too.
    public var html: Bool

    public init(capitalize: Bool = false, html: Bool = false) {
        self.capitalize = capitalize
        self.html = html
    }
}

/// Phonetic transliteration of Brahmic scripts into Latin letters. The same engine and the same
/// scheme data run in the Android and JavaScript packages, and all three pass `data/tests/cases.tsv`.
///
/// A language is identified by its code, e.g. `"ml"`. Keep your own enum or mapping if you want names.
///
/// Character classes are spelled out (`[A-Za-z0-9_]`, ASCII whitespace) because ICU's `\w`/`\s`
/// are Unicode-aware, while the JavaScript engine's regexes are not.
public enum Transliterator {

    /// Codes of the languages that can be transliterated, e.g. `["ml", "ta"]`.
    public static var supportedCodes: [String] { schemes.map(\.code) }

    public static func supports(code: String) -> Bool {
        schemes.contains { $0.code == code }
    }

    /// Returns `text` unchanged if the language isn't supported.
    public static func transliterate(_ text: String, code: String, options: TransliterationOptions = .init()) -> String {
        schemes.first { $0.code == code }?.transliterate(text, options: options) ?? text
    }

    private static let schemes = SchemeData.all.map(Scheme.init)

    fileprivate final class Scheme {
        let code: String
        private let inherentVowel: String
        private let wordFinalViramaVowel: String

        private let vowelMap: [String: String]
        private let compoundMap: [String: String]
        private let consonantMap: [String: String]
        private let modifierMap: [String: String]

        private struct CompoundRule { let followedByLetter, trailingVirama, plain: NSRegularExpression; let value: String }
        private struct ConsonantRule {
            let notFollowedByVirama, viramaNotAtEnd, trailingVirama, plain: NSRegularExpression
            let value: String
        }

        private let modifiedCompounds: NSRegularExpression
        private let modifiedVowels: NSRegularExpression
        private let modifiedConsonants: NSRegularExpression
        private let compoundRules: [CompoundRule]
        private let consonantRules: [ConsonantRule]
        private let vowelRules: [(NSRegularExpression, String)]
        private let finalRules: [(NSRegularExpression, String)]
        private let nasalRules: [(NSRegularExpression, String)]
        private let modifierRules: [(NSRegularExpression, String)]

        private static let zeroWidth = regex("[\u{200B}-\u{200D}\u{FEFF}]")
        private static let spaceChars = " \\t\\n\\x{0B}\\f\\r"
        private static let capitalizePlain = regex("[0-9]+([\(spaceChars)]+)?(.)|[\(spaceChars)]+(.)")
        private static let htmlSegment = regex("(<[^>]*>)|([^<]+)")
        private static let boundaryClass = " ).;,\"'/%!"
        private static let wordChar = "[A-Za-z0-9_]"

        init(_ spec: SchemeSpec) {
            let vowels = spec.vowels, compounds = spec.compounds, consonants = spec.consonants
            let modifiers = spec.modifiers, finals = spec.finals, nasal = spec.nasal
            let virama = spec.virama
            self.code = spec.code
            self.inherentVowel = spec.inherentVowel
            self.wordFinalViramaVowel = spec.wordFinalViramaVowel

            vowelMap = Dictionary(vowels, uniquingKeysWith: { _, last in last })
            compoundMap = Dictionary(compounds, uniquingKeysWith: { _, last in last })
            consonantMap = Dictionary(consonants, uniquingKeysWith: { _, last in last })
            modifierMap = Dictionary(modifiers, uniquingKeysWith: { _, last in last })

            func alt(_ pairs: [(String, String)]) -> String { pairs.map { $0.0 }.joined(separator: "|") }
            func glyphRegex(_ glyphs: [(String, String)]) -> NSRegularExpression {
                Scheme.regex("(\(alt(glyphs)))(\(alt(modifiers)))")
            }

            modifiedCompounds = glyphRegex(compounds)
            modifiedVowels = glyphRegex(vowels)
            modifiedConsonants = glyphRegex(consonants)

            let boundary = NSRegularExpression.escapedPattern(for: Scheme.boundaryClass)
            compoundRules = compounds.map { k, v in
                CompoundRule(
                    followedByLetter: Scheme.regex("\(k)\(virama)(\(Scheme.wordChar))"),
                    trailingVirama: Scheme.regex("\(k)\(virama)"),
                    plain: Scheme.regex(k),
                    value: v)
            }
            consonantRules = consonants.map { k, v in
                ConsonantRule(
                    notFollowedByVirama: Scheme.regex("\(k)(?!\(virama))"),
                    viramaNotAtEnd: Scheme.regex("\(k)\(virama)(?![\(Scheme.spaceChars)\(boundary)])"),
                    trailingVirama: Scheme.regex("\(k)\(virama)"),
                    plain: Scheme.regex(k),
                    value: v)
            }
            vowelRules = vowels.map { (Scheme.regex($0.0), $0.1) }
            finalRules = finals.map { (Scheme.regex($0.0), $0.1) }
            nasalRules = nasal.map { (Scheme.regex($0.0), $0.1) }
            modifierRules = modifiers.map { (Scheme.regex($0.0), $0.1) }
        }

        func transliterate(_ text: String, options: TransliterationOptions) -> String {
            var input = Scheme.replace(Scheme.zeroWidth, in: text) { _, _ in "" }

            input = Scheme.replace(modifiedCompounds, in: input) { m, s in self.compoundMap[m.group(1, s)]! + self.modifierMap[m.group(2, s)]! }
            input = Scheme.replace(modifiedVowels, in: input) { m, s in self.vowelMap[m.group(1, s)]! + self.modifierMap[m.group(2, s)]! }
            input = Scheme.replace(modifiedConsonants, in: input) { m, s in self.consonantMap[m.group(1, s)]! + self.modifierMap[m.group(2, s)]! }

            for rule in compoundRules {
                input = Scheme.replace(rule.followedByLetter, in: input) { m, s in rule.value + m.group(1, s) }
                input = Scheme.replace(rule.trailingVirama, in: input) { _, _ in rule.value + self.wordFinalViramaVowel }
                input = Scheme.replace(rule.plain, in: input) { _, _ in rule.value + self.inherentVowel }
            }
            for rule in consonantRules {
                input = Scheme.replace(rule.notFollowedByVirama, in: input) { _, _ in rule.value + self.inherentVowel }
            }
            for rule in consonantRules {
                input = Scheme.replace(rule.viramaNotAtEnd, in: input) { _, _ in rule.value }
            }
            for rule in consonantRules {
                input = Scheme.replace(rule.trailingVirama, in: input) { _, _ in rule.value + self.wordFinalViramaVowel }
            }
            for rule in consonantRules {
                input = Scheme.replace(rule.plain, in: input) { _, _ in rule.value }
            }
            for (re, v) in vowelRules { input = Scheme.replace(re, in: input) { _, _ in v } }
            for (re, v) in finalRules { input = Scheme.replace(re, in: input) { _, _ in v } }
            for (re, v) in nasalRules { input = Scheme.replace(re, in: input) { _, _ in v } }
            for (re, v) in modifierRules { input = Scheme.replace(re, in: input) { _, _ in v } }

            guard options.capitalize else { return input }
            return options.html ? Scheme.capitalizeHTML(input) : Scheme.capitalizePlainText(input)
        }

        private static func capitalizePlainText(_ text: String) -> String {
            replace(capitalizePlain, in: text) { m, s in m.group(0, s).uppercased() }
        }

        /// Only text outside tags is capitalized; the first letter of a text node that directly
        /// follows a tag counts too.
        private static func capitalizeHTML(_ html: String) -> String {
            replace(htmlSegment, in: html) { m, s in
                if m.range(at: 1).location != NSNotFound { return m.group(1, s) }
                let capitalized = capitalizePlainText(m.group(2, s))
                let follows = m.range.location > 0 && s.character(at: m.range.location - 1) == 0x3E // ">"
                guard follows, let first = capitalized.first else { return capitalized }
                return String(first).uppercased() + capitalized.dropFirst()
            }
        }

        private static func regex(_ pattern: String) -> NSRegularExpression {
            // Patterns are built from fixed scheme tables, so a failure here is a programming error.
            try! NSRegularExpression(pattern: pattern)
        }

        /// Replacement is done by hand rather than with a template string so `$` or `\` in
        /// scheme values can never be interpreted as regex syntax.
        private static func replace(
            _ regex: NSRegularExpression,
            in text: String,
            with transform: (NSTextCheckingResult, NSString) -> String
        ) -> String {
            let ns = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { return text }
            var result = ""
            var last = 0
            for m in matches {
                result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                result += transform(m, ns)
                last = m.range.location + m.range.length
            }
            result += ns.substring(from: last)
            return result
        }
    }
}

private extension NSTextCheckingResult {
    func group(_ index: Int, _ string: NSString) -> String {
        let r = range(at: index)
        return r.location == NSNotFound ? "" : string.substring(with: r)
    }
}

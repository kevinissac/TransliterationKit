import XCTest

import TransliterationKit

// Cases live in data/tests and are shared with the Kotlin and JavaScript packages. Expected
// output was produced by the JavaScript engine, which is the reference implementation.
final class TransliteratorTests: XCTestCase {

    private func cases() throws -> [(code: String, options: TransliterationOptions, input: String, expected: String)] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data/tests/cases.tsv")
        return try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                let parts = line.components(separatedBy: "\t")
                let flags = parts[1].components(separatedBy: ",")
                let options = TransliterationOptions(capitalize: flags.contains("capitalize"), html: flags.contains("html"))
                return (parts[0], options, parts[2], parts[3])
            }
    }

    func testMatchesSharedCases() throws {
        let all = try cases()
        XCTAssertFalse(all.isEmpty)
        for c in all {
            XCTAssertEqual(Transliterator.transliterate(c.input, code: c.code, options: c.options), c.expected, c.input)
        }
    }

    func testSupportedCodes() {
        XCTAssertEqual(Set(Transliterator.supportedCodes), ["ml", "ta"])
        XCTAssertTrue(Transliterator.supports(code: "ml"))
        XCTAssertFalse(Transliterator.supports(code: "en"))
    }

    func testUnsupportedLanguageIsUnchanged() {
        XCTAssertEqual(Transliterator.transliterate("In the beginning", code: "xx"), "In the beginning")
    }
}

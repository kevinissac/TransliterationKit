package com.kevinissac.transliterationkit

internal class SchemeSpec(
    val code: String,
    val virama: String,
    val inherentVowel: String,
    val wordFinalViramaVowel: String,
    val vowels: List<Pair<String, String>>,
    val compounds: List<Pair<String, String>>,
    val consonants: List<Pair<String, String>>,
    val modifiers: List<Pair<String, String>>,
    val finals: List<Pair<String, String>>,
    val nasal: List<Pair<String, String>>
)

private class Scheme(spec: SchemeSpec) {
    val code = spec.code
    private val vowels = spec.vowels
    private val compounds = spec.compounds
    private val consonants = spec.consonants
    private val modifiers = spec.modifiers
    private val finals = spec.finals
    private val nasal = spec.nasal
    private val virama = spec.virama
    private val inherentVowel = spec.inherentVowel
    private val wordFinalViramaVowel = spec.wordFinalViramaVowel

    private val vowelMap = vowels.toMap()
    private val compoundMap = compounds.toMap()
    private val consonantMap = consonants.toMap()
    private val modifierMap = modifiers.toMap()

    private fun alt(pairs: List<Pair<String, String>>) = pairs.joinToString("|") { it.first }
    private fun glyphRegex(glyphs: List<Pair<String, String>>) =
        Regex("(${alt(glyphs)})(${alt(modifiers)})")

    private val boundaryClass = " ).;,\"'/%!"

    private class CompoundRule(val followedByLetter: Regex, val trailingVirama: Regex, val plain: Regex, val value: String)
    private class ConsonantRule(
        val notFollowedByVirama: Regex,
        val viramaNotAtEnd: Regex,
        val trailingVirama: Regex,
        val plain: Regex,
        val value: String
    )

    private val modifiedCompounds = glyphRegex(compounds)
    private val modifiedVowels = glyphRegex(vowels)
    private val modifiedConsonants = glyphRegex(consonants)

    private val compoundRules = compounds.map { (k, v) ->
        CompoundRule(Regex("$k$virama(\\w)"), Regex("$k$virama"), Regex(k), v)
    }
    private val consonantRules = consonants.map { (k, v) ->
        ConsonantRule(
            Regex("$k(?!$virama)"),
            Regex("$k$virama(?![\\s$boundaryClass])"),
            Regex("$k$virama"),
            Regex(k),
            v
        )
    }
    private val vowelRules = vowels.map { (k, v) -> Regex(k) to v }
    private val finalRules = finals.map { (k, v) -> Regex(k) to v }
    private val nasalRules = nasal.map { (k, v) -> Regex(k) to v }
    private val modifierRules = modifiers.map { (k, v) -> Regex(k) to v }

    fun transliterate(text: String, options: TransliterationOptions): String {
        var input = text.replace(ZERO_WIDTH, "")

        input = input.replace(modifiedCompounds) { compoundMap.getValue(it.groupValues[1]) + modifierMap.getValue(it.groupValues[2]) }
        input = input.replace(modifiedVowels) { vowelMap.getValue(it.groupValues[1]) + modifierMap.getValue(it.groupValues[2]) }
        input = input.replace(modifiedConsonants) { consonantMap.getValue(it.groupValues[1]) + modifierMap.getValue(it.groupValues[2]) }

        compoundRules.forEach { rule ->
            input = input.replace(rule.followedByLetter) { rule.value + it.groupValues[1] }
            input = input.replace(rule.trailingVirama) { rule.value + wordFinalViramaVowel }
            input = input.replace(rule.plain) { rule.value + inherentVowel }
        }
        consonantRules.forEach { rule -> input = input.replace(rule.notFollowedByVirama) { rule.value + inherentVowel } }
        consonantRules.forEach { rule -> input = input.replace(rule.viramaNotAtEnd) { rule.value } }
        consonantRules.forEach { rule -> input = input.replace(rule.trailingVirama) { rule.value + wordFinalViramaVowel } }
        consonantRules.forEach { rule -> input = input.replace(rule.plain) { rule.value } }
        vowelRules.forEach { (re, v) -> input = input.replace(re) { v } }
        finalRules.forEach { (re, v) -> input = input.replace(re) { v } }
        nasalRules.forEach { (re, v) -> input = input.replace(re) { v } }
        modifierRules.forEach { (re, v) -> input = input.replace(re) { v } }

        if (!options.capitalize) return input
        return if (options.html) capitalizeHtml(input) else capitalizePlain(input)
    }

    private fun capitalizePlain(text: String) = text.replace(CAPITALIZE_PLAIN) { it.value.uppercase() }

    /**
     * Only text outside tags is capitalized; the first letter of a text node that directly follows
     * a tag counts too.
     */
    private fun capitalizeHtml(html: String): String = html.replace(HTML_SEGMENT) { match ->
        if (match.groups[1] != null) return@replace match.value
        val capitalized = capitalizePlain(match.value)
        val start = match.range.first
        if (start > 0 && html[start - 1] == '>' && capitalized.isNotEmpty()) {
            capitalized.substring(0, 1).uppercase() + capitalized.substring(1)
        } else {
            capitalized
        }
    }

    private companion object {
        val ZERO_WIDTH = Regex("[\u200B-\u200D\uFEFF]")
        val CAPITALIZE_PLAIN = Regex("\\d+(\\s+)?(.)|\\s+(.)", RegexOption.MULTILINE)
        val HTML_SEGMENT = Regex("(<[^>]*>)|([^<]+)")
    }
}

/**
 * @property capitalize uppercase each letter that follows whitespace or a digit (the first character of the input is unchanged). Off by default.
 * @property html treat the input as HTML: with [capitalize], only text outside tags is changed, and the first letter of a text node that follows a tag counts too.
 */
data class TransliterationOptions(val capitalize: Boolean = false, val html: Boolean = false)

/**
 * Phonetic transliteration of Brahmic scripts into Latin letters. The same engine and scheme data
 * run in the Swift and JavaScript packages, and all three pass `data/tests/cases.tsv`.
 *
 * A language is identified by its code, e.g. `"ml"`. Keep your own enum or mapping if you want names.
 */
object Transliterator {

    private val schemes = SchemeData.all.map(::Scheme)

    /** Codes of the languages that can be transliterated, e.g. `["ml", "ta"]`. */
    val supportedCodes: List<String> get() = schemes.map { it.code }

    fun supports(code: String): Boolean = schemes.any { it.code == code }

    /** Returns [text] unchanged if the language isn't supported. */
    fun transliterate(text: String, code: String, options: TransliterationOptions = TransliterationOptions()): String =
        schemes.firstOrNull { it.code == code }?.transliterate(text, options) ?: text

}

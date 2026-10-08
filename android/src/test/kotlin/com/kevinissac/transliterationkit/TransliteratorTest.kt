package com.kevinissac.transliterationkit

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Cases live in data/tests and are shared with the Swift and JavaScript packages. Expected output
// was produced by the JavaScript engine, which is the reference implementation.
class TransliteratorTest {

    private class Case(val code: String, val options: TransliterationOptions, val input: String, val expected: String)

    private val cases: List<Case> =
        File("../data/tests/cases.tsv").readLines()
            .filter { it.isNotEmpty() }
            .map { line ->
                val parts = line.split("\t")
                val flags = parts[1].split(",")
                Case(parts[0], TransliterationOptions("capitalize" in flags, "html" in flags), parts[2], parts[3])
            }

    @Test
    fun matchesSharedCases() {
        assertTrue(cases.isNotEmpty())
        for (c in cases) {
            assertEquals(c.input, c.expected, Transliterator.transliterate(c.input, c.code, c.options))
        }
    }

    @Test
    fun supportedCodes() {
        assertEquals(setOf("ml", "ta"), Transliterator.supportedCodes.toSet())
        assertTrue(Transliterator.supports("ml"))
        assertFalse(Transliterator.supports("en"))
    }

    @Test
    fun unsupportedLanguageIsUnchanged() {
        assertEquals("In the beginning", Transliterator.transliterate("In the beginning", "xx"))
    }
}

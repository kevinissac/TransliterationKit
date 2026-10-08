//
//  engine.js
//
//  Generic phonetic transliteration engine for Brahmic abugida scripts
//  (Malayalam, Tamil, Devanagari, Telugu, Kannada, ...). These scripts all
//  share the same shape: independent vowel letters, consonants that carry
//  an implicit vowel, dependent vowel signs that override it, and a
//  virama/halant mark that suppresses it to build conjuncts.
//
//  This file has no language-specific data at all — adding a language means
//  adding a scheme under ./schemes, never touching this file. See
//  ./schemes/malayalam.js for the shape a scheme object is expected to have.
//

function getKeys(o) {
	return Object.keys(o);
}

function toStringSafe(input) {
	if (typeof input === "string") return input;
	if (input === undefined || input === null) return "";
	return String(input);
}

// ______ escape characters for safe use inside a regex [...] character class
function escapeForCharClass(chars) {
	return chars.replace(/[\\\]^-]/g, "\\$&");
}

const zeroWidthCharsRegex = /[​-‍﻿]/g;
// Capitalizing uppercases the letter after whitespace or a digit; the first character of the input
// is left as is. In HTML mode only text outside tags is touched, and the first letter of a text
// node that directly follows a tag counts too.
const plainCapitalizeRegex = /\d+(\s+)?(.)|\s+(.)/gm;
const htmlSegmentRegex = /(<[^>]*>)|([^<]+)/g;

function capitalizePlain(text) {
	return text.replace(plainCapitalizeRegex, (c) => c.toUpperCase());
}

function capitalizeHtml(html) {
	return html.replace(htmlSegmentRegex, (match, tag, text, offset) => {
		if (tag) return tag;
		const capitalized = capitalizePlain(text);
		return offset > 0 && html[offset - 1] === ">" ? capitalized.charAt(0).toUpperCase() + capitalized.slice(1) : capitalized;
	});
}
const defaultWordBoundaryChars = " ).;,\"'/%!";

// everything below is precompiled once per scheme (cached on the scheme
// object) and reused on every call instead of being rebuilt per call

function compile(scheme) {
	if (scheme._compiled) return scheme._compiled;

	const compounds = scheme.compounds || {};
	const finals = scheme.finals || {};
	const nasal = scheme.nasal || {};
	const { vowels, consonants, modifiers, virama } = scheme;
	const boundaryClass = escapeForCharClass(scheme.wordBoundaryChars || defaultWordBoundaryChars);

	const modifiedGlyphRegex = {
		compounds: new RegExp("(" + getKeys(compounds).join("|") + ")(" + getKeys(modifiers).join("|") + ")", "g"),
		vowels: new RegExp("(" + getKeys(vowels).join("|") + ")(" + getKeys(modifiers).join("|") + ")", "g"),
		consonants: new RegExp("(" + getKeys(consonants).join("|") + ")(" + getKeys(modifiers).join("|") + ")", "g"),
	};

	const compoundRules = getKeys(compounds).map(function (k) {
		return {
			followedByLetter: new RegExp(k + virama + "([\\w])", "g"), // compound ending in virama but not at the end of the word
			trailingVirama: new RegExp(k + virama, "g"), // compound ending in virama has the word-final vowel
			plain: new RegExp(k, "g"), // compound not ending in virama has the inherent vowel
			value: compounds[k],
		};
	});

	const consonantRules = getKeys(consonants).map(function (k) {
		return {
			notFollowedByVirama: new RegExp(k + "(?!" + virama + ")", "g"),
			viramaNotAtEnd: new RegExp(k + virama + "(?![\\s" + boundaryClass + "])", "g"),
			trailingVirama: new RegExp(k + virama, "g"),
			plain: new RegExp(k, "g"),
			value: consonants[k],
		};
	});

	const vowelRules = getKeys(vowels).map(function (k) {
		return { regex: new RegExp(k, "g"), value: vowels[k] };
	});

	const finalRules = getKeys(finals).map(function (k) {
		return { regex: new RegExp(k, "g"), value: finals[k] };
	});

	const nasalRules = getKeys(nasal).map(function (k) {
		return { regex: new RegExp(k, "g"), value: nasal[k] };
	});

	const modifierRules = getKeys(modifiers).map(function (k) {
		return { regex: new RegExp(k, "g"), value: modifiers[k] };
	});

	scheme._compiled = { modifiedGlyphRegex, compoundRules, consonantRules, vowelRules, finalRules, nasalRules, modifierRules };
	return scheme._compiled;
}

// ______ replace a glyph immediately followed by a vowel modifier, e.g. "ക" + "ി" -> "ki"
function replaceModifiedGlyphs(re, glyphs, modifiers, input) {
	return input.replace(re, function (_full, glyph, modifier) {
		return glyphs[glyph] + modifiers[modifier];
	});
}

// ______ transliterate a string phonetically using the given scheme
// options: { capitalize: false, html: false } — see README
export function transliterate(scheme, input, options = {}) {
	const { capitalize = false, html = false } = options;
	input = toStringSafe(input);
	const inherentVowel = scheme.inherentVowel === undefined ? "a" : scheme.inherentVowel;
	const wordFinalViramaVowel = scheme.wordFinalViramaVowel === undefined ? "" : scheme.wordFinalViramaVowel;
	const compounds = scheme.compounds || {};
	const { modifiedGlyphRegex, compoundRules, consonantRules, vowelRules, finalRules, nasalRules, modifierRules } = compile(scheme);

	// replace zero width non joiners
	input = input.replace(zeroWidthCharsRegex, "");

	// replace modified compounds first
	input = replaceModifiedGlyphs(modifiedGlyphRegex.compounds, compounds, scheme.modifiers, input);

	// replace modified non-compounds
	input = replaceModifiedGlyphs(modifiedGlyphRegex.vowels, scheme.vowels, scheme.modifiers, input);
	input = replaceModifiedGlyphs(modifiedGlyphRegex.consonants, scheme.consonants, scheme.modifiers, input);

	// replace unmodified compounds
	compoundRules.forEach(function (rule) {
		input = input.replace(rule.followedByLetter, rule.value + "$1");
		input = input.replace(rule.trailingVirama, rule.value + wordFinalViramaVowel);
		input = input.replace(rule.plain, rule.value + inherentVowel);
	});

	// glyphs not ending in virama have the inherent-vowel pronunciation
	consonantRules.forEach(function (rule) {
		input = input.replace(rule.notFollowedByVirama, rule.value + inherentVowel);
	});

	// glyphs ending in virama not at the end of a word
	consonantRules.forEach(function (rule) {
		input = input.replace(rule.viramaNotAtEnd, rule.value);
	});

	// remaining glyphs ending in virama will be at the end of words
	consonantRules.forEach(function (rule) {
		input = input.replace(rule.trailingVirama, rule.value + wordFinalViramaVowel);
	});

	// remaining consonants
	consonantRules.forEach(function (rule) {
		input = input.replace(rule.plain, rule.value);
	});

	// vowels
	vowelRules.forEach(function (rule) {
		input = input.replace(rule.regex, rule.value);
	});

	// standalone final-consonant glyphs (e.g. Malayalam chillu letters)
	finalRules.forEach(function (rule) {
		input = input.replace(rule.regex, rule.value);
	});

	// nasalization marks (e.g. anusvara)
	nasalRules.forEach(function (rule) {
		input = input.replace(rule.regex, rule.value);
	});

	// replace any stray modifiers that may have been left out
	modifierRules.forEach(function (rule) {
		input = input.replace(rule.regex, rule.value);
	});

	if (capitalize) {
		input = html ? capitalizeHtml(input) : capitalizePlain(input);
	}

	return input;
}

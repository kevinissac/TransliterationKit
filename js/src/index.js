//
//  index.js
//
//  Registry of per-language transliteration schemes. Scheme data is generated from
//  ../data/schemes by tools/generate.py — add a language there, never in this file.
//

import { transliterate as run } from "./engine.js";
import schemes from "./schemes.js";

// ______ codes of the supported languages, e.g. ["ml", "ta"]
export const supportedCodes = Object.keys(schemes);

export function supports(code) {
	return Object.prototype.hasOwnProperty.call(schemes, code);
}

// ______ transliterate `text` using the scheme for `code` (e.g. "ml"); returns it unchanged if
// that language isn't supported. options: { capitalize: false, html: false }
export function transliterate(text, code, options) {
	return supports(code) ? run(schemes[code], text, options) : text;
}

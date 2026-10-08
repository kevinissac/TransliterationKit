import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { transliterate, supports, supportedCodes } from "../src/index.js";

// Cases live in data/tests and are shared with the Swift and Kotlin packages.
const file = fileURLToPath(new URL("../../data/tests/cases.tsv", import.meta.url));
const cases = readFileSync(file, "utf8").split("\n").filter(Boolean).map((line) => line.split("\t"));

function parseFlags(flags) {
	return Object.fromEntries(flags.split(",").filter(Boolean).map((f) => [f, true]));
}

test("matches the shared cases", () => {
	assert.ok(cases.length > 0);
	for (const [code, flags, input, expected] of cases) {
		assert.equal(transliterate(input, code, parseFlags(flags)), expected, input);
	}
});

test("lists supported codes", () => {
	assert.deepEqual([...supportedCodes].sort(), ["ml", "ta"]);
	assert.ok(supports("ml"));
	assert.ok(!supports("en"));
});

test("unsupported language is unchanged", () => {
	assert.equal(transliterate("In the beginning", "xx"), "In the beginning");
});

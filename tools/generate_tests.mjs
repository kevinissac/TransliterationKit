// Runs the reference (JavaScript) engine over data/tests/inputs.tsv and writes the expected output
// to data/tests/cases.tsv (code, flags, input, expected), which every platform's tests check against.
// Usage: node tools/generate_tests.mjs [path to another engine's index.js to compare against]
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const { transliterate } = await import(pathToFileURL(process.argv[2] ? resolve(process.argv[2], "index.js") : resolve(here, "../js/src/index.js")));
const lines = readFileSync(resolve(here, "../data/tests/inputs.tsv"), "utf8").split("\n").filter(Boolean);
// Every input runs under each option set; the flags column is a comma list ("" = defaults).
const optionSets = [
	["", {}],
	["capitalize", { capitalize: true }],
	["capitalize,html", { capitalize: true, html: true }],
];
const out = lines.flatMap((line) => {
	const [code, input] = line.split("\t");
	return optionSets.map(([flags, options]) => `${code}\t${flags}\t${input}\t${transliterate(input, code, options)}\n`);
});
writeFileSync(resolve(here, "../data/tests/cases.tsv"), out.join(""));
console.log(`${out.length} cases`);

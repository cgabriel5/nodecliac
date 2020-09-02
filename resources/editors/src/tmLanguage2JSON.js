#!/usr/bin/env node

// @purpose: Converts 'acmap.tmLanguage' to JSON for use with Atom/VSCode.
// @resource: tmLanguage Scheme Guide:
// [https://raw.githubusercontent.com/martinring/tmlanguage/master/tmlanguage.json]
// @usage: To generate grammars simply run the file from the CLI.

"use strict";

const path = require("path");
const fe = require("file-exists");

const { read, write } = require("../../../src/utils/toolbox.js");

(async () => {
	// eslint-disable-next-line no-unused-vars
	let err, res; // Declare empty vars to reuse for all await operations.

	// Get editors resource path.
	let parts = __dirname.replace(/\/src$/, "").split(path.sep);
	let sourcedir = parts.join(path.sep);

	// tmLanguage file names.
	let filename = "acmap.tmLanguage";
	let outputfilename = "acmap.tmLanguage.json";

	// Source paths.
	let st_spath = path.join(sourcedir, "sublime-text-3", "acmap", "grammars");
	let atom_spath = path.join(sourcedir, "atom", "language-acmap", "grammars");
	let vscode_spath = path.join(
		sourcedir,
		"vscode",
		"cgabriel5-acmap-grammar",
		"grammars"
	);
	let acmaptmpath = path.join(st_spath, filename);

	// Output paths.
	let st_opath = path.join(st_spath, outputfilename);
	let atom_opath = path.join(atom_spath, outputfilename);
	let vscode_opath = path.join(vscode_spath, outputfilename);

	// tmLanguage file must exist to proceed.
	if (await fe(acmaptmpath)) {
		let contents = await read(acmaptmpath);
		const entities = { "&quot;": '"', "&apos;": "'", "&lt;": "<" };

		contents = contents.match(/<plist .*?>([\s\S]*?)<\/plist>/)[1];
		contents = contents
			.replace(/<!--[\s\S]*?-->/g, "")
			.replace(/[ \t]*$/gm, "");
		contents = contents
			.replace(/<\/?(dict|array)>/g, (match) => {
				let res = "";
				if (!match.includes("/")) {
					res = match.includes("dict") ? "{" : "[";
				} else {
					res = match.includes("dict") ? "}" : "]";
				}
				return res;
			})
			.replace(/<key>(.*?)<\/key>/g, '"$1":')
			.replace(/<string>/g, '"')
			.replace(/<\/string>/g, '"')
			.replace(/":\n\s*"/g, '": "')
			.replace(/"\n(\s*)"/g, '",\n$1"')
			.replace(/^\s*\n+/gm, "")
			.replace(/^\t/gm, "")
			.replace(/":\s*\{/g, '": {')
			.replace(/":\s*\[/g, '": [')
			.replace(/^(\s+)}(\s*)"/gm, '$1},$2"')
			.replace(/^(\s+)](\s*)"/gm, '$1],$2"')
			.replace(/^(\s*)}(\s*){/gm, "$1},$2{");

		let r = /"(match|begin|end)": "(.*?)"(,?\s*$)/;
		contents = contents.replace(new RegExp(r, "gm"), (match) => {
			let [, key, value, remainder] = match.match(r);
			// Convert any HTML entities to their proper character(s).
			value = value
				.replace(/&(.*?);/g, (match) => {
					return entities[match];
				})
				.replace(/\\/g, "\\\\")
				.replace(/"/g, '\\"');

			return `"${key}": "${value}"${remainder}`;
		});

		// Save acmap.tmLanguage.json to needed locations.
		await write(st_opath, contents);
		await write(atom_opath, contents);
		await write(vscode_opath, contents);
	}
})();

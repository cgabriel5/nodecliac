#!/usr/bin/env node

"use strict";

// [https://csvjson.com/csv2json]

const path = require("path");
const chalk = require("chalk");
const stripansi = require("strip-ansi");
const { hasProp, write } = require("../utils/toolbox.js");
const CSV_DELIMITER = ";";
const TB_LABELS = ["tid", "kind", "line", "column", "start", "end", "lines", "$", "list", "value"];

let collens = (tokens, tbdb_lens, LINESTARTS) => {
	// Loop over each token and check each property length. Update the table
	// with the largest string property length.
	for (let i = 0, l = tokens.length; i < l; i++) {
		let token = tokens[i];
		let { tid, kind, line, start, end, lines = [], "$": str, list} = token;
		// [TODO]: When the token is a string it can span multiple lines
		// so get the start line instead of the token:line entry. However,
		// look into the ending string line is the value in the token object.
		if (lines.length) line = lines[0];

		let tid_len = (tid + "").length;
		let kind_len = kind.length;
		let line_len = (line + "").length;
		let start_len = (start + "").length;
		let end_len = (end + "").length;
		let lines_len = (lines + "").length;
		let str_len = (str || "").length;
		let list_len = ((list || "") + "").length;

		let line_col = ((start - LINESTARTS[line]) + "").length;

		if (tid_len > tbdb_lens["tid"]) tbdb_lens["tid"] = tid_len;
		if (kind_len > tbdb_lens["kind"]) tbdb_lens["kind"] = kind_len;
		if (line_len > tbdb_lens["line"]) tbdb_lens["line"] = line_len;
		if (start_len > tbdb_lens["start"]) tbdb_lens["start"] = start_len;
		if (end_len > tbdb_lens["end"]) tbdb_lens["end"] = end_len;
		if (lines_len > tbdb_lens["lines"]) tbdb_lens["lines"] = lines_len;
		if (str_len > tbdb_lens["$"]) tbdb_lens["$"] = str_len;
		if (list_len > tbdb_lens["list"]) tbdb_lens["list"] = list_len;
		if ((end - start + 1) > tbdb_lens["value"]) tbdb_lens["value"] = (end - start + 1);

		if (line_col > tbdb_lens["column"]) tbdb_lens["column"] = line_col;
	}
};

// module.exports = async (branches, cchains, flags, settings, S, cmdname) => {
// module.exports = async (S, branches) => {
// module.exports = async (tokens, text) => {
let tables = async (tokens, text, tbdb_lens, type_, LINESTARTS, bid = 0) => {
	// let tokens = S.lexerdata.tokens;

	const TB_TOP_LEFT_CORNER = "┌";
	const TB_TOP_RIGHT_CORNER = "┐";
	const TB_BOTTOM_LEFT_CORNER = "└";
	const TB_BOTTOM_RIGHT_CORNER = "┘";
	const TB_MIDDLE_T_TOP = "┬";
	const TB_MIDDLE_T_BOTTOM = "┴";
	const TB_MIDDLE_PIPE = "│";
	const TB_MIDDLE_STRAIGHT = "─";
	const TB_MIDDLE_CROSS = "┼";
	const TB_MIDDLE_T_LEFT = "├";
	const TB_MIDDLE_T_RIGHT = "┤";

	let rows = [];
	let output = [];

	// // Populate table with label keys with labels and their respective lengths.
	// for (let i = 0, l = TB_LABELS.length; i < l; i++) {
	// 	let label = TB_LABELS[i];
	// 	tbdb_lens[label] = label.length;
	// }

	// Loop over each token and check each property length. Update the table
	// with the largest string property length.
	for (let i = 0, l = tokens.length; i < l; i++) {
		let token = tokens[i];
		let { tid, kind, line, start, end, lines = [], "$": str, list} = token;
		// [TODO]: When the token is a string it can span multiple lines
		// so get the start line instead of the token:line entry. However,
		// look into the ending string line is the value in the token object.
		if (lines.length) line = lines[0];

		let tid_len = (tid + "").length;
		let kind_len = kind.length;
		let line_len = (line + "").length;
		let start_len = (start + "").length;
		let end_len = (end + "").length;
		let lines_len = (lines + "").length;
		let str_len = (str || "").length;
		let list_len = ((list || "") + "").length;

		let line_col = ((start - LINESTARTS[line]) + "").length;

		if (tid_len > tbdb_lens["tid"]) tbdb_lens["tid"] = tid_len;
		if (kind_len > tbdb_lens["kind"]) tbdb_lens["kind"] = kind_len;
		if (line_len > tbdb_lens["line"]) tbdb_lens["line"] = line_len;
		if (start_len > tbdb_lens["start"]) tbdb_lens["start"] = start_len;
		if (end_len > tbdb_lens["end"]) tbdb_lens["end"] = end_len;
		if (lines_len > tbdb_lens["lines"]) tbdb_lens["lines"] = lines_len;
		if (str_len > tbdb_lens["$"]) tbdb_lens["$"] = str_len;
		if (list_len > tbdb_lens["list"]) tbdb_lens["list"] = list_len;
		if ((end - start + 1) > tbdb_lens["value"]) tbdb_lens["value"] = (end - start + 1);

		if (line_col > tbdb_lens["column"]) tbdb_lens["column"] = line_col;
	}

	var rowcap = [];
	var rowlabels = [];
	var rowtail = [];

	var header_ = (type_ === "branches") ? "Branch" : "Tokens";
	if (type_ === "branches") bid++;
	else if (type_ === "tokens") bid = tokens.length;
	rowcap.push(` ${TB_TOP_LEFT_CORNER}${TB_MIDDLE_STRAIGHT} ${chalk.bold(header_)} ${TB_MIDDLE_STRAIGHT} ${chalk.bold.magenta(bid)} ${TB_MIDDLE_STRAIGHT}${TB_TOP_RIGHT_CORNER}\n`);

	// Generate the top row/layer of the table.
	for (let i = 0, l = TB_LABELS.length; i < l; i++) {
		let label = TB_LABELS[i];
		if (i === 0) { // first label
			rowcap.push(TB_TOP_LEFT_CORNER);
			rowcap.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
		} else if (l - 1 === i) { // last label
			rowcap.push(TB_MIDDLE_T_TOP);
			rowcap.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
			rowcap.push(TB_TOP_RIGHT_CORNER);
		} else {
			rowcap.push(TB_MIDDLE_T_TOP);
			rowcap.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
		}

		//////////

		// Generate the labels row of the table.
		var nlabel = " " + chalk.bold(label) + " ".repeat(Math.abs(tbdb_lens[label] - label.length) + 1);
		if (i === 0) { // first label
			rowlabels.push(TB_MIDDLE_PIPE, nlabel);
		} else if (l - 1 === i) { // last label
			rowlabels.push(TB_MIDDLE_PIPE, nlabel, TB_MIDDLE_PIPE);
		} else {
			rowlabels.push(TB_MIDDLE_PIPE, nlabel);
		}

		//////////

		// Generate tail end of the table.
		if (tokens.length === 1) {
			if (i === 0) { // first label
				rowtail.push(TB_BOTTOM_LEFT_CORNER);
				rowtail.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
			} else if (l - 1 === i) { // last label
				rowtail.push(TB_MIDDLE_T_BOTTOM);
				rowtail.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
				rowtail.push(TB_BOTTOM_RIGHT_CORNER);
			} else {
				rowtail.push(TB_MIDDLE_T_BOTTOM);
				rowtail.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
			}
		} else { // Empty file (no tokens).
			if (i === 0) { // first label
				rowtail.push(TB_MIDDLE_T_LEFT);
				rowtail.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
			} else if (l - 1 === i) { // last label
				rowtail.push(TB_MIDDLE_CROSS);
				rowtail.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
				rowtail.push(TB_MIDDLE_T_RIGHT);
			} else {
				rowtail.push(TB_MIDDLE_CROSS);
				rowtail.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
			}
		}
	}

	// var header = [...rowcap, "\n", ...rowlabels, "\n", ...rowtail].join("");
	var header = [...rowcap, "\n", ...rowlabels].join("");

	// Generate table separator.
	var separator_parts = [];
	for (let i = 0, l = TB_LABELS.length; i < l; i++) {
		let label = TB_LABELS[i];
		if (i === 0) { // first label
			separator_parts.push(TB_MIDDLE_T_LEFT);
			separator_parts.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
		} else if (l - 1 === i) { // last label
			separator_parts.push(TB_MIDDLE_CROSS);
			separator_parts.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
			separator_parts.push(TB_MIDDLE_T_RIGHT);
		} else {
			separator_parts.push(TB_MIDDLE_CROSS);
			separator_parts.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
		}
	}
	let separator = separator_parts.join("");

	// output.push("\n");
	for (let i = 0, l = tokens.length; i < l; i++) {
		let token = tokens[i];
		output.push("\n");

		let row = [];

		let { tid, kind, line, start, end, lines = [], "$": str, list} = token;
		// [TODO]: When the token is a string it can span multiple lines
		// so get the start line instead of the token:line entry. However,
		// look into the ending string line is the value in the token object.
		if (lines.length) line = lines[0];

		let tid_len = (tid + "").length;
		let kind_len = kind.length;
		let line_len = (line + "").length;
		let start_len = (start + "").length;
		let end_len = (end + "").length;
		let lines_len = (lines + "").length;
		let str_len = (str || "").length;
		let list_len = ((list || "") + "").length;

		let line_col = ((start - LINESTARTS[line]) + "").length;

		// if (i === 0) output.push(separator, "\n"); // After header only.
		output.push(separator, "\n"); // After every row.

		for (let i = 0, l = TB_LABELS.length; i < l; i++) {
			let label = TB_LABELS[i];
			var nstr = "";
			var nlen = 0;
			switch (i) {
				// TB_LABELS = "tid", "kind", "line", "column", "start", "end", "lines", "$", "list", "value"
				case 0:
					nstr = (tid + "")
					nlen = tid_len;
					break;
				case 1:
					nstr = (kind + "")
					nlen = kind_len;
					break;
				case 2:
					nstr = (line + "")
					nlen = line_len;
					break;
				case 3:
					nstr = ((start - LINESTARTS[line]) + "")
					nlen = line_col;
					break;
				case 4:
					nstr = (start + "")
					nlen = start_len;
					break;
				case 5:
					nstr = (end + "");
					nlen = end_len;
					break;
				case 6:
					nstr = (lines + "");
					nlen = lines_len;
					break;
				case 7: // Interpolated string value.
					nstr = ((str || "") + "");
					nlen = str_len;
					break;
				case 8:
					nstr = ((list || "") + "")
					nlen = list_len;
					break;
				case 9: // Original file substring value.
					nstr = text.substring(start, end + 1);
					nlen = nstr.length;
					break;
			}

			// When the kind is tkEOP clear the value to an empty string.
			if (i === 3 && kind === "tkEOP") {
				nstr = "";
				nlen = 0;
			}

			// Replace newline and tab characters with respective symbol.
			// No need to reset nlen as the replacing is only overwriting
			// a character for another.
			if (i === 7 || i === 9) {
				// [https://stackoverflow.com/a/34936253]
				nstr = nstr.replace(/[\r\n]|\t/g,
					(match) => (match === "\n") ? "⏎" : "⇥");
			}

// tid,kind,line,start,end,lines,$,list,value
// 0,tkCMT,1,0,8,,,,# comment
// 7,tkCMT,7,15,25,,,,# comment 2
// 9,tkCMT,8,27,37,,,,# comment 3
// 14,tkCMT,12,42,51,,,,#comment 4

			// Escape ';' characters when saving to CVS format.
			row.push(nstr.replace(CSV_DELIMITER, (match) => {
				if (i === 7 || i === 9) return `\\${CSV_DELIMITER}`;
			}));

			// // Replace newline characters with raw/escaped character.
			// if (nstr.length === 1 && nstr === "\n") {
			// 	nstr = "\\n";
			// 	nlen = 2;
			// }
			var nlabel = " " + nstr + " ".repeat(Math.abs(tbdb_lens[label] - nlen) + 1);
			if (i === 0) { // first label
				output.push(TB_MIDDLE_PIPE, nlabel);
			} else if (l - 1 === i) { // last label
				rows.push(row.join(CSV_DELIMITER));
				output.push(TB_MIDDLE_PIPE, nlabel, TB_MIDDLE_PIPE);
			} else {
				output.push(TB_MIDDLE_PIPE, nlabel);
			}
		}
	}
	output.push("\n");

	var tail = TB_BOTTOM_LEFT_CORNER + separator.slice(1, -1) + TB_BOTTOM_RIGHT_CORNER;
	output.push(tail.replaceAll(TB_MIDDLE_CROSS, TB_MIDDLE_T_BOTTOM));

	// for (let i = 0, l = TB_LABELS.length; i < l; i++) {
	// 	let label = TB_LABELS[i];
	// 	if (i === 0) { // first label
	// 		output.push(TB_BOTTOM_LEFT_CORNER);
	// 		output.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
	// 	} else if (l - 1 === i) { // last label
	// 		output.push(TB_MIDDLE_T_BOTTOM);
	// 		output.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
	// 		output.push(TB_BOTTOM_RIGHT_CORNER);
	// 	} else {
	// 		output.push(TB_MIDDLE_T_BOTTOM);
	// 		output.push(TB_MIDDLE_STRAIGHT.repeat(tbdb_lens[label] + 2))
	// 	}
	// }
	// console.table(tokens, ["kind", "line", "start", "end", "lines", "$", "list", "value"]);

	// return header+output.join("");
	return [
		header+output.join(""),
		rows.join("\n"),
		JSON.stringify(tokens, null, 4)
	]

	// console.log("---------- BREAKDOWN ----------");
	// console.log("token_count:", tokens.length);
	// console.log("branches_count:", branches.length);
	// console.log(branches);
	// console.log(tbdb_lens);
	// console.table(tokens, ["kind", "line", "start", "end", "lines", "$", "list", "value"]);
};

// module.exports = { tables, collens };


module.exports = async (tokens, BRANCHES, text, action, LINESTARTS, tks = false, brs = false) => {

	let tbdb_lens = {};
	// Populate table with label keys with labels and their respective lengths.
	for (let i = 0, l = TB_LABELS.length; i < l; i++) {
		let label = TB_LABELS[i];
		if (!hasProp(tbdb_lens, label)) {
			tbdb_lens[label] = label.length;
		}
	}

	if (tks) {
		collens(tokens, tbdb_lens, LINESTARTS);
		let [table, csv, json] = await tables(tokens, text, tbdb_lens, "tokens", LINESTARTS);
		console.log(table);
		console.log(` tokens_count: ${tokens.length}\n`);
		let csvheader = TB_LABELS.join(CSV_DELIMITER) + "\n";
		await write(path.join(process.cwd(), `${action}.debug-t.csv`), stripansi(csvheader + csv));
		// await write(path.join(process.cwd(), `${action}.debug-t.json`), json);
		await write(path.join(process.cwd(), `${action}.debug-t.json`), JSON.stringify(tokens, null, 4));
	}
	if (brs) {
		// Loop over every branch to get table length data.
		for (let i = 0, l = BRANCHES.length; i < l; i++) {
			let branch = BRANCHES[i];
			collens(branch, tbdb_lens, LINESTARTS);
		}

		// Loop over every branch to build table data output.
		var output = [];
		var csvout = [TB_LABELS.join(CSV_DELIMITER)];
		var jsonout = [];
		for (let i = 0, l = BRANCHES.length; i < l; i++) {
			let branch = BRANCHES[i];
			let [table, csv, json] = await tables(branch, text, tbdb_lens, "branches", LINESTARTS, i);
			output.push(table);
			csvout.push(`;Branch ─ ${i+1}`, csv);
			jsonout.push(json);
			if (l - 1 !== i) {
				jsonout.push(",");
			}
		}
		console.log(output.join("\n"));
		console.log(` branches_count: ${BRANCHES.length}`);
		await write(path.join(process.cwd(), `${action}.debug-b.csv`), stripansi(csvout.join("\n")));
		// // await write(path.join(process.cwd(), `${action}.debug-b.json`), "[\n" + jsonout.join("\n") + "\n]");
		await write(path.join(process.cwd(), `${action}.debug-b.json`), JSON.stringify(BRANCHES, null, 4));
	}

	process.exit();
	// return [];
};

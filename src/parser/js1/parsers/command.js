"use strict";

const copy = require("deepcopy");
const node = require("../helpers/nodes.js");
const p_flag = require("../parsers/flag.js");
const error = require("../helpers/error.js");
const add = require("../helpers/tree-add.js");
const tracer = require("../helpers/trace.js");
const { nk } = require("../helpers/enums.js");
const rollback = require("../helpers/rollback.js");
const bracechecks = require("../helpers/brace-checks.js");
const {
	cin,
	cnotin,
	C_NL,
	C_SPACES,
	C_CMD_IDENT_START,
	C_CMD_GRP_IDENT_START,
	C_CMD_IDENT,
	C_CMD_VALUE
} = require("../helpers/charsets.js");

/**
 * ----------------------------------------------------------- Parsing Breakdown
 * program.command
 * program.command ,
 * program.command =
 * program.command = [
 * program.command = [ ]?
 * program.command = --flag
 * program.command.{ command , command } = --flag
 *                | |
 *                ^-^-Whitespace-Boundary 1/2
 *                 ^-Group-Open
 *                  ^-Group-Whitespace-Boundary
 *                   ^Group-Command
 *                           ^Group-Delimiter
 *                                     ^-Group-Close
 * ^-Command-Chain
 *                 ^-Assignment
 *                   ^-Opening-Bracket
 *                    ^-Whitespace-Boundary 3
 *                     ^-Optional-Closing-Bracket?
 *                      ^-EOL-Whitespace-Boundary 4
 * -----------------------------------------------------------------------------
 *
 * @param  {object} S - State object.
 * @return {object} - Node object.
 */
module.exports = (S) => {
	let l = S.l;
	let state = "command";
	let N = node(nk.Command, S);
	const isformatting = S.args.action === "format";

	// Group state object.
	let G = {
		active: false,
		command: "",
		start: 0,
		commands: [],
		tokens: []
	};

	// Error if cc scope exists (brace not closed).
	bracechecks(S, null, "pre-existing-cs");

	/**
	 * Checks dot "."" delimiter escaping in command.
	 *
	 * @param  {string} char - The current loop iteration character.
	 * @param  {boolean} isgroup - Whether command is part of a group.
	 * @return {undefined} - Nothing is returned.
	 */
	let cescape = (c, isgroup) => {
		// Note: When escaping anything but a dot do not
		// include the '\' as it is not needed. For example,
		// if the command is 'com\mand\.name' we should return
		// 'command\.name' and not 'com\mand\.name'.
		if (c === "\\") {
			let n = S.text.charAt(S.i + 1);

			// nchar must exist else escaping nothing.
			if (!n) error(S, 10);

			// Only dots can be escaped.
			if (n !== ".") {
				error(S, 10);

				// Remove last escape char as it isn't needed.
				if (isgroup) G.command = G.command.slice(0, -1);
				else N.command.value = N.command.value.slice(0, -1);
			}
		}
	};

	let c,
		p = "";
	for (; S.i < l; S.i++, S.column++) {
		p = c;
		c = S.text.charAt(S.i);

		if (cin(C_NL, c)) {
			N.end = rollback(S) && S.i;
			break; // Stop at nl char.
		}

		if (c === "#" && p !== "\\") {
			rollback(S);
			N.end = S.i;
			break;
		}

		switch (state) {
			case "command":
				if (!N.command.value) {
					if (cnotin(C_CMD_IDENT_START, c)) error(S);

					N.command.start = N.command.end = S.i;
					N.command.value += c;

					// Once a wildcard (all) char is found change state.
					if (c === "*") state = "chain-wsb";
				} else {
					if (cin(C_CMD_IDENT, c)) {
						N.command.end = S.i;
						N.command.value += c;
						cescape(c, false);
					} else if (cin(C_SPACES, c)) {
						state = "chain-wsb";
						continue;
					} else if (c === "=") {
						state = "assignment";
						rollback(S);
					} else if (c === ",") {
						state = "delimiter";
						rollback(S);
					} else if (c === "{") {
						state = "group-open";
						rollback(S);
					} else error(S);
				}

				break;

			case "chain-wsb":
				if (cnotin(C_SPACES, c)) {
					if (c === "=") {
						state = "assignment";
						rollback(S);
					} else if (c === ",") {
						state = "delimiter";
						rollback(S);
					} else error(S);
				}

				break;

			case "assignment":
				N.assignment.start = N.assignment.end = S.i;
				N.assignment.value = c;
				state = "value-wsb";

				break;

			case "delimiter":
				N.delimiter.start = N.delimiter.end = S.i;
				N.delimiter.value = c;
				state = "eol-wsb";

				break;

			case "value-wsb":
				if (cnotin(C_SPACES, c)) {
					state = "value";
					rollback(S);
				}

				break;

			case "value":
				// Note: Intermediary step - remove it?
				if (cnotin(C_CMD_VALUE, c)) error(S);
				state = c === "[" ? "open-bracket" : "oneliner";
				rollback(S);

				break;

			case "open-bracket":
				// Note: Intermediary step - remove it?
				N.brackets.start = S.i;
				N.brackets.value = c;
				N.value.value = c;
				state = "open-bracket-wsb";

				break;

			case "open-bracket-wsb":
				if (cnotin(C_SPACES, c)) {
					state = "close-bracket";
					rollback(S);
				}

				break;

			case "close-bracket":
				if (c !== "]") error(S);
				N.brackets.end = S.i;
				N.value.value += c;
				state = "eol-wsb";

				break;

			case "oneliner":
				{
					tracer(S, "flag"); // Trace parser.

					let fN = p_flag(S, "oneliner");
					// Add alias node if it exists.
					if (fN.alias.value) {
						let cN = node(nk.Flag, S);
						cN.hyphens.value = "-";
						cN.delimiter.value = ",";
						cN.name.value = fN.alias.value;
						cN.singleton = true;
						cN.boolean.value = fN.boolean.value;
						cN.assignment.value = fN.assignment.value;
						cN.alias.value = cN.name.value;
						N.flags.push(cN);

						// Add context node for mutual exclusivity.
						let xN = node(nk.Flag, S);
						xN.value.value = `"{${fN.name.value}|${fN.alias.value}}"`;
						xN.keyword.value = "context";
						xN.singleton = false;
						xN.virtual = true;
						xN.args.push(xN.value.value);
						N.flags.push(xN);
					}
					N.flags.push(fN);
				}

				break;

			case "eol-wsb":
				if (cnotin(C_SPACES, c)) error(S);

				break;

			// Command group states

			case "group-open":
				N.command.end = S.i;
				N.command.value += !isformatting ? "?" : c;

				state = "group-wsb";

				G.start = S.column;
				G.commands.push([]);
				G.active = true;

				break;

			case "group-wsb": {
				let l = G.commands.length;
				if (G.command) G.commands[l - 1].push(G.command);
				G.command = "";

				if (cnotin(C_SPACES, c)) {
					if (cin(C_CMD_GRP_IDENT_START, c)) {
						state = "group-command";
						rollback(S);
					} else if (c === ",") {
						state = "group-delimiter";
						rollback(S);
					} else if (c === "}") {
						state = "group-close";
						rollback(S);
					} else error(S);
				}

				break;
			}

			case "group-command":
				if (!G.command) {
					if (cnotin(C_CMD_GRP_IDENT_START, c)) {
						error(S);
					}

					G.tokens.push(["command", S.column]);
					N.command.end = S.i;
					G.command += c;
					if (isformatting) N.command.value += c;
				} else {
					if (cin(C_CMD_IDENT, c)) {
						N.command.end = S.i;
						G.command += c;
						if (isformatting) N.command.value += c;
						cescape(c, true);
					} else if (cin(C_SPACES, c)) {
						state = "group-wsb";
						continue;
					} else if (c === ",") {
						state = "group-delimiter";
						rollback(S);
					} else if (c === "}") {
						state = "group-close";
						rollback(S);
					} else error(S);
				}

				break;

			case "group-delimiter": {
				N.command.end = S.i;
				if (isformatting) N.command.value += c;

				let l = G.tokens.length;
				if (!l || (l && G.tokens[l - 1][0] === "delimiter")) {
					error(S, 12);
				}

				l = G.commands.length;
				if (G.command) G.commands[l - 1].push(G.command);
				G.tokens.push(["delimiter", S.column]);
				G.command = "";
				state = "group-wsb";

				break;
			}

			case "group-close": {
				N.command.end = S.i;
				if (isformatting) N.command.value += c;

				let l = G.commands.length;
				if (G.command) G.commands[l - 1].push(G.command);
				if (!G.commands[l - 1].length) {
					S.column = G.start;
					error(S, 11); // Empty command group.
				}
				l = G.tokens.length;
				if (G.tokens[l - 1][0] === "delimiter") {
					S.column = G.tokens[l - 1][1];
					error(S, 12); // Trailing delimiter.
				}

				G.active = false;
				G.command = "";
				state = "command";

				break;
			}
		}
	}

	if (G.active) {
		S.column = G.start;
		error(S, 13); // Command group was left unclosed.
	}

	// Expand command groups.
	if (!isformatting && G.commands.length) {
		var commands = [];
		// Loop over each group command group and replace placeholder.
		for (let i = 0, l = G.commands.length; i < l; i++) {
			let group = G.commands[i];
			if (!commands.length) {
				for (let i = 0, l = group.length; i < l; i++) {
					commands.push(N.command.value.replace("?", group[i]));
				}
			} else {
				let tmp_commands = [];
				for (let i = 0, l = commands.length; i < l; i++) {
					for (let j = 0, ll = group.length; j < ll; j++) {
						tmp_commands.push(commands[i].replace("?", group[j]));
					}
				}
				commands = tmp_commands;
			}
		}

		// Create individual Node objects for each expanded command chain.
		for (let i = 0, l = commands.length; i < l; i++) {
			let cN = copy(N);
			cN.command.value = commands[i];
			cN.delimiter.value = cN.assignment.value = "";
			let aval = N.assignment.value;
			if (N.delimiter.value || aval) {
				if (aval && l - 1 === i) cN.assignment.value = "=";
				else cN.delimiter.value = ",";
			}

			add(S, cN); // Add flags below.
			let ll = cN.flags.length;
			for (let i = 0; i < ll; i++) add(S, cN.flags[i]);
		}
	} else {
		add(S, N); // Add flags below.
		for (let i = 0, l = N.flags.length; i < l; i++) add(S, N.flags[i]);
	}

	// If scope is created store ref to Node object.
	if (N.value.value === "[") S.scopes.command = N;
};

"use strict";

// Get needed modules.
const issuefunc = require("./p.error.js");
const pflagset = require("./p.flagset.js");
// Get RegExp patterns.
let { r_nl } = require("./h.patterns.js");

/**
 * Parses command chain line to extract command chain.
 *
 * ---------- Parsing States Breakdown -----------------------------------------
 * program.command = [ ]?
 *                | |
 *                ^-^-Whitespace-Boundary 1/2
 * ^-Command-Chain
 *                 ^-Assignment
 *                   ^-Opening-Bracket
 *                    ^-Whitespace-Boundary 3
 *                     ^-Optional-Closing-Bracket?
 *                      ^-EOL-Whitespace-Boundary 4
 * -----------------------------------------------------------------------------
 *
 * @param  {string} string - The line to parse.
 * @return {object} - Object containing parsed information.
 */
module.exports = () => {
	// Trace parser.
	require("./h.trace.js")(__filename);

	// Get globals.
	let string = global.$app.get("string");
	let i = global.$app.get("i");
	let l = global.$app.get("l");
	let line_num = global.$app.get("line_num");
	let line_fchar = global.$app.get("line_fchar");
	let h = global.$app.get("highlighter");
	let formatting = global.$app.get("formatting");
	let lookup = global.$app.get("lookup");
	let keywords = global.$app.get("keywords");
	let hkeywords = global.$app.get("hkeywords");

	// Parsing vars.
	let chain = "";
	let chains = []; // Delimited chains.
	let assignment = "";
	let value = "";
	let flagset = "";
	let hflagset = "";
	let flagsets = [];
	let hflagsets = [];
	let command = "";
	let commands = [];
	let has_shortcuts = false;
	let is_oneliner = false;
	let delimiter = false;
	let state = "command"; // Parsing state.
	let nl_index;
	// Collect all parsing warnings.
	let warnings = [];
	// Capture state's start/end indices.
	let indices = {
		chain: {
			start: i,
			end: null
		},
		assignment: {
			index: null
		},
		delimiter: {
			index: null
		},
		value: {
			start: null,
			end: null
		},
		braces: {
			open: null
		},
		shortcut: {
			open: null
		},
		oneliner: {
			start: null
		}
	};
	// Store brace state (open/closed).
	let brstate;

	// Wrap issue function to add fixed parameters.
	let issue = (type = "error", code, char = "") => {
		// Run and return issue.
		return issuefunc(i, __filename, warnings, state, type, code, {
			// Parser specific variables.
			char,
			name: chain
		});
	};

	/**
	 * Set chain as a global to access in other parsers.
	 *
	 * @param  {string} chain - The chain to store.
	 * @return {undefined} - Nothing is returned.
	 */
	let setchain = chain => {
		// Get global chain.
		let cchain = global.$app.vars.currentchain;

		// Only set if chain is different than current chain.
		if (chain !== cchain) {
			// Store as global to access in other parsers (for dupe checks).
			global.$app.vars.currentchain = chain;
		}

		// If a global chain does not exist, increment global size.
		if (!cchain) {
			global.$app.size(1); // Increment size by 1.
		}
	};

	/**
	 * Store fallback command string for provided command chain. Also store
	 *     possible delimited sibling command chains.
	 *
	 * @param  {string} keyword  - The un-highlighted keyword (default/always).
	 * @param  {string} hkeyword - The highlighted keyword.
	 * @param  {string} value    - The un-highlighted keyword value.
	 * @param  {string} hvalue   - The highlighted keyword value.
	 * @param  {string} chain    - The chain to attach fallback to.
	 * @return {undefined} - Nothing is returned.
	 */
	let store_fallback = function(keyword, hkeyword, value, hvalue, chain) {
		// Get global chain objects.
		let chains = global.$app.get("chains");

		// Add current chain to objects.
		chains.push({ chain });

		// Loop over chains to add keyword.
		for (let i = 0, l = chains.length; i < l; i++) {
			// Cache current loop item.
			let item = chains[i];
			let chain = item.chain;

			// Store setting/value pair.
			keywords[chain] = [keyword, value];
			hkeywords[chain] = [hkeyword, hvalue];
			// Increment keyword size/count.
			keywords.__count__++;
		}

		// Remove current chain from chains.
		chains.pop();
	};

	// Loop over string.
	for (; i < l; i++) {
		// Cache current loop item.
		let char = string.charAt(i);
		let pchar = string.charAt(i - 1);
		let nchar = string.charAt(i + 1);

		// End loop on a new line char.
		if (r_nl.test(char)) {
			// Store newline index.
			nl_index = i;
			break;
		}

		// Default parse state.
		if (state === "command") {
			// Check for special command characters.
			if (/[./{|} \t]/.test(char)) {
				// RegExp Switch case: [https://stackoverflow.com/a/2896642]
				switch (true) {
					case /[./]/.test(char) && pchar !== "\\":
						{
							// Character after dot must be a letter, ':', or '{'.
							if (!/[:{a-zA-Z]/.test(nchar)) {
								return issue("error", 8, char);
							}

							// Store command string and delimiter.
							commands.push(command, ".");
							// Reset command string.
							command = "";

							// Add char to string.
							chain += char;
						}

						break;
					case char === "{": // Opening shortcut brace.
						{
							// Check for shortcut opening brace '{'.
							// If an open brace already exists.
							if (indices.shortcut.open) {
								return issue("error", 4, char);
							}

							// Add opening shortcut brace.
							commands.push(char);

							// Store command string if populated.
							if (command) {
								commands.push(command);
							}
							// Reset command string.
							command = "";

							// Store index.
							indices.shortcut.open = i;
							// Add char to string.
							chain += char;
							// Set flag.
							has_shortcuts = true;
						}

						break;
					case /[}|]/.test(char): // Check for shortcut braces.
						{
							// Open brace must exist or char is used out of place.
							if (!indices.shortcut.open) {
								return issue("error", 4, char);
							}

							// Character after '|' must be a letter, ':', or '{'.
							if (char === "|" && !/[:{a-zA-Z]/.test(nchar)) {
								return issue("error", 9, char);
							}

							// Store command string if populated.
							if (command) {
								// Add syntax highlighting?
								// commands.push(h(command, "shortcut"));

								commands.push(command);
							}
							// Reset command string.
							command = "";

							// Add closing shortcut brace/pipe separator char.
							commands.push(char);
							// Add char to string.
							chain += char;

							// Closing brace '}'.
							if (char === "}") {
								// Clear opening shortcut index.
								indices.shortcut.open = null;
							}
						}

						break;
					// If we encounter a whitespace character, everything after
					// this point must be a space until we encounter an eq sign
					// or the end-of-line.
					case /[ \t]/.test(char): {
						// If brace index is set it was never closed.
						if (indices.shortcut.open) {
							// Reset index opened shortcut brace.
							i = indices.shortcut.open;
							return issue("error", 7, "{");
						}

						state = "chain-wsb";
					}
				}

				continue;
			}

			// If char is the first char...
			if (!command) {
				// First char of command must be a letter or semicolon.
				if (!/[:a-zA-Z]/.test(char)) {
					return issue("error", 1, char);
				}
				// Store index.
				indices.chain.start = i;
				// Add char to strings.
				command += char;
				chain += char;
			}
			// Keep building command string...
			else {
				// If char is allowed keep building string.
				if (/[-_.:+\\/a-zA-Z0-9]/.test(char)) {
					// Flag denotes whether to skip character escaping.
					let escapechar;

					// Check for escape char '\'. Next char must be a dot.
					// or not an allowed escape sequence.
					if (char === "\\") {
						// A next char must exist else '\' is escaping nothing.
						if (!nchar) {
							return issue("error", 4, char);
						}

						// Escaping anything but a dot give warning/error.
						if (nchar !== ".") {
							// Allowed command chars: give warning.
							if (/[-_a-zA-Z0-9]/.test(nchar)) {
								// If char is not a dot give warning.
								issue("warning", 2, nchar);
								escapechar = false;
							}
							// Invalid characters: give error.
							else {
								return issue("error", 3, nchar);
							}
						} else {
							escapechar = true;
						}
					}

					// Store index.
					indices.chain.end = i;
					if (escapechar) {
						// Increment index to start after escaped character.
						i++;
						// Store index.
						indices.chain.end = i;

						// Add char to strings.
						command += "\\.";
						chain += "\\.";
					}
					// If not a command delimiter store character.
					else {
						// When escaping anything but a dot do not include
						// the '\' as it is not needed. For example, if the
						// command is 'com\mand\.name' we should return
						// 'command\.name' and not 'com\mand\.name'.
						if (char === "\\") {
							continue;
						}

						// Add char to strings.
						command += char;
						chain += char;
					}
				}
				// If char is an eq sign change state/reset index.
				else if (char === "=") {
					// If brace index is set it was never closed.
					if (indices.shortcut.open) {
						// Reset index opened shortcut brace.
						i = indices.shortcut.open;
						return issue("error", 7, "{");
					}

					state = "assignment";
					i--;
				}
				// If char is a comma change state/reset index.
				else if (char === ",") {
					// If brace index is set it was never closed.
					if (indices.shortcut.open) {
						// Reset index opened shortcut brace.
						i = indices.shortcut.open;
						return issue("error", 7, "{");
					}

					state = "delimiter";
					i--;
				}
				// Anything else the character is not allowed.
				else {
					return issue("error", 4, char);
				}
			}
		} else if (state === "chain-wsb") {
			// If the character is not a space and the assignment has not
			// been set we are looking for an eq sign.
			if (!/[ \t]/.test(char) && assignment === "") {
				// Character at this point can only be an eq sign (=) or
				// a command (,). Return error for anything else.
				if (!/[=,]/.test(char)) {
					return issue("error", 4, char);
				} else {
					// Set state.
					state = char === "=" ? "assignment" : "delimiter";
					i--;
				}
			}
		} else if (state === "assignment") {
			// Store index.
			indices.assignment.index = i;

			assignment = "=";

			state = "open-bracket-wsb";
		} else if (state === "delimiter") {
			// Store index.
			indices.delimiter.index = i;

			// Set flag.
			delimiter = true;
			// Make command.
			command = commands.join("") + command;
			// Store chain in delimited chains array.
			chains.push(commands.join("") + command);
			// Clear commands array.
			commands.length = 0;

			state = "open-bracket-wsb";
		} else if (state === "open-bracket-wsb") {
			// If the delimiter flag is set...
			if (delimiter) {
				// All characters at this point must be spaces. Anything else
				// is invalid and should produce an error.
				if (!/[ \t]/.test(char)) {
					return issue("error", 4, char);
				}

				// Break from loop and set index to continue parsing.
				nl_index = i;
			}

			// Ignore all beginning consecutive spaces. Once a non-space
			// character is detected switch to value state.
			if (!/[ \t]/.test(char)) {
				state = "value";
				// Set index back 1 to start parsing at the character
				// (this character) that triggered the state switch.
				i--;
				continue;
			}
		} else if (state === "value") {
			// If this is the first char is must be '['.
			if (value === "") {
				if (char === "[") {
					// Store index.
					indices.braces.open = i;
				} else if (char === "-" || /[a-z]/.test(char)) {
					// Parsing a one-line flag.
					state = "flagset-oneline";

					// Set index.
					indices.oneliner.start = i;

					i--;
					continue;
				} else {
					return issue("error", 4, char);
				}

				// Store index.
				indices.value.start = i;
				value += char;
			} else {
				// After getting the first character '[' everything after
				// must be a space followed by ']', whitespace, or nothing.
				if (char === "]") {
					state = "eol-wsb";
				} else if (!/[ \t]/.test(char)) {
					return issue("error", 4, char);
				}

				// Store index.
				indices.value.end = i;
				// Don't add whitespace to value.
				if (!/[ \t]/.test(char)) {
					value += char;
				}
			}
		} else if (state === "eol-wsb") {
			// Allow trailing whitespace only.
			if (!/[ \t]/.test(char)) {
				return issue("error", 4, char);
			}
		} else if (state === "flagset-oneline") {
			// With RegExp to parse on unescaped '|' characters it would be
			// something like this: String.split(/(?<=[^\\]|^|$)\|/);
			// [https://stackoverflow.com/a/25895905]
			// [https://stackoverflow.com/a/12281034]

			// Set flag.
			is_oneliner = true;

			// Get individual flag sets. Use unescaped '|' as the delimiter.
			if (char === "|" && pchar !== "\\") {
				// Store chain as a global.
				setchain(chain);

				// Use as global to access in other parsers (for dupe checks).
				if (!global.$app.vars.oneliner) {
					global.$app.vars.oneliner = new Set();
					global.$app.size(1); // Increment size by 1.
				}

				// Run flag value parser from here...
				let pvalue = pflagset({
					str: [indices.oneliner.start], // Index to resume parsing at.
					usepipe: true // End parsing either on newlines or pipe chars.
				});

				// Join warnings.
				if (pvalue.warnings.length) {
					warnings = warnings.concat(pvalue.warnings);
				}
				// If error exists return error.
				if (pvalue.code) {
					return pvalue;
				}

				// Get result values.
				let keyword = pvalue.keyword;
				let symbol = pvalue.symbol;
				let name = pvalue.name;
				let hname = pvalue.h.name;
				let assignment = pvalue.assignment;
				let value = pvalue.args;
				let hvalue = pvalue.h.hargs;
				let nl_index = pvalue.nl_index;

				// For keyword declarations.
				if (keyword) {
					// Get highlighted/non-highlighted keywords.
					let [, hkeyword] = keyword;
					keyword = keyword[0];

					// Store the provided command string fallback (default/always).
					store_fallback(keyword, hkeyword, value, hvalue, chain);

					// Reset flag to newly parsed value.
					flagset = `${keyword} ${value}`;
					// Set highlighted version.
					hflagset = `${hkeyword} ${hvalue}`;
				} else {
					// If value is not a string (therefore an array) join values.
					if (typeof value !== "string" && value.length > 1) {
						value = `(${value.join(" ")})`;
						hvalue = `(${hvalue.join(" ")})`;
					}

					// Reset flag to newly parsed value.
					flagset = `${symbol}${name}${assignment}${value}`;
					// Set highlighted version.
					hflagset = `${symbol}${hname}${assignment}${hvalue}`;
				}

				// Reset oneliner start index.
				indices.oneliner.start = (nl_index || i) + 1;

				// Don't add fallback (default/always) to flagsets as they have
				// their own section (bottom of output).
				if (!keyword || formatting) {
					// Store current flag set.
					flagsets.push(flagset);
					// Set highlighted version.
					hflagsets.push(hflagset);
				}

				// Reset flag set string.
				flagset = "";
				hflagset = "";
			} else {
				// Build flag set string.
				flagset += char;
			}
		}
	}

	// If brace index is set it was never closed.
	if (indices.shortcut.open) {
		// Reset index opened shortcut brace.
		i = indices.shortcut.open;
		return issue("error", 7, "{");
	}

	// Add the last command.
	if (command) {
		commands.push(command);
	}

	// Join command parts and reset chain to normalized chain string.
	chain = commands.join("");

	// Store chain as a global.
	setchain(chain);

	// [TODO] Use a function to not repeat followed pflagset logic.

	// Add final flag set.
	if (flagset) {
		// Run flag value parser from here...
		let pvalue = pflagset({
			str: [indices.oneliner.start], // Index to resume parsing at.
			usepipe: true // End parsing either on newlines or pipe chars.
		});

		// Join warnings.
		if (pvalue.warnings.length) {
			warnings = warnings.concat(pvalue.warnings);
		}
		// If error exists return error.
		if (pvalue.code) {
			return pvalue;
		}

		// Get result values.
		let symbol = pvalue.symbol;
		let keyword = pvalue.keyword;
		let name = pvalue.name;
		let hname = pvalue.h.name;
		let assignment = pvalue.assignment;
		let value = pvalue.args;
		let hvalue = pvalue.h.hargs;
		let nl_index = pvalue.nl_index;

		// For keyword declarations.
		if (keyword) {
			// Get highlighted/non-highlighted keywords.
			let [, hkeyword] = keyword;
			keyword = keyword[0];

			// Store the provided command string fallback (default/always).
			store_fallback(keyword, hkeyword, value, hvalue, chain);

			// Reset flag to newly parsed value.
			flagset = `${keyword} ${value}`;
			// Set highlighted version.
			hflagset = `${hkeyword} ${hvalue}`;
		} else {
			// If value is not a string (therefore an array) join values.
			if (typeof value !== "string" && value.length > 1) {
				value = `(${value.join(" ")})`;
				hvalue = `(${hvalue.join(" ")})`;
			}

			// Reset flag to newly parsed value.
			flagset = `${symbol}${name}${assignment}${value}`;
			// Set highlighted version.
			hflagset = `${symbol}${hname}${assignment}${hvalue}`;
		}

		// Reset oneliner start index.
		indices.oneliner.start = (nl_index || i) + 1;

		// Don't add fallback (default/always) to flagsets as they have
		// their own section (bottom of output) unless formatting.
		if (!keyword || formatting) {
			// Store current flag set.
			flagsets.push(flagset);
			// Set highlighted version.
			hflagsets.push(hflagset);
		}

		// Reset flag set string.
		flagset = "";
		hflagset = "";
	}

	// If there was assignment do some value checks.
	if (assignment && !flagsets.length) {
		// Determine brace state.
		brstate =
			value === "[]" ? "closed" : value === "[" ? "open" : undefined;

		// If assignment but not value give warning.
		if (!value) {
			// Reset index to point to eq sign.
			i = indices.assignment.index;

			// Add warning.
			issue("warning", 5, "=");
		}

		// If assignment but not value give warning.
		if (brstate === "closed") {
			// Reset index to point to opening brace'['.
			i = indices.value.start;

			// Add warning.
			issue("warning", 6);
		}
	}

	// Check if command chain is a duplicate.
	if (lookup[chain]) {
		// Reset index.
		i = indices.chain.end;

		// Add warning.
		issue("warning", 10, chain);
	}

	// Unset global oneliner flag set used for dupe checks.
	if (global.$app.vars.oneliner) {
		delete global.$app.vars.oneliner;
		global.$app.size(-1); // Decrease size by 1.
	}

	// Return relevant parsing information.
	return {
		chain,
		value,
		brstate,
		assignment,
		flagsets,
		hflagsets,
		nl_index,
		delimiter,
		warnings,
		has_shortcuts,
		is_oneliner,
		// Return brace opening index for later error checks.
		br_open_index: indices.braces.open - line_fchar + 1, // Add 1 to account for 0 index.
		// Return delimiter index for later error checks.
		delimiter_index: indices.delimiter.index - line_fchar + 1,
		h: {
			chain: h(chain, "command")
		}
	};
};

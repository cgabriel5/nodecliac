#!/usr/bin/env node

"use strict";

const lexer = require("./lexer");
const { vsetting, vvariable, vstring, vsetting_aval } = require("./validation.js");
const { builtins } = require("./defvars.js");
const { issue_hint, issue_warn, issue_error } = require("./issue.js");
const { hasProp } = require("../../utils/toolbox.js");
const acdef = require("./acdef.js");
const formatter = require("./formatter.js");

const R = /(?<!\\)\$\{\s*[^}]*\s*\}/g;

async function parser(action, text, cmdname, source, fmt, trace, igc, test) {
	let ttid = 0;
	let NEXT = [];
	let SCOPE = [];
	let branch = [];
	let BRANCHES = [];
	let oneliner = -1;

	let chain = [];
	let CCHAINS = [];
	let ubids = [];
	let FLAGS = {};
	let flag = {};

	let setting = [];
	let SETTINGS = [];

	let variable = [];
	let VARIABLES = [];

	let USED_VARS = {};
	let USER_VARS = {};
	let VARSTABLE = builtins(cmdname);
	let vindices = {};

	let { tokens, ttypes, ttids, dtids, LINESTARTS } = lexer.tokenizer(text);

	let i = 0;
	let l = tokens.length;

	let S = {
		tid: -1,
		filename: source,
		text: text,
		args: {
			action: action,
			source: source,
			fmt: fmt,
			trace: trace,
			igc: igc,
			test: test
		},
		ubids: ubids,
		excludes: [],
		warnings: {},
		warn_lines: new Set(),
		warn_lsort: new Set(),
		lexerdata: { LINESTARTS, tokens, ttypes, ttids, dtids }
	};

	let lastn = (list, offset = -1) => list[list.length + offset];
	let strfrmpts = (s, start, end) => s.substring(start, end + 1);

	function tkstr(S, tid) {
		if (tid === -1) return "";
		if (S.lexerdata.tokens[tid].kind === "tkSTR") {
			if (S.lexerdata.tokens[tid].$) {
				return S.lexerdata.tokens[tid].$;
			}
		}
		return strfrmpts(S.text, S.lexerdata.tokens[tid].start, S.lexerdata.tokens[tid].end);
	}

	function err(tid, message, pos = "start", scope = "") {
		// When token ID points to end-of-parsing token,
		// reset the id to the last true token before it.
		if (S.lexerdata.tokens[tid].kind === "tkEOP") {
			tid = lastn(S.lexerdata.ttids);
		}

		let token = S.lexerdata.tokens[tid];
		let line = token.line;
		let index = token[pos];
		// let msg = message;
		let col = index - S.lexerdata.LINESTARTS[line];

		if (message.endsWith(":")) {
			message += " '" + tkstr(S, tid) + "'";
		}

		// // Add token debug information.
		// dbeugmsg = "\n\n\033[1mToken\033[0m: "
		// dbeugmsg += "\n - tid: " + str(token["tid"])
		// dbeugmsg += "\n - kind: " + token["kind"]
		// dbeugmsg += "\n - line: " + str(token["line"])
		// dbeugmsg += "\n - start: " + str(token["start"])
		// dbeugmsg += "\n - end: " + str(token["end"])
		// dbeugmsg += "\n __val__: [" + tkstr(tid) + "]"

		// dbeugmsg += "\n\n\033[1mExpected\033[0m: "
		// for n in NEXT:
		//     if not n: n = "\"\""
		//     dbeugmsg += "\n - " + n
		// dbeugmsg += "\n\n\033[1mScopes\033[0m: "
		// for s in SCOPE:
		//     dbeugmsg += "\n - " + s
		// decor = "-" * 15
		// msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor
		// msg += dbeugmsg
		// msg += "\n\n" + decor + " TOKEN_DEBUG_INFO " + decor

		issue_error(S.filename, line, col, message);
	}

	function warn(tid, message) {
		let token = S.lexerdata.tokens[tid];
		let line = token.line;
		let index = token.start;
		let col = index - S.lexerdata.LINESTARTS[line];

		if (message.endsWith(":")) {
			message += " '" + tkstr(S, tid) + "'";
		}

		if (!hasProp(S.warnings, line)) {
			S.warnings[line] = [];
		}

		S.warnings[line].push([S.filename, line, col, message]);
		S.warn_lines.add(line);
	}

	function hint(tid, message) {
		let token = S.lexerdata.tokens[tid];
		let line = token.line;
		let index = token.start;
		let col = index - S.lexerdata.LINESTARTS[line];

		if (message.endsWith(":")) {
			message += " '" + tkstr(S, tid) + "'";
		}

		issue_hint(S.filename, line, col, message);
	}

	function addtoken(S, i) {
		// Interpolate/track interpolation indices for string.
		if (S.lexerdata.tokens[i].kind === "tkSTR") {
			let value = tkstr(S, i);
			S.lexerdata.tokens[i].$ = value;

			if (S.args.action !== "format" && !hasProp(vindices, i)) {
				let end = 0;
				let pointer = 0;
				let tmpstr = "";
				vindices[i] = [];

				let matches = [...value.matchAll(R)];
				for (let j = 0, l = matches.length; j < l; j++) {
					let match = matches[j];

					let start = match.index;
					end = start + match[0].length;
					let varname = match[0].slice(2, -1).trim();

					if (!hasProp(VARSTABLE, varname)) {
						// Note: Modify token index to point to
						// start of the variable position.
						// s.LexerData.Tokens[S.Tid].Start += start
						S.lexerdata.tokens[S.tid].start += start;
						err(ttid, "Undefined variable", "start", "child");
					}

					USED_VARS[varname] = 1;
					vindices[i].push([start, end]);

					tmpstr += value.substring(pointer, start);
					let sub = VARSTABLE[varname] || "";
					if (sub !== "") {
						if (!(sub[0] === '"' || sub[1] === "'")) {
							tmpstr += sub;
						} else {
							// Unquote string if quoted.
							tmpstr += sub.slice(1, -1);
						}
					}
					pointer = end;
				}

				// Get tail-end of string.
				tmpstr += value.substr(end);
				S.lexerdata.tokens[i].$ = tmpstr;

				if (vindices[i].length === 0) {
					delete vindices[i];
				}
			}
		}

		lastn(BRANCHES).push(tokens[i]);
	}

	function expect(...args) {
		NEXT.length = 0;
		for (let i = 0, l = args.length; i < l; i++) NEXT.push(args[i]);
	}

	function clearscope() {
		SCOPE.length = 0;
	}

	function addscope(s) {
		SCOPE.push(s);
	}

	function popscope(pops = 1) {
		while (pops > 0) {
			SCOPE.pop();
			pops -= 1;
		}
	}

	function hasscope(s) {
		return SCOPE.includes(s);
	}

	function prevscope() {
		return lastn(SCOPE);
	}

	function hasnext(s) {
		return NEXT.includes(s);
	}

	function nextany() {
		return NEXT[0] === "";
	}

	function addbranch() {
		BRANCHES.push(branch);
	}

	function newbranch() {
		branch = [];
	}

	function prevtoken(s) {
		return S.lexerdata.tokens[S.lexerdata.dtids[S.tid]];
	}

	// Command chain/flag grouping helpers.
	// ================================

	function newgroup() {
		chain = [];
	}

	function addtoken_group(i) {
		chain.push(i);
	}

	function addgroup(g) {
		CCHAINS.push([g]);
	}

	function addtoprevgroup() {
		newgroup();
		lastn(CCHAINS).push(chain);
	}

	// ============================

	function newvaluegroup(prop) {
		flag[prop].push([-1]);
	}

	function setflagprop(prop, prev_val_group = false) {
		let index = CCHAINS.length - 1;

		if (prop !== "values") {
			lastn(FLAGS[index])[prop] = S.tid;
		} else {
			if (!prev_val_group) {
				lastn(FLAGS[index])[prop].push([S.tid]);
			} else {
				lastn(lastn(FLAGS[index])[prop]).push(S.tid);
			}
		}
	}

	function newflag() {
		flag = {
			tid: -1,
			alias: -1,
			boolean: -1,
			assignment: -1,
			multi: -1,
			union: -1,
			values: []
		};
		let index = CCHAINS.length - 1;
		if (!hasProp(FLAGS, index)) {
			FLAGS[index] = [];
		}
		FLAGS[index].push(flag);
		setflagprop("tid");
	}

	// Setting/variable grouping helpers.
	// ================================

	function newgroup_stn() {
		setting = [];
	}

	function addtoken_stn_group(i) {
		setting.push(i);
	}

	function addgroup_stn(g) {
		SETTINGS.push(g);
	}

	// function addtoprevgroup_stn() {
	//   newgroup_stn()
	//   lastn(SETTINGS).push(setting)
	// }

	// ============================

	function newgroup_var() {
		variable = [];
	}

	function addtoken_var_group(i) {
		variable.push(i);
	}

	function addgroup_var(g) {
		VARIABLES.push(g);
	}

	// void addtoprevgroup_var() {
	//     newgroup_var()
	//     VARIABLES.back().push_back(variable)
	// }

	while (i < l) {
		let token = tokens[i];
		let kind = token.kind;
		let line = token.line;
		// start = token.start
		// end = token.end
		S.tid = token.tid;

		if (kind === "tkNL") {
			i += 1;
			continue;
		}

		if (kind !== "tkEOP") {
			ttid = i;
		}

		if (kind === "tkTRM") {
			if (!SCOPE.length) {
				addbranch();
				addtoken(S, ttid);
				newbranch();
				expect("");
			} else {
				addtoken(S, ttid);

				if (NEXT.length && !nextany()) {
					err(ttid, "Improper termination", "start", "child");
				}
			}

			i += 1;
			continue;
		}

		if (!SCOPE.length) {
			oneliner = -1;

			if (BRANCHES.length) {
				let ltoken = lastn(lastn(BRANCHES)); // Last branch token.
				if (line === ltoken.line && ltoken.kind !== "tkTRM") {
					err(ttid, "Improper termination", "start", "parent");
				}
			}

			if (kind !== "tkEOP") {
				addbranch();
				addtoken(S, ttid);

				if (new Set(["tkSTN", "tkVAR", "tkCMD"]).has(kind)) {
					addscope(kind);
					if (kind === "tkSTN") {
						newgroup_stn();
						addgroup_stn(setting);
						addtoken_stn_group(S.tid);

						vsetting(S);
						expect("", "tkASG");
					} else if (kind === "tkVAR") {
						newgroup_var();
						addgroup_var(variable);
						addtoken_var_group(S.tid);

						let varname = tkstr(S, S.tid).slice(1);
						VARSTABLE[varname] = "";

						if (!hasProp(USER_VARS, varname)) {
							USER_VARS[varname] = [];
						}
						USER_VARS[varname].push(S.tid);

						vvariable(S);
						expect("", "tkASG");
					} else if (kind === "tkCMD") {
						addtoken_group(S.tid);
						addgroup(chain);

						expect("", "tkDDOT", "tkASG", "tkDCMA");

						let command = tkstr(S, S.tid);
						if (command !== "*" && command !== cmdname) {
							warn(S.tid, "Unexpected command:");
						}
					}
				} else {
					if (kind === "tkCMT") {
						newbranch();
						expect("");
					} else {
						// Handle unexpected parent tokens.
						err(S.tid, "Unexpected token:", "start", "parent");
					}
				}
			}
		} else {
			if (kind === "tkCMT") {
				addtoken(S, ttid);
				i += 1;
				continue;
			}

			// Remove/add necessary tokens when parsing long flag form.
			if (hasscope("tkBRC_LB")) {
				if (hasnext("tkDPPE")) {
					// Remove "tkDPPE"
					NEXT = NEXT.filter((tk) => tk !== "tkDPPE");
					NEXT.push("tkFLG");
					NEXT.push("tkKYW");
					NEXT.push("tkBRC_RB");
				}
			}

			if (NEXT.length && !hasnext(kind)) {
				if (nextany()) {
					clearscope();
					newbranch();

					newgroup();
					// i += 1;
					continue;
				} else {
					err(S.tid, "Unexpected token:", "start", "child");
				}
			}

			addtoken(S, ttid);

			// Oneliners must be declared on oneline, else error.
			if (
				lastn(BRANCHES)[0].kind === "tkCMD" &&
				(hasscope("tkFLG") || hasscope("tkKYW") || new Set(["tkFLG", "tkKYW"]).has(kind)) &&
				!hasscope("tkBRC_LB")
			) {
				if (oneliner === -1) {
					oneliner = token.line;
				} else if (token.line !== oneliner) {
					err(S.tid, "Improper oneliner", "start", "child");
				}
			}

			switch (prevscope()) {
				case "tkSTN":
					switch (kind) {
						case "tkASG":
							addtoken_stn_group(S.tid);

							expect("tkSTR", "tkAVAL");

							break;

						case "tkSTR":
							addtoken_stn_group(S.tid);

							expect("");

							vstring(S);

							break;

						case "tkAVAL":
							addtoken_stn_group(S.tid);

							expect("");

							vsetting_aval(S);

							break;
					}

					break;

				case "tkVAR":
					switch (kind) {
						case "tkASG":
							addtoken_var_group(S.tid);

							expect("tkSTR");

							break;

						case "tkSTR":
							addtoken_var_group(S.tid);
							VARSTABLE[tkstr(S, lastn(lastn(BRANCHES), -3).tid).slice(1)] = tkstr(S, S.tid);

							expect("");

							vstring(S);

							break;
					}

					break;

				case "tkCMD":
					switch (kind) {
						case "tkASG":
							// If a universal block, store group id.
							if (hasProp(S.lexerdata.dtids, S.tid)) {
								let prevtk = prevtoken(S);
								if (prevtk.kind === "tkCMD" && S.text[prevtk.start] === "*") {
									S.ubids.push(CCHAINS.length - 1);
								}
							}
							expect("tkBRC_LB", "tkFLG", "tkKYW");

							break;

						case "tkBRC_LB":
							addscope(kind);
							expect("tkFLG", "tkKYW", "tkBRC_RB");

							break;

						// // [TODO] Pathway needed?
						// case "tkBRC_RB":
						// 	expect("", "tkCMD")
						// break;

						case "tkFLG":
							newflag();

							addscope(kind);
							expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB");

							break;

						case "tkKYW":
							newflag();

							addscope(kind);
							expect("tkSTR", "tkDLS");

							break;

						case "tkDDOT":
							expect("tkCMD", "tkBRC_LC");

							break;

						case "tkCMD":
							addtoken_group(S.tid);

							expect("", "tkDDOT", "tkASG", "tkDCMA");

							break;

						case "tkBRC_LC":
							addtoken_group(-1);

							addscope(kind);
							expect("tkCMD");

							break;

						case "tkDCMA":
							// If a universal block, store group id.
							if (hasProp(S.lexerdata.dtids, S.tid)) {
								let prevtk = prevtoken(S);
								if (prevtk.kind === "tkCMD" && S.text[prevtk.start] === "*") {
									S.ubids.push(CCHAINS.length - 1);
								}
							}

							addtoprevgroup();

							addscope(kind);
							expect("tkCMD");

							break;
					}

					break;

				case "tkBRC_LC":
					switch (kind) {
						case "tkCMD":
							addtoken_group(S.tid);

							expect("tkDCMA", "tkBRC_RC");

							break;

						case "tkDCMA":
							expect("tkCMD");

							break;

						case "tkBRC_RC":
							addtoken_group(-1);

							popscope(1);
							expect("", "tkDDOT", "tkASG", "tkDCMA");

							break;
					}

					break;

				case "tkFLG":
					switch (kind) {
						case "tkDCLN":
							if (prevtoken(S).kind !== "tkDCLN") {
								expect("tkDCLN");
							} else {
								expect("tkFLGA");
							}

							break;

						case "tkFLGA":
							setflagprop("alias", false);

							expect("", "tkASG", "tkQMK", "tkDPPE");

							break;

						case "tkQMK":
							setflagprop("boolean", false);

							expect("", "tkDPPE");

							break;

						case "tkASG":
							setflagprop("assignment", false);

							expect("", "tkDCMA", "tkMTL", "tkDPPE", "tkBRC_LP", "tkFVAL", "tkSTR", "tkDLS", "tkBRC_RB");

							break;

						case "tkDCMA":
							setflagprop("union", false);

							expect("tkFLG", "tkKYW");

							break;

						case "tkMTL":
							setflagprop("multi", false);

							expect("", "tkBRC_LP", "tkDPPE");

							break;

						case "tkDLS":
							addscope(kind); // Build cmd-string.
							expect("tkBRC_LP");

							break;

						case "tkBRC_LP":
							addscope(kind);
							expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP");

							break;

						case "tkFLG":
							newflag();

							if (hasscope("tkBRC_LB") && token.line === prevtoken(S).line) {
								err(S.tid, "Flag same line (nth)", "start", "child");
							}
							expect("", "tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE");

							break;

						case "tkKYW":
							newflag();

							// [TODO] Investigate why leaving flag scope doesn't affect
							// parsing. For now remove it to keep scopes array clean.
							popscope(1);

							if (hasscope("tkBRC_LB") && token.line === prevtoken(S).line) {
								err(S.tid, "Keyword same line (nth)", "start", "child");
							}
							addscope(kind);
							expect("tkSTR", "tkDLS");

							break;

						case "tkSTR":
							setflagprop("values", false);

							expect("", "tkDPPE");

							break;

						case "tkFVAL":
							setflagprop("values", false);

							expect("", "tkDPPE");

							break;

						case "tkDPPE":
							expect("tkFLG", "tkKYW");

							break;

						case "tkBRC_RB":
							popscope(1);
							expect("");

							break;
					}

					break;

				case "tkBRC_LP":
					switch (kind) {
						case "tkFOPT":
							let prevtk = prevtoken(S);
							if (prevtk.kind === "tkBRC_LP") {
								if (prevtk.line === line) {
									err(S.tid, "Option same line (first)", "start", "child");
								}
								addscope("tkOPTS");
								expect("tkFVAL", "tkSTR", "tkDLS");
							}

							break;

						case "tkFVAL":
							setflagprop("values", false);

							expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD");
							// // Disable pathway for now.
							// when "tkTBD":
							// 	setflagprop("values", false)

							// 	expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD")
							// 	break;

							break;

						case "tkSTR":
							setflagprop("values", false);

							expect("tkFVAL", "tkSTR", "tkDLS", "tkBRC_RP", "tkTBD");

							break;

						case "tkDLS":
							addscope(kind);
							expect("tkBRC_LP");
							// // [TODO] Pathway needed?
							// when "tkDCMA":
							// 	expect("tkFVAL", "tkSTR")
							// 	break;

							break;

						case "tkBRC_RP":
							{
								popscope(1);
								expect("", "tkDPPE");

								let prevtk = prevtoken(S);
								if (prevtk.kind === "tkBRC_LP") {
									warn(prevtk.tid, "Empty scope (flag)");
								}
							}

							break;

						// // [TODO] Pathway needed?
						// when "tkBRC_RB":
						// 	popscope(1);
						// 	expect("");
						// 	break;
					}

					break;

				case "tkDLS":
					switch (kind) {
						case "tkBRC_LP":
							newvaluegroup("values");
							setflagprop("values", true);

							expect("tkSTR");

							break;

						case "tkDLS":
							expect("tkSTR");

							break;

						case "tkSTR":
							expect("tkDCMA", "tkBRC_RP");

							break;

						case "tkDCMA":
							expect("tkSTR", "tkDLS");

							break;

						case "tkBRC_RP":
							popscope(1);

							setflagprop("values", true);

							// Handle: 'program = --flag=$("cmd")'
							// Handle: 'program = default $("cmd")'
							if (new Set(["tkFLG", "tkKYW"]).has(prevscope())) {
								if (hasscope("tkBRC_LB")) {
									popscope(1);
									expect("tkFLG", "tkKYW", "tkBRC_RB");
								} else {
									// Handle: oneliner command-string
									// 'program = --flag|default $("cmd", $"c", "c")'
									// 'program = --flag::f=(1 3)|default $("cmd")|--flag'
									// 'program = --flag::f=(1 3)|default $("cmd")|--flag'
									// 'program = default $("cmd")|--flag::f=(1 3)'
									// 'program = default $("cmd")|--flag::f=(1 3)|default $("cmd")'
									expect("", "tkDPPE", "tkFLG", "tkKYW");
								}

								// Handle: 'program = --flag=(1 2 3 $("c") 4)'
							} else if (prevscope() === "tkBRC_LP") {
								expect("tkFVAL", "tkSTR", "tkFOPT", "tkDLS", "tkBRC_RP");

								// Handle: long-form
								// 'program = [
								// 	--flag=(
								// 		- 1
								// 		- $("cmd")
								// 		- true
								// 	)
								// ]'
							} else if (prevscope() === "tkOPTS") {
								expect("tkFOPT", "tkBRC_RP");
							}

							break;
					}

					break;

				case "tkOPTS":
					switch (kind) {
						case "tkFOPT":
							if (prevtoken(S).line === line) {
								err(S.tid, "Option same line (nth)", "start", "child");
							}
							expect("tkFVAL", "tkSTR", "tkDLS");

							break;

						case "tkDLS":
							addscope("tkDLS"); // Build cmd-string.
							expect("tkBRC_LP");

							break;

						case "tkFVAL":
							setflagprop("values", false);

							expect("tkFOPT", "tkBRC_RP");

							break;

						case "tkSTR":
							setflagprop("values", false);

							expect("tkFOPT", "tkBRC_RP");

							break;

						case "tkBRC_RP":
							popscope(2);
							expect("tkFLG", "tkKYW", "tkBRC_RB");

							break;
					}

					break;

				case "tkBRC_LB":
					switch (kind) {
						case "tkFLG":
							newflag();

							if (hasscope("tkBRC_LB") && token.line === prevtoken(S).line) {
								err(S.tid, "Flag same line (first)", "start", "child");
							}
							addscope(kind);
							expect("tkASG", "tkQMK", "tkDCLN", "tkFVAL", "tkDPPE", "tkBRC_RB");

							break;

						case "tkKYW":
							newflag();

							if (hasscope("tkBRC_LB") && token.line === prevtoken(S).line) {
								err(S.tid, "Keyword same line (first)", "start", "child");
							}
							addscope(kind);
							expect("tkSTR", "tkDLS", "tkBRC_RB");

							break;

						case "tkBRC_RB":
							{
								popscope(1);
								expect("");

								let prevtk = prevtoken(S);
								if (prevtk.kind === "tkBRC_LB") {
									warn(prevtk.tid, "Empty scope (command)");
								}
							}

							break;
					}

					break;

				case "tkKYW":
					switch (kind) {
						case "tkSTR":
							setflagprop("values", false);

							// Collect exclude values for use upstream.
							if (hasProp(S.lexerdata.dtids, S.tid)) {
								let prevtk = prevtoken(S);
								if (prevtk.kind === "tkKYW" && tkstr(S, prevtk.tid) === "exclude") {
									let excl_values = tkstr(S, S.tid).slice(1, -1).trim().split(";");
									// for exclude in excl_values: S.excludes.push(exclude)
									// excl_values.each { |exclude|
									// 	S.excludes.push(exclude)
									// }
								}
							}

							// [TODO] This pathway re-uses the flag (tkFLG) token
							// pathways. If the keyword syntax were to change
							// this will need to change as it might no loner work.
							popscope(1);
							addscope("tkFLG"); // Re-use flag pathways for now.
							expect("", "tkDPPE");

							break;

						case "tkDLS":
							addscope(kind); // Build cmd-string.
							expect("tkBRC_LP");
							// // [TODO] Pathway needed?
							// when "tkBRC_RB":
							// 	popscope(1);
							// 	expect("")
							// // [TODO] Pathway needed?
							// when "tkFLG":
							// 	expect("tkASG", "tkQMK"
							// 		"tkDCLN", "tkFVAL", "tkDPPE")
							// // [TODO] Pathway needed?
							// when "tkKYW":
							// 	addscope(kind);
							// 	expect("tkSTR", "tkDLS")

							break;

						case "tkDPPE":
							// [TODO] Because the flag (tkFLG) token pathways are
							// reused for the keyword (tkKYW) pathways, the scope
							// needs to be removed. This is fine for now but when
							// the keyword token pathway change, the keyword
							// pathways will need to be fleshed out in the future.
							if (prevscope() === "tkKYW") {
								popscope(1);
								addscope("tkFLG"); // Re-use flag pathways for now.
							}
							expect("tkFLG", "tkKYW");

							break;
					}

					break;

				case "tkDCMA":
					switch (kind) {
						case "tkCMD":
							addtoken_group(S.tid);

							popscope(1);
							expect("", "tkDDOT", "tkASG", "tkDCMA");

							let command = tkstr(S, S.tid);
							if (command !== "*" && command !== cmdname) {
								warn(S.tid, "Unexpected command:");
							}

							break;
					}

					break;

				default:
					err(S.lexerdata.tokens[S.tid].tid, "Unexpected token:", "end", "");

					break;
			}
		}

		i += 1;
	}

	// Check for any unused variables and give warning.
	for (const uservar in USER_VARS) {
		if (!hasProp(USED_VARS, uservar)) {
			for (let i = 0, l = USER_VARS[uservar].length; i < l; i++) {
				let tid = USER_VARS[uservar][i];
				warn(tid, `Unused variable: '${uservar}'`);
				S.warn_lsort.add(tokens[tid].line);
			}
		}
	}

	// Sort warning lines and print issues.
	let warnlines = Array.from(S.warn_lines);
	warnlines = warnlines.sort((a, b) => a - b);

	for (let i = 0, l = warnlines.length; i < l; i++) {
		let warnline = warnlines[i];
		// Only sort lines where unused variable warning(s) were added.
		if (S.warn_lsort.has(warnline) && S.warnings[warnline].length > 1) {
			// [https://stackoverflow.com/a/46256174]
			S.warnings[warnline].sort((a, b) => a[1] - b[1] || a[2] - b[2]);
		}
		for (let i = 0, l = S.warnings[warnline].length; i < l; i++) {
			let warning = S.warnings[warnline][i];
			issue_warn(...warning);
		}
	}

	if (action == "make") return Promise.resolve(acdef(BRANCHES, CCHAINS, FLAGS, SETTINGS, S, cmdname));
	else return Promise.resolve(formatter(tokens, text, BRANCHES, CCHAINS, FLAGS, SETTINGS, S));
}

module.exports = parser;

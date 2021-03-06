"use strict";

const { nk } = require("../helpers/enums.js");

/**
 * Formats (prettifies) .acmap file.
 *
 * @param  {object} S - State object.
 * @return {string} - The prettied file contents.
 */
module.exports = (S) => {
	let { fmt, igc } = S.args;
	let { nodes } = S.tables.tree;
	const eN = {};
	let output = [];
	let passed = [];
	const r = /^[ \t]+/g;
	let alias;

	// Indentation level multipliers.
	let MXP = {
		COMMENT: 0,
		COMMAND: 0,
		FLAG: 1,
		OPTION: 2,
		BRACE: 0,
		NEWLINE: 0,
		SETTING: 0,
		VARIABLE: 0
	};

	let nl_count = 0; // Track consecutive newlines.
	let scopes = []; // Track command/flag scopes.

	const [ichar, iamount] = fmt;
	let indent = (type, count) => ichar.repeat((count || MXP[type]) * iamount);

	/**
	 * Gets next node that is not a comment. Also takes into account
	 *     subsequent newline node.
	 *
	 * @param  {number} i - The index to start search.
	 * @param  {number} l - The length of array.
	 * @return {object} - The node object.
	 */
	let nextnode = (i, l) => {
		let r = eN;
		if (igc) {
			for (i = i + 1; i < l; i++) {
				let N = nodes[i];
				let type = N.node;
				if (type !== nk.Comment) {
					r = N;
					break;
				} else if (type === nk.Comment) i++;
			}
		} else r = nodes[i + 1];

		return r;
	};

	/**
	 * Gets the node previously iterated over.
	 *
	 * @param  {number} i - The index to start search.
	 * @param  {number} l - The length of array.
	 * @return {object} - The node object.
	 */
	let lastnode = (i /*, l*/) => {
		let r = eN;
		if (igc) r = passed[passed.length - 1];
		else r = nodes[i - 1];
		return r;
	};

	// Loop over nodes to build formatted file.

	for (let i = 0, l = nodes.length; i < l; i++) {
		let N = nodes[i];
		let type = N.node;

		// Ignore starting newlines.
		if (!output.length && type === nk.Newline) continue;
		// Remove comments when flag is provided.
		if (igc && type === nk.Comment) {
			i++;
			continue;
		}

		switch (type) {
			case nk.Comment:
				{
					let scope = scopes[scopes.length - 1] || null;
					let pad = !N.inline ? indent(null, scope) : " ";

					output.push(`${pad}${N.comment.value}`);
				}

				break;

			case nk.Newline:
				{
					let nN = nextnode(i, l);

					if (nl_count <= 1) output.push("\n");
					nl_count++;
					if (nN && nN.node !== nk.Newline) nl_count = 0;

					if (scopes.length) {
						let last = output[output.length - 2];
						let lchar = last[last.length - 1];
						let isbrace = lchar === "[" || lchar === "(";
						if (isbrace && nN && nN.node === nk.Newline) nl_count++;
						if (nN.node === nk.Brace) {
							if (lastnode(i, l).node === nk.Newline)
								output.pop();
						}
					}
				}

				break;

			case nk.Setting:
				{
					let nval = N.name.value;
					let aval = N.assignment.value;
					let vval = N.value.value;

					let r = "@";
					if (nval) {
						r += nval;
						if (aval) {
							r += ` ${aval}`;
							if (vval) {
								r += ` ${vval}`;
							}
						}
					}

					output.push(r);
				}

				break;

			case nk.Variable:
				{
					let nval = N.name.value;
					let aval = N.assignment.value;
					let vval = N.value.value;

					let r = "$";
					if (nval) {
						r += nval;
						if (aval) {
							r += ` ${aval}`;
							if (vval) {
								r += ` ${vval}`;
							}
						}
					}

					output.push(r);
				}

				break;

			case nk.Command:
				{
					let vval = N.value.value;
					let cval = N.command.value;
					let dval = N.delimiter.value;
					let aval = N.assignment.value;

					let r = "";
					if (cval) {
						r += cval;
						if (dval) {
							r += dval;
						} else {
							if (aval) {
								r += ` ${aval}`;
								if (vval) {
									r += ` ${vval}`;
								}
							}
						}
					}

					let nN = nextnode(i, l);
					if (nN && nN.node === nk.Flag) r += " ";
					output.push(r);
					if (vval && vval === "[") scopes.push(1); // Track scope.
				}

				break;

			case nk.Flag:
				{
					if (N.virtual) {
						continue;
					}

					let kval = N.keyword.value;
					let hval = N.hyphens.value;
					let nval = N.name.value;
					let bval = N.boolean.value;
					let aval = N.assignment.value;
					let dval = N.delimiter.value;
					let mval = N.multi.value;
					let vval = N.value.value;
					let ival = N.alias.value;
					let singleton = N.singleton;
					let pad = indent(null, singleton ? 1 : null);
					let pipe_del = singleton ? "" : "|";

					// Skip if an alias and set ref for later.
					if (ival && ival === nval) {
						alias = N;
						continue;
					}

					// Note: If nN is a flag reset var.
					if (pipe_del) {
						let nN = nextnode(i, l);
						if (nN && nN.node !== nk.Flag) pipe_del = "";
					}

					// [https://stackoverflow.com/a/23867090]
					let r = pad;

					if (kval) {
						r += kval;
						if (vval) r += ` ${vval}`;
					} else {
						if (hval) {
							r += hval;
							if (nval) {
								r += nval;
								if (
									ival &&
									alias &&
									ival === alias.alias.value
								) {
									r += `::${ival}`;
									alias = null;
								}
								if (bval) {
									r += bval;
								} else if (aval) {
									r += aval;
									if (mval) r += mval;
									if (dval) r += dval;
									if (vval) r += vval;
								}
							}
						}
					}

					output.push(r + pipe_del);

					if (vval && vval === "(") scopes.push(2); // Track scope.
				}

				break;

			case nk.Option:
				{
					let bval = N.bullet.value;
					let vval = N.value.value;
					let pad = indent("OPTION");

					let r = pad;
					if (bval) {
						r += bval;
						if (vval) {
							r += ` ${vval}`;
						}
					}

					output.push(r);
				}

				break;

			case nk.Brace:
				{
					let bval = N.brace.value;
					let pad = indent(null, bval === "]" ? 0 : 1);

					if (bval === ")") {
						let l = output.length;
						let last = output[l - 1];
						let slast = output[l - 2];
						let ll = last.length;
						let lfchar = last.replace(r, "")[0];
						let slchar = slast[slast.length - 1];

						if (lfchar === "-" && last[ll - 1] === "(") pad = "";
						else if (last === "\n" && slchar === "(") {
							pad = "";
							output.pop();
						}
					} else if (bval === "]") {
						let l = output.length;
						let last = output[l - 1];
						let slast = output[l - 2];
						if (last === "\n" && slast === "\n") {
							output.pop();
						} else {
							let sl = slast.length;
							let slchar = slast[sl - 1];
							if (last === "\n" && slchar === "[") output.pop();
						}
					}

					output.push(`${pad}${bval}`);
					scopes.pop(); // Un-track last scope.
				}

				break;
		}

		passed.push(N);
	}

	/*eslint no-constant-condition: ["error", { "checkLoops": false }]*/
	let i = output.length - 1;
	while (true) {
		if (output[i] !== "\n") break;
		output.pop();
		i--;
	}

	return output.join("") + "\n";
};

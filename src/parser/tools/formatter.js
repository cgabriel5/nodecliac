"use strict";

/**
 * Formats (prettifies) .acmap file.
 *
 * @param  {object} S - State object.
 * @return {string} - The prettied file contents.
 */
module.exports = S => {
	let { fmt, igc } = S.args;
	let { nodes } = S.tables.tree;
	let output = "";

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

	// Filter comment nodes when flag is provided.
	if (igc) nodes = nodes.filter(N => (N.node !== "COMMENT"));

	// Loop over nodes to build formatted file.
	nodes.forEach((N, i) => {
		let type = N.node;

		switch (type) {
			case "COMMENT":
				{
					let scope = scopes[scopes.length - 1] || null;
					let pad = indent(null, scope);

					output += `${pad}${N.comment.value}`;
				}

				break;

			case "NEWLINE":
				{
					let nN = nodes[i + 1];

					if (nl_count <= 1) output += "\n";
					nl_count++;
					if (nN && nN.node !== "NEWLINE") nl_count = 0;
				}

				break;

			case "SETTING":
				{
					let nval = N.name.value;
					let aval = N.assignment.value;
					let vval = N.value.value;

					output += `@${nval} ${aval} ${vval}`;
				}

				break;

			case "VARIABLE":
				{
					let nval = N.name.value;
					let aval = N.assignment.value;
					let vval = N.value.value;

					output += `$${nval} ${aval} ${vval}`;
				}

				break;

			case "COMMAND":
				{
					let vval = N.value.value;
					let cval = N.command.value;
					let dval = N.delimiter.value;
					let aval = N.assignment.value;

					output += `${cval}${dval} ${aval} ${vval}`;
					if (vval && vval === "[") scopes.push(1); // Track scope.
				}

				break;

			case "FLAG":
				{
					let kval = N.keyword.value;
					let hval = N.hyphens.value;
					let nval = N.name.value;
					let bval = N.boolean.value;
					let aval = N.assignment.value;
					let mval = N.multi.value;
					let vval = N.value.value;
					let singleton = N.singleton;
					let pad = indent(null, singleton ? 1 : null);
					let pipe_del = singleton ? "" : "|";

					// Note: If nN is a flag reset var.
					if (pipe_del) {
						let nN = nodes[i + 1];
						if (nN && nN.node !== "FLAG") pipe_del = "";
					}

					output += // [https://stackoverflow.com/a/23867090]
						pad +
						(kval ? kval + " " : "") +
						hval +
						nval +
						bval +
						aval +
						mval +
						vval +
						pipe_del;

					if (vval && vval === "(") scopes.push(2); // Track scope.
				}

				break;

			case "OPTION":
				{
					let bval = N.bullet.value;
					let vval = N.value.value;
					let pad = indent("OPTION");

					output += `${pad}${bval} ${vval}`;
				}

				break;

			case "BRACE":
				{
					let bval = N.brace.value;
					let pad = indent(null, bval === "]" ? 0 : 1);

					output += `${pad}${bval}`;
					scopes.pop(); // Un-track last scope.
				}

				break;
		}
	});

	// Final newline replacements.
	return (
		output
			.replace(/(\[|\()$\n{2}/gm, "$1\n")
			.replace(/\n{2}([ \t]*)(\]|\))$/gm, "\n$1$2")
			.replace(/^\s*|\s*$/g, "")
			.replace(/ *$/gm, "") + "\n"
	);
};

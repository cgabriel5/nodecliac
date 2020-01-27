"use strict";

/**
 * Format (prettify) provided .addef file.
 *
 * @param  {object} S - Main loop state object.
 * @return {string} - The prettied file contents.
 */
module.exports = S => {
	let { fmt, igc } = S.args;
	let TREE = S.tables.tree;
	let nodes = TREE.nodes;
	let output = "";

	// Indentation level multipliers.
	let MULTIPLIER = {
		COMMENT: 0, // Note: Scope indentation overrides default.
		COMMAND: 0,
		FLAG: 1,
		OPTION: 2,
		BRACE: 0, // Note: Scope indentation overrides default.
		NEWLINE: 0,
		SETTING: 0,
		VARIABLE: 0
	};

	let newline_counter = 0; // Keep track on consecutive newlines.
	let scopes = []; // Keep track of command/flag scopes.

	const [indent_char, indent_amount] = fmt; // Get formatting info.
	let indent = (type, count) => {
		return indent_char.repeat((count || MULTIPLIER[type]) * indent_amount);
	};

	// Filter out comment nodes if strip comments flag is provided.
	if (igc) nodes = nodes.filter(NODE => !(NODE.node !== "COMMENT"));

	// Loop over nodes to build formatted .acdef contents file.
	nodes.forEach((NODE, i, nodes) => {
		let type = NODE.node; // Get the node type.

		switch (type) {
			case "COMMENT":
				{
					let scope = scopes[scopes.length - 1] || null;
					let indentation = indent(null, scope);

					output += `${indentation}${NODE.comment.value}`;
				}

				break;

			case "COMMAND":
				{
					let vvalue = NODE.value.value;
					let cvalue = NODE.command.value;
					let dvalue = NODE.delimiter.value || "";
					let avalue = NODE.assignment.value || "";

					output += `${cvalue}${dvalue} ${avalue} ${vvalue || ""}`;

					if (vvalue && vvalue === "[") scopes.push(1); // Save scope.
				}

				break;

			case "FLAG":
				{
					let kvalue = NODE.keyword.value;
					let hvalue = NODE.hyphens.value || "";
					let nvalue = NODE.name.value || "";
					let bvalue = NODE.boolean.value || "";
					let avalue = NODE.assignment.value || "";
					let mvalue = NODE.multi.value || "";
					let vvalue = NODE.value.value || "";
					let singletonflag = NODE.singletonflag;
					let indentation = indent(null, singletonflag ? 1 : null);

					let pipe_delimiter = singletonflag ? "" : "|";

					// Note: If next node is a flag reset var.
					if (pipe_delimiter) {
						let nNODE = nodes[i + 1]; // The next node.
						if (nNODE && nNODE.node !== "FLAG") pipe_delimiter = "";
					}

					output += // [https://stackoverflow.com/a/23867090]
						indentation +
						(kvalue ? kvalue + " " : "") +
						hvalue +
						nvalue +
						bvalue +
						avalue +
						mvalue +
						vvalue +
						pipe_delimiter;

					if (vvalue && vvalue === "(") scopes.push(2); // Save scope.
				}

				break;

			case "OPTION":
				{
					let bvalue = NODE.bullet.value;
					let vvalue = NODE.value.value;
					let indentation = indent("OPTION");

					output += `${indentation}${bvalue} ${vvalue}`;
				}

				break;

			case "BRACE":
				{
					let bvalue = NODE.brace.value;
					let indentation = indent(null, bvalue === "]" ? 0 : 1);

					output += `${indentation}${bvalue}`;

					scopes.pop(); // Remove last scope.
				}

				break;

			case "NEWLINE":
				{
					let nNODE = nodes[i + 1]; // The next node.

					if (newline_counter <= 1) output += "\n";
					newline_counter++;

					if (nNODE && nNODE.node !== "NEWLINE") newline_counter = 0;
				}

				break;

			case "SETTING":
				{
					let nvalue = NODE.name.value;
					let avalue = NODE.assignment.value;
					let vvalue = NODE.value.value;

					output += `@${nvalue} ${avalue} ${vvalue}`;
				}

				break;

			case "VARIABLE":
				{
					let nvalue = NODE.name.value;
					let avalue = NODE.assignment.value;
					let vvalue = NODE.value.value;

					output += `$${nvalue} ${avalue} ${vvalue}`;
				}

				break;
		}
	});

	// Final newline replacements.
	output =
		output
			.replace(/(\[|\()$\n{2}/gm, "$1\n")
			.replace(/\n{2}([ \t]*)(\]|\))$/gm, "\n$1$2")
			.replace(/^\s*|\s*$/g, "")
			.replace(/ *$/gm, "") + "\n"; // Add trailing newline.

	return { content: output, print: output };
};

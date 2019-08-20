"use strict";

/**
 * Format (prettify) provided .addef file.
 *
 * @param  {object} STATE - Main loop state object.
 * @return {string} - The prettied file contents.
 */
module.exports = STATE => {
	// Vars.
	let TREE = STATE.DB.tree;
	let nodes = TREE.nodes;
	let output = "";

	// Indentation level multiplier lookup table.
	let indentations = {
		COMMENT: 0, // Note: Scope indentation overrides default.
		COMMAND: 0,
		FLAG: 1,
		OPTION: 2,
		BRACE: 0, // Note: Scope indentation overrides default.
		NEWLINE: 0,
		SETTING: 0,
		VARIABLE: 0
	};

	// Keep track on consecutive newlines.
	let newline_counter = 0;
	// Keep track of command/flag scopes.
	let scopes = [];

	// Get formatting information.
	let [indent_char, indent_amount] = STATE.args.formatting;
	let indent = (type, count) => {
		return indent_char.repeat(
			(count || indentations[type]) * indent_amount
		);
	};

	// Filter out comment nodes if strip comments flag is provided.
	if (STATE.args.stripcomments) {
		nodes = nodes.filter(NODE => {
			if (NODE.node !== "COMMENT") {
				return true;
			}
		});
	}

	// Loop over all nodes to build formatted .acdef contents file.
	nodes.forEach((NODE, i, nodes) => {
		let type = NODE.node; // Get the node type.

		switch (type) {
			case "COMMENT":
				output += `${indent(null, scopes[scopes.length - 1] || null)}${
					NODE.comment.value
				}`;

				break;
			case "COMMAND":
				output += `${NODE.command.value} ${NODE.assignment.value ||
					""} ${NODE.value.value || ""}`;

				if (NODE.value.value && NODE.value.value === "[") {
					scopes.push(1);
				}

				break;
			case "FLAG":
				let pipe_delimiter = "";

				pipe_delimiter = NODE.singletonflag ? "" : "|";
				let indentation = indent(null, NODE.singletonflag ? 1 : null);

				if (pipe_delimiter) {
					let nNODE = nodes[i + 1];
					// Next node must also be a flag else reset it.
					if (nNODE && nNODE.node !== "FLAG") {
						pipe_delimiter = "";
					}
				}

				output += `${indentation}${NODE.hyphens.value}${
					NODE.name.value
				}${NODE.boolean.value || ""}${NODE.assignment.value || ""}${NODE
					.multi.value || ""}${NODE.value.value ||
					""}${pipe_delimiter}`;

				if (NODE.value.value && NODE.value.value === "(") {
					scopes.push(2);
				}

				break;
			case "OPTION":
				output += `${indent("OPTION")}${NODE.bullet.value} ${
					NODE.value.value
				}`;

				break;
			case "BRACE":
				let brace = NODE.brace.value;

				output += `${indent(null, brace === "]" ? 0 : 1)}${
					NODE.brace.value
				}`;

				scopes.pop();

				break;
			case "NEWLINE":
				let nNODE = nodes[i + 1];

				if (newline_counter <= 1) {
					output += "\n";
				}
				newline_counter++;

				if (nNODE && nNODE.node !== "NEWLINE") {
					newline_counter = 0;
				}

				break;
			case "SETTING":
				output += `@${NODE.name.value} ${NODE.assignment.value} ${NODE.value.value}`;

				break;
			case "VARIABLE":
				output += `\$${NODE.name.value} ${NODE.assignment.value} ${NODE.value.value}`;

				break;
		}
	});

	// Final, newline replacements.
	output = output
		.replace(/(\[|\()$\n{2}/gm, "$1\n")
		.replace(/\n{2}([ \t]*)(\]|\))$/gm, "\n$1$2")
		.replace(/^\s*|\s*$/g, "");

	return { content: output, print: output };
};

"use strict";

module.exports = (STATE, commandname) => {
	let TREE = STATE.DB.tree;
	let output = "";

	let indentations = {
		COMMENT: 0, // Scoped: Scope indentation overrides. default
		COMMAND: 0,
		FLAG: 1,
		OPTION: 2,
		BRACE: 0, // Note: Scope indentation overrides. default
		NEWLINE: 0,
		SETTING: 0,
		VARIABLE: 0
		// TEMPLATE: 0
	};

	let nls = 0;
	let scopes = [];
	let indent = (type, count) => {
		return "\t".repeat(count || indentations[type]);
	};

	TREE.nodes.forEach((NODE, i, nodes) => {
		let type = NODE.node;

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

				if (nls <= 1) {
					output += "\n";
				}
				nls++;

				if (nNODE && nNODE.node !== "NEWLINE") {
					nls = 0;
				}

				break;
			case "SETTING":
				output += `@${NODE.name.value} ${NODE.assignment.value} ${NODE.value.value}`;

				break;
			case "VARIABLE":
				output += `\$${NODE.name.value} ${NODE.assignment.value} ${NODE.value.value}`;

				break;
			// case "TEMPLATE":
			// 	break;
		}
	});

	// Final, newline replacements.
	output = output
		.replace(/(\[|\()$\n{2}/gm, "$1\n")
		.replace(/\n{2}([ \t]*)(\]|\))$/gm, "\n$1$2")
		.replace(/^\s*|\s*$/g, "");

	return { content: output };
};

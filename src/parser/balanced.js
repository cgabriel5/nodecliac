"use strict";

// Needed modules.
const chalk = require("chalk");
const { exit } = require("../utils.js");

/**
 * Checks whether braces are balanced.
 *
 * @param  {string} string - The string to check.
 * @return {boolean} - True means balanced.
 *
 * @resource [https://codereview.stackexchange.com/a/46039]
 */
module.exports = string => {
	// Vars.
	let braces = "[]{}()";
	let stack = [];
	let brindex;

	/**
	 * Determine the line information (line and character) of where
	 *     the brace imbalance was found.
	 *
	 * @param  {number} index - The index of the imbalanced brace.
	 * @return {boolean|undefined} - Boolean (true) for when braces
	 *     are balanced. Otherwise, exit script and print imbalanced
	 *     brace error message.
	 */
	let lineinfo = index => {
		// Get the line/char information.
		let lines = string.substring(0, index + 1).split(/\r?\n/);

		// Return the line and character line information.
		return {
			line: lines.length,
			char: lines.pop().indexOf(string.charAt(index))
		};
	};

	// Loop over content.
	for (let i = 0, l = string.length; i < l; i++) {
		// Get index of current char. If index is not '-1'
		// then we have a brace character.
		brindex = braces.indexOf(string.charAt(i));

		// Skip loop iteration if not a brace character.
		if (!-~brindex) {
			continue;
		}

		// If brace is even get its closing brace.
		if (!(brindex % 2)) {
			// Store expected closing brace index to later
			// check against.
			stack.push({ brindex: brindex + 1, i });
		} else {
			// if (stack.pop().brindex !== brindex) {

			// If stack is empty this means there were no opening
			// braces but a close brace was detected so break.
			if (!stack.length) {
				stack.push({ brindex, i, noopen: true });
				break;
			}

			// If brindex is not even then we potentially have
			// a closing brace. Therefore, compare the stacks
			// last item's value (the stored closing brace index)
			// with the current loop's iteration char index. If
			// the indices do not match then braces are unbalanced.
			if (stack[stack.length - 1].brindex !== brindex) {
				break;
			}

			// Remove last brace info object if its the correct
			// closing brace.
			stack.pop();
		}
	}

	// If stack is empty, braces are balanced.
	if (!stack.length) {
		return true;
	} else {
		// Else the script is imbalanced. Exit and print message.

		// Get the last brace object.
		let last = stack.pop();
		let { line, char } = lineinfo(last.i);
		let brindex = last.brindex;

		// No opening brace.
		if (last.noopen) {
			exit([
				`${chalk.bold("Brace:")} Unopened '${braces.charAt(
					brindex
				)}' at ${chalk.bold(`${line}:${char}.`)}`
			]);
		} else {
			// No closing brace.
			exit([
				`${chalk.bold("Brace:")} Unclosed '${braces.charAt(
					brindex - 1
				)}' at ${chalk.bold(`${line}:${char}.`)}`
			]);
		}
	}
};

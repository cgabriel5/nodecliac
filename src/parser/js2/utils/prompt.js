"use strict";

const rl = require("readline");

let prompt = function() {};

/**
 * Creates a readline interface.
 *
 * @return {undefined} - Nothing is returned.
 */
prompt.start = function() {
	const opts = { input: process.stdin, output: process.stdout };
	let readline = rl.createInterface(opts);
	prompt.instance = readline;
	return readline;
};

/**
 * A simple prompt interface.
 *
 * @param  {string} question - The question to ask.
 * @param  {string} def - Default reply if reply is empty.
 * @return {promise} - A promise is returned.
 *
 * @return {resource} [https://attacomsian.com/blog/nodejs-read-input-from-cli]
 * @return {resource} [https://www.codecademy.com/articles/getting-user-input-in-node-js]
 * @return {resource} [https://nodejs.org/en/knowledge/command-line/how-to-prompt-for-command-line-input/]
 */
prompt.input = function(question, def) {
	return new Promise(function(resolve, reject) {
		// console.log(this, prompt, 111111, prompt.instance);
		prompt.instance.question(question, (reply) => resolve(reply || def));
	});
};

/**
 * Call to close prompt once questions are asked.
 *
 * @return {undefined} - Nothing is returned.
 */
prompt.close = function() { prompt.instance.close(); };
// Close event handler.
// readline.on("close", function() { process.exit(0); });

module.exports = prompt;

"use strict";

const log = require("fancy-log");

/**
 * Logs messages then exits script.
 *
 * @param  {array} message - List of messages to log.
 * @return {undefined} - Nothing.
 */
let exit = (messages, stop, normal_log) => {
	for (let i = 0, l = messages.length; i < l; i++) {
		let message = messages[i];
		if (normal_log) console.log(message);
		else log(message);
	}

	if (stop === undefined) process.exit();
};
// Use console.log over fancy-log.
exit.normal = (messages, stop) => {
	exit(messages, stop, true);
};

module.exports = {
	exit
};

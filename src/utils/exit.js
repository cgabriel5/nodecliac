"use strict";

const log = require("fancy-log");

/**
 * Logs messages and exit if needed.
 *
 * @param  {array} message - List of messages to log.
 * @return {undefined} - Nothing is returned.
 */
let exit = (messages, stop, normal_log) => {
	for (let i = 0, l = messages.length; i < l; i++) {
		let message = messages[i];
		if (normal_log) console.log(message);
		else log(message);
	}

	if (stop === undefined) process.exit();
};

/**
 * Use regular console.log over fancy-log to print messages.
 *
 * @param  {array} message - List of messages to log.
 * @return {undefined} - Nothing is returned.
 */
exit.normal = (messages, stop) => {
	exit(messages, stop, true);
};

module.exports = {
	exit
};

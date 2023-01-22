"use strict";

/**
 * Logs messages and exits if needed.
 *
 * @param  {array} list - List of messages to log.
 * @param  {boolean} stop - exit after printing?
 * @return {undefined} - Nothing is returned.
 */
let exit = (list, stop) => {
	for (let i = 0, l = list.length; i < l; i++) console.log(list[i]);
	if (stop === undefined) process.exit();
};

module.exports = { exit };

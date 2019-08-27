"use strict";

/**
 * Rollback index by 1 so parser starts on assignment case on next
 *     iteration.
 *
 * @param  {object} STATE - Main loop state object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = STATE => {
	STATE.i--;
	STATE.column--;
};

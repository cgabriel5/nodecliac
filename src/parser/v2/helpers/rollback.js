"use strict";

/**
 * Rollback loop index so parser re-starts same iteration.
 *
 * @param  {object} STATE - Main loop state object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = STATE => {
	STATE.i--;
	STATE.column--;
};

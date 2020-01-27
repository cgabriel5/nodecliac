"use strict";

/**
 * Rollback loop index so parser re-starts same iteration.
 *
 * @param  {object} S - Main loop state object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	S.i--;
	S.column--;
};

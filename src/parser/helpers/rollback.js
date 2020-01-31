"use strict";

/**
 * Rollback loop index/column to re-run parser at same iteration.
 *
 * @param  {object} S - State object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = S => {
	S.i--;
	S.column--;
};

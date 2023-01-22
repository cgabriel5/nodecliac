"use strict";

/**
 * Concat values from N sets into a main set.
 *
 * @param  {set} set - The main set iterable.
 * @param  {...set} iterables - N amount of sets.
 * @return {set} - The main set with other merged set values.
 *
 * @resource [https://stackoverflow.com/a/41328397]
 */
let concat = function (set, ...iterables) {
	for (let iterable of iterables) {
		for (let item of iterable) {
			set.add(item);
		}
	}
};

module.exports = {
	concat
};

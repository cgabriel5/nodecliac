"use strict";

/**
 * Adds node object to node tree.
 *
 * @param  {object} S - Main loop state object.
 * @param  {object} N - The node object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, N) => S.tables.tree.nodes.push(N);

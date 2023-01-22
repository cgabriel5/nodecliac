"use strict";

/**
 * Add node object to tree.
 *
 * @param  {object} S - State object.
 * @param  {object} N - Node object.
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, N) => S.tables.tree.nodes.push(N);

"use strict";

/**
 * Adds NODE object to node tree.
 *
 * @param  {object} S - Main loop state object.
 * @param  {object} NODE - Object containing parsed information (node).
 * @return {undefined} - Nothing is returned.
 */
module.exports = (S, NODE) => S.tables.tree.nodes.push(NODE);

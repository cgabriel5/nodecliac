"use strict";

/**
 * Adds NODE object to node tree.
 *
 * @param  {object} STATE - Main loop state object.
 * @param  {object} NODE - Object containing parsed information (node).
 * @return {undefined} - Nothing is returned.
 */
module.exports = (STATE, NODE) => STATE.tables.tree.nodes.push(NODE);

"use strict";

/**
 * Wrapper for `Object.prototype.hasOwnProperty.call`.
 *
 * @param  {object} obj - Object to check.
 * @param  {string|number} prop - Property name to check.
 * @return {boolean} - True if it's object's property. False otherwise.
 */
let hasProp = (...args) => Object.prototype.hasOwnProperty.call(...args);

module.exports = { hasProp };

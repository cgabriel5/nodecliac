"use strict";

/**
 * Wrapper for `Object.prototype.hasOwnProperty.call` method call.
 *
 * @param  {object} obj - The object to check.
 * @param  {string|number} prop - The property name to check.
 * @return {boolean} - True if it's object's property. False otherwise.
 */
let hasOwnProperty = (...args) => Object.prototype.hasOwnProperty.call(...args);

module.exports = { hasOwnProperty };

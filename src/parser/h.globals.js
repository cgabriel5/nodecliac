"use strict";

// Keep track of object size.
let count = 0;
// Store reference to object.
let ref;

// Attach to global namespace if not already.
if (!global.hasOwnProperty("$app")) {
	global.$app = {
		vars: {}
	};

	// Store reference.
	ref = global.$app.vars;
}

// Make noop function to attach methods to.
let f = () => {};

// Methods.

/**
 * Set a global key: value pair.
 *
 * @param  {string} name - The global name.
 * @param  {any} value - The global value.
 * @return {any} - Return provided value.
 */
f.set = (name, value) => {
	ref[name] = value;

	// Increment count.
	count++;

	// Return value.
	return value;
};

/**
 * Get a global key's value.
 *
 * @param  {string} name - The global name.
 * @param  {any} def - A default value in case global does not exist.
 * @return {any} - The global's value.
 */
f.get = (name, def) => {
	// Get value.
	let value = ref[name];

	// If value is not undefined return it. This way it falsy values
	// are properly returned.
	return value !== undefined ? value : def;
};

/**
 * Check if global is set.
 *
 * @param  {string} name - The global name.
 * @return {boolean} - True if global is set.
 */
f.has = name => {
	return ref[name] ? true : false;
};

/**
 * Unset a global.
 *
 * @param  {string} name - The global name.
 * @return {undefined} - Nothing is returned.
 */
f.unset = name => {
	if (ref.hasOwnProperty(name)) {
		// Remove from object
		delete ref[name];

		// Decrease count.
		count--;
	}
};

/**
 * Return amount of globals set.
 *
 * @return {number} - Global count.
 */
f.size = () => {
	return count;
};

// Add app name.
f.set("__name", "nodecliac");

// Attach directly to object to access without importing file.
global.$app.set = f.set;
global.$app.get = f.get;
global.$app.has = f.has;
global.$app.unset = f.unset;
global.$app.size = f.size;

// Export methods to have available when importing file.
module.exports = {
	set: f.set,
	get: f.get,
	has: f.has,
	unset: f.unset,
	size: f.size,
	self: ref
};

"use strict";

// Import simple eslint config.
const config = require("eslint-config-simple");

// Customize config.
config.settings = {
	react: {
		version: "16.6.3"
	}
};

// Export config.
module.exports = config;

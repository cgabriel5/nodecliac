"use strict";

// 'make' and 'format' functions share logic so call make action.
module.exports = async (args) => require("./make.js")(args);

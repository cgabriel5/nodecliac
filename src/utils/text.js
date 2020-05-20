"use strict";

/**
 * Remove all comments from Bash/Perl files.
 *
 * @param  {string} contents - The file contents.
 * @return {string} - The file contents with comments removed.
 */
let strip_comments = (contents) => {
	return (
		contents
			// Inject acmap.
			// .replace(/# \[\[__acmap__\]\]/, acmap)
			// Remove comments/empty lines but leave sha-bang comment.
			.replace(/^\s*#(?!!).*?$/gm, "")
			.replace(/\s{1,}#\s{1,}.+$/gm, "")
			// .replace(/(^\s*#.*?$|\s{1,}#\s{1,}.*$)/gm, "")
			.replace(/(\r\n\t|\n|\r\t){1,}/gm, "\n")
			.trim()
	);
};

module.exports = {
	strip_comments
};

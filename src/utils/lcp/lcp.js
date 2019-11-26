"use strict";

/**
 * Finds all common prefixes in a list of strings.
 *
 * @param  {array} strs - The list of strings.
 * @return {array} - The found/collected prefixes.
 *
 * @resource [https://www.perlmonks.org/?node_id=274114]
 * @resource [https://stackoverflow.com/q/6634480]
 * @resource [https://stackoverflow.com/a/6634498]
 * @resource [https://stackoverflow.com/a/35588015]
 * @resource [https://stackoverflow.com/a/35838357]
 * @resource [https://stackoverflow.com/a/1917041]
 * @resource [https://davidwells.io/snippets/traverse-object-unknown-size-javascript]
 * @resource [https://jonlabelle.com/snippets/view/javascript/calculate-mean-median-mode-and-range-in-javascript]
 * @resource* [https://softwareengineering.stackexchange.com/q/262242]
 * @resource* [https://stackoverflow.com/q/11397137]
 *
 */
let lcp = (strs, options = {}) => {
	// Vars.
	let l = strs.length;
	// let dict = {}; // Root object/dictionary/table.
	let frqz = {}; // Frequency of prefixes.
	let indices = {}; // Track indices of strings containing any found prefixes.
	let aindices = {}; // Track indices order.
	// let prefixes = []; // Final collection of found prefixes.

	// Final result tuple and its sequence values.
	let prxs = [];
	let xids = {};
	let r = { prefixes: prxs, indices: xids };

	// Options/defaults.
	let {
		charloop_startindex = 0, // Index where char loop will start at.
		min_frqz_prefix_len = 1, // Min length string should be to store frqz.
		min_prefix_len = 1, // Min length prefixes should be.
		min_frqz_count = 2, // Min frqz required to be considered a prefix.
		min_src_list_size = 0, // Min size source array must be to proceed.
		char_break_points = [], // Hitting these chars will break the inner loop.
		prepend: fprefix = "", // Prefix to prepend to final prefix.
		append: fsuffix = "" // Suffix to append to final prefix.
	} = options;

	/**
	 * Prepend/append provided prefix/suffix to string.
	 *
	 * @param  {string} s - The string to modidy.
	 * @return {string} - The string with prepended/appended strings.
	 *
	 */
	let decorate = s => `${fprefix}${s}${fsuffix}`;

	// If char breakpoints are provided turn into a lookup table.
	let char_bps = {};
	for (let i = 0, l = char_break_points.length; i < l; i++) {
		char_bps[char_break_points[i]] = true;
	}

	// If source array is not the min size then short-circuit.
	if (l < min_src_list_size) return r;

	// If array size is <= 2 strings use one of the following short-circuit methods.
	if (l <= 2) {
		/**
		 * Quick loop to get string from provided startpoint and end at
		 *     any provided character breakpoints.
		 *
		 * @param  {string} s - The string to loop.
		 * @return {string} - The resulting string from any trimming/clipping.
		 *
		 */
		let stringloop = s => {
			let prefix = "";
			for (let i = charloop_startindex, l = s.length; i < l; i++) {
				let char = s[i]; // Cache current loop item.
				if (char_bps[char]) break; // Stop loop if breakpoint char is hit.
				prefix += char; // Gradually build prefix.
			}
			return decorate(prefix);
		};

		switch (l) {
			case 0: // If source array is empty return empty array.
				return r;
			case 1: // If only a single string is in array return that string.
				// If only a single string is in array return that string.
				xids[0] = false; // Add string index to table.
				r.prefixes.push(stringloop(strs[0]));
				return r;
			case 2: {
				// If 2 strings exists...
				// If strings match then return string...
				if (strs[0] === strs[1]) {
					xids[0] = false; // Add string indices to table.
					xids[1] = true; // Add string indices to table.
					r.prefixes.push(stringloop(strs[0]));
					return r;
				}

				// Else use start/end-point method: [https://stackoverflow.com/a/35838357]
				// to get the prefix between the two strings.
				// Sort: [https://stackoverflow.com/a/10630852]
				// Sorting explained: [https://stackoverflow.com/a/6568100]
				// [https://stackoverflow.com/a/9175783]
				strs.sort((a, b) => b.length - a.length); // Sort strings by length.
				let first = strs[0];
				let last = strs[1];
				let ep = charloop_startindex; // Index endpoint.
				// Get common prefix between first and last completion items.
				while (first[ep] === last[ep]) ep++;
				// Add common prefix to prefixes array.
				let prefix = first.substring(0, ep);

				// Add string indices to table.
				if (prefix) {
					let isfirst_prefixed = first.startsWith(prefix);
					xids[0] = !isfirst_prefixed;
					xids[1] = isfirst_prefixed;
					r.prefixes.push(stringloop(prefix));
				}
				return r;
			}
		}
	}

	// Loop over each completion string...
	for (let i = 0; i < l; i++) {
		let str = strs[i]; // Cache current loop item.
		// let cnode; // Always reference current trie node.
		let prefix = ""; // Gradually build prefix.

		// Loop over each character in string...
		for (let j = charloop_startindex, l = str.length; j < l; j++) {
			let char = str[j]; // Cache current loop item.
			prefix += char; // Gradually build prefix each char iteration.

			if (char_bps[char]) break; // Stop loop id breakpoint char is hit.

			// Prefix must be specific length to account for frequency.
			if (prefix.length >= min_frqz_prefix_len) {
				// If prefix not found in table add to table.
				if (!frqz[prefix]) frqz[prefix] = 0;
				frqz[prefix]++; // Increment frequency.

				// Track prefix's string index to later filter out items from array.
				if (!indices[prefix]) indices[prefix] = {};
				indices[prefix][i] = true; // Add index to table

				// Track prefix's string index to later filter out items from array.
				if (!aindices[prefix]) aindices[prefix] = [];
				aindices[prefix].push(i);
			}

			// // Add initial trie node for first character of string.
			// // Note: This can change depending if an offset was provided.
			// if (j === charloop_startindex) {
			// 	if (!dict[char]) {
			// 		cnode = {};
			// 		dict[char] = cnode;

			// 		// If node for the single char exists, just point to it.
			// 	} else cnode = dict[char];

			// 	// After the first character node is stored in trie the prefix
			// 	// begins to take form and this prefix will get added as a
			// 	// child node of the initial single characters parent node.
			// 	// This will continue until all characters in the string have
			// 	// been iterated over.
			// } else {
			// 	if (!cnode[prefix]) {
			// 		let pnode = cnode;
			// 		cnode = {};
			// 		pnode[prefix] = cnode;

			// 		// If node for the prefix exists, just point to it.
			// 	} else cnode = cnode[prefix];
			// }
		}
	}

	let aprefixes = []; // Contain prefixes in array to later check prefix-of-prefixes.
	let tprefixes = {}; // Contain prefixes in table for later quick lookups.

	// Loop over each prefix in the frequency table...
	loop1: for (let str in frqz) {
		if (Object.prototype.hasOwnProperty.call(frqz, str)) {
			let count = frqz[str]; // Get string frequency.

			// If prefix doesn't exist in table and its frequency is >= 2 continue...
			if (!tprefixes[str] && count >= 2) {
				let prevkey = str.slice(0, -1); // Remove (str - last char) if it exists.
				// The previous prefix frequency, else 0 if not existent.
				let prevcount = tprefixes[prevkey] ? tprefixes[prevkey] : 0;

				// If last entry has a greater count skip this iteration.
				if (prevcount > count) continue;

				// If any string in array is prefix of the current string, skip string.
				if (aprefixes.length) {
					// var has_existing_prefix = false;
					for (let i = 0, l = aprefixes.length; i < l; i++) {
						let prefix = aprefixes[i]; // Cache current loop item.

						// If array string prefixes the string, continue to main loop.
						if (
							str.startsWith(prefix) &&
							tprefixes[prefix] > count
						) {
							// has_existing_prefix = true;
							continue loop1;
						}
					}
					// if (has_existing_prefix) continue;
				}

				// When previous count exists remove the preceding prefix from array/table.
				if (prevcount) {
					aprefixes.pop();
					delete tprefixes[prevkey];
				}

				// Finally, add current string to array/table.
				aprefixes.push(str);
				tprefixes[str] = count;
			}
		}
	}

	// Filter prefixes based on prefix length and prefix frequency count.
	for (let i = 0, l = aprefixes.length; i < l; i++) {
		let prefix = aprefixes[i];
		if (
			prefix.length > min_prefix_len &&
			tprefixes[prefix] >= min_frqz_count
		) {
			let obj = indices[prefix];
			for (let key in obj) {
				if (Object.prototype.hasOwnProperty.call(obj, key)) {
					// Add indices to final table.
					// ~~: [https://stackoverflow.com/a/43056963]
					// [https://stackoverflow.com/a/14355500]
					xids[key] =
						aindices[prefix][0] === ~~key ? false : obj[key];
				}
			}
			prxs.push(decorate(prefix));
		}
	}
	return r;

	// return Object.keys(tprefixes).filter(
	// 	s => s.length > min_prefix_len && tprefixes[s] >= min_frqz_count
	// );

	// /**
	//  * Recursively loop over provided object and run provided function
	//  *     on each object, starting from the root all the way down the
	//  *     child line.
	//  *
	//  * @param  {object} obj - The object to run on.
	//  * @param  {function} fn - The function to run on each object.
	//  * @return {undefined} - Nothing is returned.
	//  *
	//  * @resource [https://gist.github.com/sphvn/dcdf9d683458f879f593]
	//  */
	// let traverse = function(obj, fn) {
	// 	for (let key in obj) {
	// 		if (!Object.prototype.hasOwnProperty.call(obj, key)) continue;

	// 		// Get child node object.
	// 		let child = obj[key];
	// 		// If child node does not exist skip iteration.
	// 		if (!child) continue;

	// 		// Run provided function the key and its child object.
	// 		fn(key, child); // fn.apply(this, [key, child]);

	// 		// If child node is an object then use recursion.
	// 		if (typeof child === "object") traverse(child, fn);
	// 	}
	// };

	// let lprefixes = []; // Store lowest prefixes
	// *
	//  * Checks whether prefix is a prefix of another collected prefix. If
	//  *     so the prefix is removed.
	//  *
	//  * @param  {string} str - The prefix to check.
	//  * @return {boolean} - True if prefix is not a prefix of a prefix.

	// let islowestprefix = function(str) {
	// 	// Vars.
	// 	let r = true; // Result variable.

	// 	for (let i = 0, l = lprefixes.length; i < l; i++) {
	// 		if (str.startsWith(lprefixes[i])) {
	// 			r = false;
	// 			break; // Stop loop if string is a prefix of a prefix.
	// 		}
	// 	}

	// 	lprefixes.push(str); // Store prefix.
	// 	return r; // Return result.
	// };

	// // Using source array, determine `mincount` to check `count` against.
	// let countmin = l === 1 ? 0 : l === 2 || l === 3 ? 2 : 3;

	// // Traverse trie object.
	// traverse(dict, function(key, value) {
	// 	// Get amount of keys in object.
	// 	let count = Object.keys(value).length;

	// 	// Prefixes must pass following conditions:
	// 	if (
	// 		key.length >= min_prefix_len &&
	// 		(count >= countmin && frqz[key] >= min_frqz_count) &&
	// 		islowestprefix(key)
	// 	) {
	// 		prefixes.push(key); // String passed so store as a prefix.
	// 	}
	// });

	// // Finally, return all collected prefixes.
	// return prefixes;
};

// Usage examples:

// eslint-disable-next-line no-redeclare
var strs = [
	"Call Mike and schedule meeting.",
	"Call Lisa",
	// "Cat",
	"Call Adam and ask for quote.",
	"Implement new class for iPhone project",
	"Implement new class for Rails controller",
	"Buy groceries"
	// "Buy groceries"
];
console.log(13, lcp(strs));

// eslint-disable-next-line no-redeclare
var strs = ["--hintUser=", "--hintUser=", "--hintUser="];
console.log(
	-1,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--app=",
	"--assertions=",
	"--boundChecks=",
	"--checks=",
	"--cincludes=",
	"--clib=",
	"--clibdir=",
	"--colors=",
	"--compileOnly=",
	"--cppCompileToNamespace=",
	"--cpu=",
	"--debugger=",
	"--debuginfo=",
	"--define=",
	"--docInternal ",
	"--docSeeSrcUrl=",
	"--dynlibOverride=",
	"--dynlibOverrideAll ",
	"--embedsrc=",
	"--errorMax=",
	"--excessiveStackTrace=",
	"--excludePath=",
	"--expandMacro=",
	"--experimental=",
	"--fieldChecks=",
	"--floatChecks=",
	"--forceBuild=",
	"--fullhelp ",
	"--gc=",
	"--genDeps=",
	"--genScript=",
	"--help ",
	"--hintCC=",
	"--hintCodeBegin=",
	"--hintCodeEnd=",
	"--hintCondTrue=",
	"--hintConf=",
	"--hintConvFromXtoItselfNotNeeded=",
	"--hintConvToBaseNotNeeded=",
	"--hintDependency=",
	"--hintExec=",
	"--hintExprAlwaysX=",
	"--hintExtendedContext=",
	"--hintGCStats=",
	"--hintGlobalVar=",
	"--hintLineTooLong=",
	"--hintLink=",
	"--hintName=",
	"--hintPath=",
	"--hintPattern=",
	"--hintPerformance=",
	"--hintProcessing=",
	"--hintQuitCalled=",
	"--hints=",
	"--hintSource=",
	"--hintStackTrace=",
	"--hintSuccess=",
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw=",
	"--hintXDeclaredButNotUsed=",
	"--hotCodeReloading=",
	"--implicitStatic=",
	"--import=",
	"--include=",
	"--incremental=",
	"--index=",
	"--infChecks=",
	"--laxStrings=",
	"--legacy=",
	"--lib=",
	"--lineDir=",
	"--lineTrace=",
	"--listCmd ",
	"--listFullPaths=",
	"--memTracker=",
	"--multimethods=",
	"--nanChecks=",
	"--newruntime ",
	"--nilChecks=",
	"--nilseqs=",
	"--NimblePath=",
	"--nimcache=",
	"--noCppExceptions ",
	"--noLinking=",
	"--noMain=",
	"--noNimblePath ",
	"--objChecks=",
	"--oldast=",
	"--oldNewlines=",
	"--opt=",
	"--os=",
	"--out=",
	"--outdir=",
	"--overflowChecks=",
	"--parallelBuild=",
	"--passC=",
	"--passL=",
	"--path=",
	"--profiler=",
	"--project ",
	"--putenv=",
	"--rangeChecks=",
	"--refChecks=",
	"--run ",
	"--showAllMismatches=",
	"--skipCfg=",
	"--skipParentCfg=",
	"--skipProjCfg=",
	"--skipUserCfg=",
	"--stackTrace=",
	"--stdout=",
	"--styleCheck=",
	"--taintMode=",
	"--threadanalysis=",
	"--threads=",
	"--tlsEmulation=",
	"--trmacros=",
	"--undef=",
	"--useVersion=",
	"--verbosity=",
	"--version ",
	"--warningCannotOpenFile=",
	"--warningConfigDeprecated=",
	"--warningDeprecated=",
	"--warningEachIdentIsTuple=",
	"--warningOctalEscape=",
	"--warnings=",
	"--warningSmallLshouldNotBeUsed=",
	"--warningUser="
];
console.log(
	1,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--app=",
	"--assertions=",
	"--boundChecks=",
	"--checks=",
	"--cincludes=",
	"--clib=",
	"--clibdir=",
	"--colors="
];
console.log(
	2,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--warningCannotOpenFile",
	"--warningConfigDeprecated",
	"--warningDeprecated",
	"--warningEachIdentIsTuple",
	"--warningOctalEscape",
	"--warnings",
	"--warningSmallLshouldNotBeUsed",
	"--warningUser"
];
console.log(
	3,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--skipCfg=",
	"--skipParentCfg=",
	"--skipProjCfg=",
	"--skipUserCfg="
];
console.log(
	4,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--hintCC=",
	"--hintCodeBegin=",
	"--hintCodeEnd=",
	"--hintCondTrue=",
	"--hintConf=",
	"--hintConvFromXtoItselfNotNeeded=",
	"--hintConvToBaseNotNeeded=",
	"--hintDependency=",
	"--hintExec=",
	"--hintExprAlwaysX=",
	"--hintExtendedContext=",
	"--hintGCStats=",
	"--hintGlobalVar=",
	"--hintLineTooLong=",
	"--hintLink=",
	"--hintName=",
	"--hintPath=",
	"--hintPattern=",
	"--hintPerformance=",
	"--hintProcessing=",
	"--hintQuitCalled=",
	"--hints=",
	"--hintSource=",
	"--hintStackTrace=",
	"--hintSuccess=",
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw="
];
console.log(
	5,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--warnings=",
	"--warningCannotOpenFile=",
	"--warningXonfigDeprecated=",
	"--warningPofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofigApple=",
	"--warningCofgTest="
];
console.log(
	6,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = ["--warnings=", "--warningCannotOpenFile="];
console.log(
	7,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = ["--warnings="];
console.log(
	8,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--hintCC=",
	"--hintCodeBegin=",
	"--hintCodeEnd=",
	"--hintCondTrue=",
	"--hintConf=",
	"--hintConvFromXtoItselfNotNeeded=",
	"--hintConvToBaseNotNeeded=",
	"--hintDependency=",
	"--hintExec=",
	"--hintExprAlwaysX=",
	"--hintExtendedContext=",
	"--hintGCStats=",
	"--hintGlobalVar=",
	"--hintLineTooLong=",
	"--hintLink=",
	"--hintName=",
	"--hintPath=",
	"--hintPattern=",
	"--hintPerformance=",
	"--hintProcessing=",
	"--hintQuitCalled=",
	"--hints=",
	"--hintSource=",
	"--hintStackTrace=",
	"--hintSuccess=",
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw=",
	"--hintXDeclaredButNotUsed="
];
console.log(
	9,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = ["--hintCC="];
console.log(
	10,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = ["--hintUser=", "--hintUserRaw=", "--hintXDeclaredButNotUsed="];
console.log(
	11,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"--hintSuccessX=",
	"--hintUser=",
	"--hintUserRaw=",
	"--hintXDeclaredButNotUsed="
];
console.log(
	12,
	lcp(strs, {
		charloop_startindex: 2,
		min_frqz_prefix_len: 2,
		min_prefix_len: 3,
		min_frqz_count: 3,
		char_break_points: ["="],
		prepend: "--",
		append: "..."
	})
);

// eslint-disable-next-line no-redeclare
var strs = [
	"Call Mike and schedule meeting.",
	"Call Lisa",
	"Call Adam and ask for quote.",
	"Implement new class for iPhone project",
	"Implement new class for Rails controller",
	"Buy groceries"
];
console.log(13, lcp(strs));

console.log(14, lcp(["interspecies", "interstelar", "interstate"])); // "inters"
console.log(15, lcp(["throne", "throne"])); // "throne"
console.log(16, lcp(["throne", "dungeon"])); // ""
console.log(17, lcp(["cheese"])); // "cheese"
console.log(18, lcp([])); // ""
console.log(19, lcp(["prefix", "suffix"])); // ""

"use strict";

/**
 * Finds all common prefixes in a list of strings.
 *
 * @param  {array} strs - The list of strings.
 * @return {array} - The found/collected prefixes.
 *
 * @resource [https://stackoverflow.com/q/6634480]
 * @resource [https://stackoverflow.com/a/6634498]
 * @resource [https://stackoverflow.com/a/1917041]
 * @resource [https://softwareengineering.stackexchange.com/q/262242]
 * @resource [https://stackoverflow.com/q/11397137]
 */
let lcp = (strs, options = {}) => {
	let l = strs.length;
	let frqz = {};
	let indices = {};
	let aindices = {};
	let prxs = [];
	let xids = {};
	let r = { prefixes: prxs, indices: xids };

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
	 * Prepend/append prefix/suffix to string.
	 *
	 * @param  {string} s - String to modidy.
	 * @return {string} - Modified string.
	 *
	 */
	let decorate = s => `${fprefix}${s}${fsuffix}`;

	// If char breakpoints are provided create lookup table.
	let char_bps = {};
	for (let i = 0, l = char_break_points.length; i < l; i++) {
		char_bps[char_break_points[i]] = true;
	}

	if (l < min_src_list_size) return r;

	// Short-circuits.
	if (l <= 2) {
		/**
		 * Get string from startpoint to any character  breakpoints.
		 *
		 * @param  {string} s - String to loop.
		 * @return {string} - Resulting string from any trimming/clipping.
		 */
		let stringloop = s => {
			let prefix = "";
			for (let i = charloop_startindex, l = s.length; i < l; i++) {
				let char = s[i];
				if (char_bps[char]) break;
				prefix += char;
			}
			return decorate(prefix);
		};

		switch (l) {
			case 0: return r;
			case 1:
				xids[0] = false;
				r.prefixes.push(stringloop(strs[0]));
				return r;
			case 2: {
				if (strs[0] === strs[1]) {
					xids[0] = false;
					xids[1] = true;
					r.prefixes.push(stringloop(strs[0]));
					return r;
				}

				// [https://stackoverflow.com/a/35838357]
				strs.sort((a, b) => b.length - a.length);
				let first = strs[0];
				let last = strs[1];
				let ep = charloop_startindex; // Endpoint.
				while (first[ep] === last[ep]) ep++;
				let prefix = first.substring(0, ep);

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

	// Loop over each completion string.
	for (let i = 0; i < l; i++) {
		let str = strs[i];
		let prefix = "";

		// Loop over each char in string...
		for (let j = charloop_startindex, l = str.length; j < l; j++) {
			let char = str[j];
			prefix += char;

			if (char_bps[char]) break;

			// Store if min length satisfied.
			if (prefix.length >= min_frqz_prefix_len) {
				if (!frqz[prefix]) frqz[prefix] = 0;
				frqz[prefix]++;

				if (!indices[prefix]) indices[prefix] = {};
				indices[prefix][i] = true;

				if (!aindices[prefix]) aindices[prefix] = [];
				aindices[prefix].push(i);
			}
		}
	}

	let aprefixes = [];
	let tprefixes = {};

	// Loop over each prefix in frequency table.
	loop1: for (let str in frqz) {
		if (Object.prototype.hasOwnProperty.call(frqz, str)) {
			let count = frqz[str];

			if (!tprefixes[str] && count >= 2) {
				let prevkey = str.slice(0, -1);
				let prevcount = tprefixes[prevkey] ? tprefixes[prevkey] : 0;

				if (prevcount > count) continue;

				if (aprefixes.length) {
					for (let i = 0, l = aprefixes.length; i < l; i++) {
						let prefix = aprefixes[i];

						if (
							str.startsWith(prefix) &&
							tprefixes[prefix] > count
						) {
							continue loop1;
						}
					}
				}

				if (prevcount) {
					aprefixes.pop();
					delete tprefixes[prevkey];
				}

				aprefixes.push(str);
				tprefixes[str] = count;
			}
		}
	}

	// Filter prefixes based on length and frqz count.
	for (let i = 0, l = aprefixes.length; i < l; i++) {
		let prefix = aprefixes[i];
		if (
			prefix.length > min_prefix_len &&
			tprefixes[prefix] >= min_frqz_count
		) {
			let obj = indices[prefix];
			for (let key in obj) {
				if (Object.prototype.hasOwnProperty.call(obj, key)) {
					// ~~: [https://stackoverflow.com/a/14355500]
					xids[key] =
						aindices[prefix][0] === ~~key ? false : obj[key];
				}
			}
			prxs.push(decorate(prefix));
		}
	}
	return r;
};

// Examples:

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

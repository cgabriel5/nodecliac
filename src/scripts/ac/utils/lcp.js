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
module.exports = (strs, options = {}) => {
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
	let decorate = (s) => `${fprefix}${s}${fsuffix}`;

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
		let stringloop = (s) => {
			let prefix = "";
			for (let i = charloop_startindex, l = s.length; i < l; i++) {
				let char = s[i];
				if (char_bps[char]) break;
				prefix += char;
			}
			return decorate(prefix);
		};

		switch (l) {
			case 0:
				return r;
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

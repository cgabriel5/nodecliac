"use strict";

// Require needed modules.
const paramparse = require("./paramparse.js");

/**
 * Fill-in placeholded long-form flags with collapsed single line
 *     containing the formated flags.
 *
 * @param  {string} contents - The line with possible placeholders.
 * @return {string} - The filled line with collapsed and formatted flags.
 */
module.exports = flags => {
	// Return if provided array is empty.
	if (!flags.length) {
		return [];
	}

	// Format flags:
	let lists = {
		type1: [],
		type2: [],
		type3: {
			list: [],
			lookup: {}
		}
	};
	let t2list = lists.type2;
	let t3list = lists.type3.list;
	// let t3lkup = lists.type3.lookup;

	// Loop over flags and format.
	for (let i = 0, l = flags.length; i < l; i++) {
		// Cache current loop item.
		let flag = flags[i].trim();

		// Flag forms:
		// --flag             → type 1
		// --flag=            → type 2
		// --flag=*           → type 2
		// --flag=value       → type 3

		if (!flag.includes("=")) {
			// Flag forms:
			// --flag

			// Add flag if not already in list.
			if (!-~lists.type1.indexOf(flag)) {
				lists.type1.push(flag);
			}
		} else {
			// Flag forms:
			// --flag=, --flag=*, --flag=value

			// If in form → --flag=/--flag=*, add to list if not already.
			if (
				/^-{1,2}[a-z][-.a-z0-9]*=\*?$/i.test(flag) &&
				!-~t2list.indexOf(flag)
			) {
				if (flag.endsWith("*")) {
					// If non-asterisk form has already been added, remove
					// it from the list.
					let fflag = flag.slice(0, -1);
					if (t2list.includes(fflag)) {
						// Remove it from the list.
						t2list.splice(t2list.indexOf(fflag), 1);
					}
				} else {
					// If asterisk form has been already added don't add
					// non-asterisk flag.
					if (t2list.includes(`${flag}*`)) {
						continue;
					}
				}

				t2list.push(flag);
			} else {
				// Flag forms:
				// --flag=value

				// Split into flag (key) and value.
				let eq_index = flag.indexOf("=");
				let key = flag.substring(0, eq_index);
				let value = flag.substring(eq_index + 1);

				// Cleanup flag if it's a command-flag.
				if (/^\$\(.*?\)$/.test(value)) {
					flag = `${key}=${paramparse(value)}`;
				}

				let fkey = `${key}=`;
				// Since this key has options make sure to also add the key
				// to the type 2 flags as well if not explicitly provided.
				if (!-~t2list.indexOf(fkey) && !-~t2list.indexOf(`${fkey}*`)) {
					t2list.push(fkey);
				}

				// Add to type3 list.
				t3list.push(flag);

				//////////////////////////////////////////*
				// // If the flag has a value as an option. Join multiple
				// // flag options into a single-mega option.
				//
				// // Split into flag (key) and value.
				// let eq_index = flag.indexOf("=");
				// let key = flag.substring(0, eq_index);
				// let value = flag.substring(eq_index + 1);
				//
				// // Add flag if not already in list.
				// if (!t3lkup[key]) {
				// 	// Store value.
				// 	t3lkup[key] = [value];
				// } else {
				// 	// Else, flag is already in list. Just add the value.
				// 	t3lkup[key].push(value);
				// }
				//////////////////////////////////////////*
			}
		}
	}

	//////////////////////////////////////////*
	// // Combine all flags into a single line.
	// // Prep type3 flag types.
	// let obj = lists.type3.lookup;
	// for (let key in obj) {
	// 	if (obj.hasOwnProperty(key)) {
	// 		let fkey = `${key}=`;
	// 		// Since this key has options make sure to also add the key
	// 		// to the type 2 flags as well if not explicitly provided.
	// 		if (
	// 			!-~t2list.indexOf(fkey) &&
	// 			!-~t2list.indexOf(`${fkey}*`)
	// 		) {
	// 			t2list.push(fkey);
	// 		}
	//
	// 		let value = obj[key].join(" ");
	// 		// Add to type3 list.
	// 		t3list.push(`${key}=(${value})`);
	// 	}
	// }
	//////////////////////////////////////////*

	return lists.type1.concat(lists.type2, lists.type3.list);
};

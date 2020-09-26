"use strict";

var d = document;
var $ = (id) => d.getElementById(id);

/**
 * Determines which animation[start|end|iteration] event the user's
 *     browser supports and returns it.
 *
 * @param {string} type - The event type: either start, end, or
 *     iteration.
 * @return {string} - The browser prefixed transition event.
 *
 * @resource [https://davidwalsh.name/css-animation-callback]
 * @resource [https://github.com/cgabriel5/snippets/blob/master/js/detection/which_animation_transition_event.js]
 */
var which_transition_event = function (type) {
	// Lowercase type.
	type = type.toLowerCase();

	var $el = document.createElement("div"),
		transitions = {
			transition: "transition",
			// Opera prefix info:
			// [https://developer.mozilla.org/en-US/docs/Web/Events/transitionend]
			OTransition: "oTransition",
			otransition: "otransition",
			MozTransition: "transition",
			WebkitTransition: "webkitTransition",
			MSTransition: "MSTransition"
		};

	for (var transition in transitions) {
		if ($el.style[transition] !== undefined) {
			// Cache value.
			var value = transitions[transition];

			// Determine if suffix needs to be capitalized.
			var end = value.match(/[A-Z]/)
				? type.charAt(0).toUpperCase() + type.substring(1)
				: type;

			// Return prefixed event.
			return value + end;
		}
	}
};

/**
 * Determines which animation[start|end|iteration] event the user's
 *     browser supports and returns it.
 *
 * @param {string} type - The event type: either start, end, or
 *     iteration.
 * @return {string} - The browser prefixed transition event.
 *
 * @resource [https://davidwalsh.name/css-animation-callback]
 * @resource [https://github.com/cgabriel5/snippets/blob/master/js/detection/which_animation_transition_event.js]
 */
var which_animation_event = function (type) {
	// Lowercase type.
	type = type.toLowerCase();
	var $el = document.createElement("div"),
		animations = {
			animation: "animation",
			OAnimation: "oAnimation",
			oanimation: "oanimation",
			MozAnimation: "animation",
			WebkitAnimation: "webkitAnimation",
			MSAnimation: "MSAnimation"
		};
	for (var animation in animations) {
		if ($el.style[animation] !== undefined) {
			// Cache value.
			var value = animations[animation];

			// Determine if suffix needs to be capitalized.
			var end = value.match(/[A-Z]/)
				? type.charAt(0).toUpperCase() + type.substring(1)
				: type;

			// Return prefixed event.
			return value + end;
		}
	}
};

const init = function () {
	let API = window.api;
	let $cached_sb = null;
	let $cached_pkg = null;
	const { Interaction, Funnel } = window.app.libs;
	API.loaded("API_LOADED");

	API.setup_config = function (status, cache, debug, singletons) {
		/**
		 * Select/unselect settings action buttons.
		 *
		 * @param  {...[string]} names - The button action names.
		 * @return {undefined} - Nothing is returned.
		 */
		const action = (...names) => {
			for (let i = 0, l = names.length; i < l; i++) {
				let name = names[i];
				let select = !name.startsWith("!");
				if (!select) name = name.slice(1);
				let $e = $(`setting-action-btn-${name}`);
				let prefix = select ? "" : "un";
				let method = select ? "remove" : "add";
				let classes = $e.classList;
				classes.remove("noselect", "setting-action-btn-unselected");
				classes.add(`setting-action-btn-${prefix}selected`);
				$e.children[0].classList[method]("none");
			}
		};

		$("switch-status").checked = !!status;
		$("switch-single-flag-comp").checked = !!singletons;

		if (cache) {
			$("switch-cache").checked = true;
			if (cache === 1) action("dynamic", "!all");
			else if (cache === 2) action("!dynamic", "all");
		} else {
			$("switch-cache").checked = false;
			action("!dynamic", "!all");
		}

		if (debug) {
			$("switch-debug").checked = true;
			if (cache === 2) action("nim", "!perl");
			else if (cache === 3) action("!nim", "perl");
		} else {
			$("switch-debug").checked = false;
			action("!nim", "!perl");
		}
	};

	Interaction.addHandler("mousedown:main", function (e, targets, filter) {
		if (e.which !== 1) return; // Only left button mousedowns.

		switch (filter) {
			case "row:pkg":
				{
					if ($cached_pkg) {
						$cached_pkg.classList.remove("pkg-entry-selected");

						// prettier-ignore
						let ids = ["name", "description", "author", "repository", "version", "location"];
						// prettier-ignore
						ids.forEach((id) => {$("pkg-info-row-" + id).children[1].textContent = "--";});
					}
					let delegate = targets.delegateTarget;
					if ($cached_pkg === delegate) {
						$cached_pkg = null;
						return;
					}
					if (delegate) {
						delegate.classList.toggle("pkg-entry-selected");
						$cached_pkg = delegate;
						API.get_pkg_info(delegate.id.slice(10));
					}
				}

				break;
			case "row:sb":
				{
					let delegate = targets.delegateTarget;
					if ($cached_sb === delegate) return;
					if ($cached_sb) {
						// $cached_sb.classList.toggle("none");
						$cached_sb.classList.remove("sb-row-selected");
						const dattr = $cached_sb.getAttribute("data-row");
						const pname = dattr + "-cont";
						const node = $(pname);
						if (node) node.classList.add("none");
					}
					if (delegate) {
						document
							.querySelector(".packages-cont")
							.classList.add("none");
						delegate.classList.toggle("sb-row-selected");
						const dattr = delegate.getAttribute("data-row");
						const pname = dattr + "-cont";
						const node = $(pname);
						if (node) node.classList.remove("none");
						$cached_sb = delegate;

						if (dattr === "packages") API.packages();
						else if (dattr === "settings") API.config();
					}
				}

				break;

			case "row:pkg-select-toggle":
				{
					let delegate = targets.delegateTarget;
					let icon = delegate.children[0];
					if (icon.classList.contains("fa-square")) {
						icon.classList.remove("fa-square");
						icon.classList.add(
							"fa-check-square",
							"pkg-entry-icon-selected"
						);

						let actions_cont = $("pkg-list-header-actions");
						actions_cont.classList.remove(
							"pkg-list-header-actions-disabled"
						);

						// Select all package entries.
						let list = document.querySelectorAll(".pkg-entry-icon");
						for (let i = 0, l = list.length; i < l; i++) {
							let item = list[i];
							item.children[0].classList.remove("fa-square");
							item.children[0].classList.add(
								"fa-check-square",
								"pkg-entry-icon-selected"
							);
						}
					} else {
						icon.classList.remove(
							"fa-check-square",
							"pkg-entry-icon-selected"
						);
						icon.classList.add("fa-square");

						let actions_cont = $("pkg-list-header-actions");
						actions_cont.classList.add(
							"pkg-list-header-actions-disabled"
						);

						// Select all package entries.
						let list = document.querySelectorAll(".pkg-entry-icon");
						for (let i = 0, l = list.length; i < l; i++) {
							let item = list[i];
							item.children[0].classList.remove(
								"fa-check-square",
								"pkg-entry-icon-selected"
							);
							item.children[0].classList.add("fa-square");
						}
					}
				}

				break;

			case "row:pkg-select-toggle-entry":
				{
					// let delegate = targets.delegateTarget;

					// untoggle main toggle
					let main_toggle = $("select-all-toggle");
					var icon = main_toggle.children[0];
					icon.classList.remove(
						"fa-check-square",
						"pkg-entry-icon-selected"
					);
					icon.classList.add("fa-square");

					let delegate = targets.delegateTarget;
					var icon = delegate.children[0];
					if (icon.classList.contains("fa-square")) {
						icon.classList.remove("fa-square");
						icon.classList.add(
							"fa-check-square",
							"pkg-entry-icon-selected"
						);
					} else {
						icon.classList.remove(
							"fa-check-square",
							"pkg-entry-icon-selected"
						);
						icon.classList.add("fa-square");
					}

					if (
						document.querySelectorAll(".pkg-entry-icon-selected")
							.length
					) {
						let actions_cont = $("pkg-list-header-actions");
						actions_cont.classList.remove(
							"pkg-list-header-actions-disabled"
						);
					} else {
						let actions_cont = $("pkg-list-header-actions");
						actions_cont.classList.add(
							"pkg-list-header-actions-disabled"
						);
					}
				}

				break;

			case "action:setting":
				{
					let delegate = targets.delegateTarget;
					let id = delegate.id;
					if (id === "setting-action-btn-dynamic") {
						let e;
						e = delegate;
						// if (
						// 	!e.classList.contains("setting-action-btn-selected")
						// ) {
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-selected");
						e.children[0].classList.remove("none");
						// } else {
						// 	e.classList.remove("setting-action-btn-selected");
						// 	e.classList.add(
						// 		"setting-action-btn-unselected",
						// 		"noselect"
						// 	);
						// 	e.children[0].classList.add("none");
						// }

						e = $("setting-action-btn-all");
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-unselected");
						e.children[0].classList.add("none");
					} else if (id === "setting-action-btn-all") {
						let e;
						e = $("setting-action-btn-dynamic");
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-unselected");
						e.children[0].classList.add("none");
						e = $("setting-action-btn-all");
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-selected");
						e.children[0].classList.remove("none");
					} else if (id === "setting-action-btn-nim") {
						let e;
						e = delegate;
						// if (
						// 	!e.classList.contains("setting-action-btn-selected")
						// ) {
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-selected");
						e.children[0].classList.remove("none");
						// } else {
						// 	e.classList.remove("setting-action-btn-selected");
						// 	e.classList.add(
						// 		"setting-action-btn-unselected",
						// 		"noselect"
						// 	);
						// 	e.children[0].classList.add("none");
						// }

						e = $("setting-action-btn-perl");
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-unselected");
						e.children[0].classList.add("none");
					} else if (id === "setting-action-btn-perl") {
						let e;
						e = $("setting-action-btn-nim");
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-unselected");
						e.children[0].classList.add("none");
						e = $("setting-action-btn-perl");
						e.classList.remove(
							"noselect",
							"setting-action-btn-unselected"
						);
						e.classList.add("setting-action-btn-selected");
						e.children[0].classList.remove("none");
					} else if (id === "setting-action-btn-clear-cache") {
						API.clear_cache();
					}

					if (id.includes("dynamic") || id.includes("all")) {
						$("switch-cache").checked = true;
					} else if (id.includes("nim") || id.includes("perl")) {
						$("switch-debug").checked = true;
					}
				}

				break;

			case "switch:setting":
				{
					let delegate = targets.delegateTarget;
					let id = delegate.getAttribute("for");
					let toggle = $(id);
					let state = !toggle.checked;
					if (state) {
						let b1 = "";
						let b2 = "";
						if (id === "switch-cache") {
							b1 = "dynamic";
							b2 = "all";
						} else if (id === "switch-debug") {
							b1 = "nim";
							b2 = "perl";
						}

						if (id === "switch-status") {
							API.update_state(1);
						}

						let e;
						e = $("setting-action-btn-" + b1);
						if (!e) return;
						e.classList.remove(
							"setting-action-btn-unselected",
							"noselect"
						);
						e.classList.add("setting-action-btn-selected");
						e.children[0].classList.remove("none");
						e = $("setting-action-btn-" + b2);
						e.classList.remove("setting-action-btn-selected");
						e.classList.add(
							"setting-action-btn-unselected",
							"noselect"
						);
						e.children[0].classList.add("none");
					} else {
						let b1 = "";
						let b2 = "";
						if (id === "switch-cache") {
							b1 = "dynamic";
							b2 = "all";
						} else if (id === "switch-debug") {
							b1 = "nim";
							b2 = "perl";
						}

						if (id === "switch-status") {
							API.update_state(0);
						}

						let e;
						e = $("setting-action-btn-" + b1);
						if (!e) return;
						e.classList.remove("setting-action-btn-selected");
						e.classList.add(
							"setting-action-btn-unselected",
							"noselect"
						);
						e.children[0].classList.add("none");
						e = $("setting-action-btn-" + b2);
						e.classList.remove("setting-action-btn-selected");
						e.classList.add(
							"setting-action-btn-unselected",
							"noselect"
						);
						e.children[0].classList.add("none");
					}
				}

				break;
		}
	});
	Interaction.addFilter("row:pkg-select-toggle-entry", function (e, targets) {
		let parents = Funnel(targets.target).parents().getStack();
		return Funnel(targets.target)
			.concat(parents)
			.classes("pkg-entry-icon")
			.getElement();
	});
	Interaction.addFilter("row:pkg-select-toggle", function (e, targets) {
		let parents = Funnel(targets.target).parents().getStack();
		return Funnel(targets.target)
			.concat(parents)
			.attrs("id")
			.attrs("id=select-all-toggle")
			.getElement();
	});
	Interaction.addFilter("row:pkg", function (e, targets) {
		let parents = Funnel(targets.target).parents().getStack();
		return Funnel(targets.target)
			.concat(parents)
			.classes("pkg-entry")
			.getElement();
	});
	Interaction.addFilter("row:sb", function (e, targets) {
		let parents = Funnel(targets.target).parents().getStack();
		return Funnel(targets.target)
			.concat(parents)
			.classes("sb-row")
			.getElement();
	});

	Interaction.addFilter("action:setting", function (e, targets) {
		let parents = Funnel(targets.target).parents().getStack();
		return Funnel(targets.target)
			.concat(parents)
			.classes("setting-action-btn")
			.getElement();
	});

	Interaction.addFilter("switch:setting", function (e, targets) {
		let parents = Funnel(targets.target).parents().getStack();
		return Funnel(targets.target)
			.concat(parents)
			.classes("switch")
			.getElement();
	});

	new Interaction("Handle onChange events.")
		.on("mousedown")
		.anchors(document)
		.handler("mousedown:main")
		.filters("action:setting")
		.filters("switch:setting")
		.filters("row:pkg-select-toggle")
		.filters("row:pkg-select-toggle-entry")
		.filters("row:pkg")
		.filters("row:sb")
		.capture(false)
		.enable();

	Interaction.addFilter("input:F", function (e, targets) {
		return Funnel(targets.target).tags("input").getElement();
	});
	Interaction.addHandler("input:H", function (e, targets) {
		if (targets.delegateTarget) {
			let target = targets.delegateTarget;
			let value = target.value;
			console.log(value);
		}
	});
	var event = new Interaction("Handle onChange events.")
		.on("input")
		.anchors(document)
		.handler("input:H")
		.filters("input:F")
		.capture(false)
		.debounce(200)
		.enable();

	Interaction.addHandler("focus:H", function (e, targets) {
		if (!$("settings-cont").classList.contains("none")) {
			API.config();
		}
	});
	var event = new Interaction("Handle window focus events.")
		.on("focus")
		.anchors(window)
		.handler("focus:H")
		.debounce(100)
		// .capture(false)
		.enable();

	// Interaction.addFilter("toggle:F", function (e, targets) {
	// 	return Funnel(targets.target).tags("input").getElement();
	// });
	// Interaction.addHandler("toggle:H", function (e, targets) {
	// 	if (targets.delegateTarget) {
	// 		let target = targets.delegateTarget;
	// 		let value = target.value;
	// 		console.log(value);
	// 	}
	// });
	// var event = new Interaction("Handle onChange events.")
	// 	.on("change")
	// 	.anchors(document)
	// 	.handler("toggles:H")
	// 	.filters("toggles:F")
	// 	.capture(false)
	// 	.debounce(200)
	// 	.enable();

	// window.addEventListener("contextmenu", (event) => event.preventDefault());

	/* Sniff: [https://stackoverflow.com/a/4702584] */
	if (navigator.platform.includes("Mac")) {
		document.body.classList.add("macosx-zoom");
	}
};

// // [https://stackoverflow.com/a/61839322]
// document.onreadystatechange = function () {
// 	// if (document.readyState == "complete") setTimeout(() => init(), 250);

// 	if (document.readyState == "complete") {
// 		document.addEventListener(which_animation_event("start"), function (e) {
// 			var aname = e.animationName;
// 			var $target = e.target;

// 			if ($target.id && $target.id === "leaf") {
// 				if (aname === "animate-pulse") {
// 					$("leaf").classList.add("on");
// 					let el = $("splash-overlay");
// 					el.classList.remove("opa1");
// 					el.classList.add("opa0");
// 				}
// 			}
// 		});

// 		document.addEventListener(which_transition_event("end"), function (e) {
// 			var $target = e.target;
// 			var pname = e.propertyName;

// 			if ($target.id && $target.id === "splash-overlay") {
// 				$("splash-overlay").classList.add("none");
// 				init();
// 			}
// 		});

// 		$("leaf").classList.add("animate-pulse");
// 	}
// };

// [https://stackoverflow.com/a/61839322]
document.onreadystatechange = function () {
	// if (document.readyState == "complete") setTimeout(() => init(), 250);

	if (document.readyState == "complete") {
		document.addEventListener(which_animation_event("start"), function (e) {
			var $target = e.target;
			var aname = e.animationName;

			// console.log("WHICH_ANIMATION_START", $target.id, aname);

			if ($target.id && $target.id === "leaf") {
				if (aname === "animate-pulse") {
					// $("leaf").classList.add("on");
					let el = $("splash-overlay");
					el.classList.remove("opa1");
					el.classList.add("opa0");
				}
			}

			// if ($target.id && $target.id === "leaf") {
			// 	if (aname === "animate-pulse") {
			// 		$("leaf").classList.add("on");
			// 		let el = $("splash-overlay");
			// 		el.classList.remove("opa1");
			// 		el.classList.add("opa0");
			// 	}
			// }
		});

		document.addEventListener(which_animation_event("start"), function (e) {
			var $target = e.target;
			var aname = e.animationName;

			// console.log("WHICH_ANIMATION_END", $target.id, aname);
		});

		document.addEventListener(which_transition_event("end"), function (e) {
			var $target = e.target;
			var pname = e.propertyName;

			// console.log("WHICH_TRANSITION_END", $target.id, pname);

			if ($target.id && $target.id === "leaf") {
				if (!$target.classList.contains("on")) {
					$target.classList.add("on");
				} else {
					$target.classList.add("animate-pulse");
				}
			} else if ($target.id && $target.id === "splash-overlay") {
				$("splash-overlay").classList.add("none");
				init();
			}

			// if ($target.id && $target.id === "splash-overlay") {
			// 	$("splash-overlay").classList.add("none");
			// 	init();
			// }
		});

		$("leaf").classList.add("off");
		// $("leaf").classList.add("animate-pulse");
	}
};

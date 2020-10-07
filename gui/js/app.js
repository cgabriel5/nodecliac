"use strict";

const { Interaction, Funnel: f } = window.app.libs;
const d = document;
const $ = (...args) => {
	if (args.length === 1) return d.getElementById(args[0]);
	else {
		let mode = args[0];
		let method = "";
		args.shift();
		switch (mode) {
			case "QUERY_ALL":
				method = "querySelectorAll";
				break;
			case "QUERY":
				method = "querySelector";
				break;
			case "CLASS_NAME":
				method = "getElementsByClassName";
				break;
			case "NAME":
				method = "getElementsByName";
				break;
			case "TAG_NAME":
				method = "getElementsByTagName";
				break;
			case "TAG_NAME_NS":
				method = "getElementsByTagNameNS";
				break;
		}
		return d[method](args[0]);
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
const which_transition_event = (type) => {
	type = type.toLowerCase();

	let $el = document.createElement("div"),
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

	for (let transition in transitions) {
		if ($el.style[transition] !== undefined) {
			let value = transitions[transition];

			// Determine if suffix needs to be capitalized.
			let end = value.match(/[A-Z]/)
				? type.charAt(0).toUpperCase() + type.substring(1)
				: type;

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
const which_animation_event = (type) => {
	type = type.toLowerCase();
	let $el = document.createElement("div"),
		animations = {
			animation: "animation",
			OAnimation: "oAnimation",
			oanimation: "oanimation",
			MozAnimation: "animation",
			WebkitAnimation: "webkitAnimation",
			MSAnimation: "MSAnimation"
		};
	for (let animation in animations) {
		if ($el.style[animation] !== undefined) {
			let value = animations[animation];

			// Determine if suffix needs to be capitalized.
			let end = value.match(/[A-Z]/)
				? type.charAt(0).toUpperCase() + type.substring(1)
				: type;

			return value + end;
		}
	}
};

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
		let $el = $(`action-${name}`);
		if (!$el) continue;
		let prefix = select ? "" : "un";
		let method = select ? "remove" : "add";
		let classes = $el.classList;
		classes.remove("noselect", "unselected");
		classes.add(`${prefix}selected`);
		let cname = "icon-cont";
		f($el).all().classes(cname).getElement().classList[method]("none");
	}
};

// const get_sel_modifier = (b1, b2) => {
// 	let res = 0;
// 	let cname = "setting-action-btn-selected";

// 	if ($(`setting-action-btn-${b1}`).classList.contains(cname)) res = 1;
// 	else if ($(`setting-action-btn-${b2}`).classList.contains(cname)) res = 2;
// 	if (b1 === "nim") res++;
// 	return res;
// };

function check($el) {
	$el.classList.remove("none");
	$el.parentNode.classList.add("selected");
}
function uncheck($el) {
	$el.classList.add("none");
	$el.parentNode.classList.remove("selected");
}
const checked = ($el) => !$el.classList.contains("none");
const toggle_pkg_sel_actions = (state) => {
	let method = state ? "remove" : "add";
	let $actions_cont = $("header-actions");
	$actions_cont.classList[method]("disabled");
	// let $btns = f($actions_cont).all().classes("btn-header").getStack();
	// $btns.forEach(($btn) => $btn.classList[method]("none"));
};
const mass_toggle = (method) => {
	// prettier-ignore
	let list = f("#pkg-entries").all().classes("checkmark").getStack();
	for (let i = 0, l = list.length; i < l; i++) {
		let $icon = f(list[i]).all().classes("fa-check").getElement();
		window[method]($icon);
	}
};

if (!window.api) window.api = {};
let API = window.api;
API.reset_pkg_info = () => {
	// prettier-ignore
	let ids = ["name", "description", "author", "repository", "location", "version", "license"];
	// prettier-ignore
	for (let i = 0, l = ids.length; i < l; i++) {
		f("pkg-i-" + ids[i]).all().classes("value").getElement().textContent = "--";
	}
};
// prettier-ignore
API.set_pkg_info_row = (row, value) => {
	f("pkg-i-" + row).all().classes("value").getElement().innerHTML = value;
};

const init = () => {
	console.log(API);
	let $cached_sb = null;
	let $cached_pkg = null;
	API.loaded("API_LOADED");

	API.setup_config = (status, cache, debug, singletons) => {
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
			if (debug === 1 || debug === 2) action("nim", "!perl");
			else if (debug === 3) action("!nim", "perl");
		} else {
			$("switch-debug").checked = false;
			action("!nim", "!perl");
		}
	};

	Interaction.addHandler("mousedown:main", (e, targets, filter) => {
		if (e.which !== 1) return; // Only left button mousedowns.
		let $delegate = targets.delegateTarget;
		let id = $delegate.id;

		switch (filter) {
			case "packages:input-cont":
				{
					// If the clear icon is clicked...
					if (id === "search-icon-clear") {
						let $input = $("header-input");
						$input.value = "";
						let opts = { targets: { target: $input } };
						Interaction.trigger("search-input", opts);
					}

					$delegate.focus();
					e.preventDefault();
				}

				break;

			case "packages:entry":
				{
					if ($cached_pkg) {
						$cached_pkg.classList.remove("selected");
						API.reset_pkg_info();
					}
					if ($cached_pkg === $delegate) {
						$cached_pkg = null;
						return;
					}
					if ($delegate) {
						$delegate.classList.toggle("selected");
						$cached_pkg = $delegate;
						API.get_pkg_info(id.slice(10));
					}
				}

				break;
			case "sidebar:entry":
				{
					if ($cached_sb === $delegate) {
						$cached_sb.classList.remove("selected");
						let dattr = $cached_sb.getAttribute("data-row");
						let $node = $(dattr + "-cont");
						if ($node) $node.classList.add("none");
						$cached_sb = null;

						$("default-cont").classList.remove("none");

						return;
					}
					if ($cached_sb) {
						$cached_sb.classList.remove("selected");
						let dattr = $cached_sb.getAttribute("data-row");
						let $node = $(dattr + "-cont");
						if ($node) $node.classList.add("none");
					}

					if ($delegate) {
						let $default = $("default-cont");
						if (!$default.classList.contains("none")) {
							$default.classList.add("none");
						}

						// $("QUERY", ".packages-cont").classList.add("none");
						$delegate.classList.toggle("selected");
						let dattr = $delegate.getAttribute("data-row");
						let $node = $(dattr + "-cont");
						if ($node) $node.classList.remove("none");
						$cached_sb = $delegate;

						if (dattr === "packages") API.packages();
						else if (dattr === "settings") API.config();
						// else if (dattr === "doctor") API.doctor();
					}
				}

				break;

			// case "packages:main-checkmark":
			// 	{
			// 		// prettier-ignore
			// 		let $icon = f($delegate).all().classes("fa-check").getElement();
			// 		if (!checked($icon)) {
			// 			check($icon);
			// 			toggle_pkg_sel_actions(true);
			// 			mass_toggle("check");
			// 		} else {
			// 			uncheck($icon);
			// 			toggle_pkg_sel_actions(false);
			// 			mass_toggle("uncheck");
			// 		}
			// 	}

			// 	break;

			// case "packages:entry-checkmark":
			// 	{
			// 		// prettier-ignore
			// 		let $icon = f("#main-toggle").all().classes("fa-check").getElement();
			// 		uncheck($icon); // Untoggle main checkmark.

			// 		// prettier-ignore
			// 		let $dicon = f($delegate).all().classes("fa-check").getElement();
			// 		window[!checked($dicon) ? "check" : "uncheck"]($dicon);

			// 		// prettier-ignore
			// 		let list = f("#pkg-entries").all().classes("checkmark", "selected").getStack();
			// 		toggle_pkg_sel_actions(!!list.length);
			// 	}

			// 	break;

			// case "settings:action":
			// 	{
			// 		if (id.includes("dynamic") || id.includes("all")) {
			// 			$("switch-cache").checked = true;
			// 		} else if (id.includes("nim") || id.includes("perl")) {
			// 			$("switch-debug").checked = true;
			// 		}

			// 		switch (id) {
			// 			case "action-dynamic":
			// 				API.update_cache(1);
			// 				action("dynamic", "!all");
			// 				break;

			// 			case "action-all":
			// 				API.update_cache(2);
			// 				action("!dynamic", "all");
			// 				break;

			// 			case "action-nim":
			// 				API.update_debug(2);
			// 				action("nim", "!perl");
			// 				break;

			// 			case "action-perl":
			// 				API.update_debug(3);
			// 				action("!nim", "perl");
			// 				break;

			// 			case "action-clear-cache":
			// 				API.clear_cache();
			// 				break;
			// 		}
			// 	}

			// 	break;

			// case "settings:switch":
			// 	{
			// 		let id = $delegate.getAttribute("for");
			// 		let toggle = $(id);
			// 		let state = !toggle.checked;
			// 		let b1 = id === "switch-cache" ? "dynamic" : "nim";
			// 		let b2 = id === "switch-cache" ? "all" : "perl";

			// 		switch (id) {
			// 			case "switch-status":
			// 				API.update_state(state | 0);
			// 				break;

			// 			case "switch-cache":
			// 			case "switch-debug":
			// 				{
			// 					// let mod = get_sel_modifier(b1, b2);
			// 					// API[method](Math.max(state | 0, mod));
			// 					if (state) action(b1, `!${b2}`);
			// 					else action(`!${b1}`, `!${b2}`);
			// 					let method = "update_cache";
			// 					// prettier-ignore
			// 					if (id.includes("debug")) method = "update_debug";
			// 					API[method](state | 0);
			// 				}

			// 				break;

			// 			case "switch-single-flag-comp":
			// 				API.update_singletons(state | 0);
			// 				break;
			// 		}
			// 	}

			// 	break;

			// case "settings:reset":
			// 	{
			// 		API.reset_settings();
			// 	}

			// 	break;
		}
	});

	Interaction.addHandler("click:main", (e, targets, filter) => {
		if (e.which !== 1) return; // Only left button mousedowns.
		let $delegate = targets.delegateTarget;
		let id = $delegate.id;

		switch (filter) {
			case "packages:main-checkmark":
				{
					// prettier-ignore
					let $icon = f($delegate).all().classes("fa-check").getElement();
					if (!checked($icon)) {
						check($icon);
						toggle_pkg_sel_actions(true);
						mass_toggle("check");
					} else {
						uncheck($icon);
						toggle_pkg_sel_actions(false);
						mass_toggle("uncheck");
					}
				}

				break;

			case "packages:entry-checkmark":
				{
					// prettier-ignore
					let $icon = f("#main-toggle").all().classes("fa-check").getElement();
					uncheck($icon); // Untoggle main checkmark.

					// prettier-ignore
					let $dicon = f($delegate).all().classes("fa-check").getElement();
					window[!checked($dicon) ? "check" : "uncheck"]($dicon);

					// prettier-ignore
					let list = f("#pkg-entries").all().classes("checkmark", "selected").getStack();
					toggle_pkg_sel_actions(!!list.length);
				}

				break;

			case "settings:action":
				{
					if (id.includes("dynamic") || id.includes("all")) {
						$("switch-cache").checked = true;
					} else if (id.includes("nim") || id.includes("perl")) {
						$("switch-debug").checked = true;
					}

					switch (id) {
						case "action-dynamic":
							API.update_cache(1);
							action("dynamic", "!all");
							break;

						case "action-all":
							API.update_cache(2);
							action("!dynamic", "all");
							break;

						case "action-nim":
							API.update_debug(2);
							action("nim", "!perl");
							break;

						case "action-perl":
							API.update_debug(3);
							action("!nim", "perl");
							break;

						case "action-clear-cache":
							API.clear_cache();
							break;
					}
				}

				break;

			case "settings:switch":
				{
					let id = $delegate.getAttribute("for");
					let toggle = $(id);
					let state = !toggle.checked;
					let b1 = id === "switch-cache" ? "dynamic" : "nim";
					let b2 = id === "switch-cache" ? "all" : "perl";

					switch (id) {
						case "switch-status":
							API.update_state(state | 0);
							break;

						case "switch-cache":
						case "switch-debug":
							{
								// let mod = get_sel_modifier(b1, b2);
								// API[method](Math.max(state | 0, mod));
								if (state) action(b1, `!${b2}`);
								else action(`!${b1}`, `!${b2}`);
								let method = "update_cache";
								// prettier-ignore
								if (id.includes("debug")) method = "update_debug";
								API[method](state | 0);
							}

							break;

						case "switch-single-flag-comp":
							API.update_singletons(state | 0);
							break;
					}
				}

				break;

			case "settings:reset":
				{
					API.reset_settings();
				}

				break;

			case "doctor:actions":
				{
					let action = $delegate.getAttribute("data-action");
					if (action === "run") {
						API.doctor();
					} else if (action === "clear") {
						let $cont = $("doctor-output");
						while ($cont.firstChild) {
							$cont.removeChild($cont.lastChild);
						}
					}
				}

				break;
		}
	});

	const $sidebar = $("sidebar");
	const $entries = $("pkg-entries");
	const $pkgheader = $("header-cont");
	const $settings = $("settings-cont");
	const $doctor = $("doctor-cont");
	Interaction.addFilter("packages:main-checkmark", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f(targets.target)
			.concat($parents)
			.attrs("id")
			.attrs("id=main-toggle")
			.getElement();
		if ($pkgheader.contains($el)) return $el;
	});
	Interaction.addFilter("packages:entry-checkmark", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("checkmark").getElement();
		if ($entries.contains($el)) return $el;
	});
	Interaction.addFilter("packages:entry", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("entry").getElement();
		let $cm = f($target).concat($parents).classes("checkmark").getElement();
		if (!$cm && $entries.contains($el)) return $el;
	});
	Interaction.addFilter("sidebar:entry", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("row").getElement();
		if ($sidebar.contains($el)) return $el;
	});
	Interaction.addFilter("settings:action", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target)
			.concat($parents)
			.classes("btn-action")
			.getElement();
		if ($settings.contains($el)) return $el;
	});
	Interaction.addFilter("settings:switch", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("switch").getElement();
		if ($settings.contains($el)) return $el;
	});
	Interaction.addFilter("settings:reset", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("reset").getElement();
		if ($settings.contains($el)) return $el;
	});

	Interaction.addFilter("doctor:actions", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("btn").getElement();
		if ($doctor.contains($el)) return $el;
	});

	Interaction.addFilter("packages:input-cont", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		// prettier-ignore
		let $el = f($target).concat($parents).classes("input-cont").getElement();
		// prettier-ignore
		let $clear = f($target).concat($parents).classes("search-icon-clear").getElement();
		// prettier-ignore
		let $input = f($target).concat($parents).classes("header-input").getElement();
		return $clear || (!$input && $el ? $("header-input") : undefined);
	});

	new Interaction()
		.on("mousedown")
		.anchors(document)
		.handler("mousedown:main")
		// .filters("settings:action")
		// .filters("settings:switch")
		// .filters("settings:reset")
		// .filters("packages:main-checkmark")
		// .filters("packages:entry-checkmark")
		.filters("packages:entry")
		.filters("packages:input-cont")
		.filters("sidebar:entry")
		.capture(false)
		.enable();

	new Interaction()
		.on("click")
		.anchors(document)
		.handler("click:main")
		.filters("settings:action")
		.filters("settings:switch")
		.filters("settings:reset")
		.filters("packages:main-checkmark")
		.filters("packages:entry-checkmark")
		.filters("doctor:actions")
		.capture(false)
		.enable();

	Interaction.addFilter("packages:input", (e, targets) => {
		return f(targets.target).tags("input").getElement();
	});

	let $clear = $("search-icon-clear");
	let $spinner = $("search-spinner");
	Interaction.addHandler("input:main", (e, targets) => {
		if (targets.delegateTarget) {
			let $target = targets.delegateTarget;
			let value = $target.value;

			if (value.length) $clear.classList.remove("opa0", "nointer");
			else $clear.classList.add("opa0", "nointer");

			$spinner.classList.remove("none");
			API.filter(value);
			// $spinner.classList.add("none");
		}
	});
	new Interaction()
		.id("search-input")
		.on("input")
		.anchors(document)
		.handler("input:main")
		.filters("packages:input")
		.capture(false)
		// .debounce(150)
		.enable();

	Interaction.addHandler("focus:main", (e, targets) => {
		if (!$("settings-cont").classList.contains("none")) API.config();
	});
	new Interaction()
		.on("focus")
		.anchors(window)
		.handler("focus:main")
		.debounce(100)
		.enable();

	// window.addEventListener("contextmenu", (event) => event.preventDefault());
};

// [https://stackoverflow.com/a/61839322]
d.onreadystatechange = () => {
	// if (d.readyState === "complete") setTimeout(() => init(), 250);

	/* Sniff: [https://stackoverflow.com/a/4702584] */
	if (navigator.platform.includes("Mac")) {
		d.body.classList.add("macosx-no-rubberbanding", "macosx-zoom");
	}

	if (d.readyState === "complete") {
		d.addEventListener(which_animation_event("start"), (e) => {
			let $target = e.target;
			let aname = e.animationName;
			let id = $target.id;

			if (id && id === "leaf") {
				if (aname === "animate-pulse") {
					let $el = $("splash-overlay");
					let classes = $el.classList;
					classes.remove("opa1");
					classes.add("opa0");
				}
			}
		});

		d.addEventListener(which_transition_event("end"), (e) => {
			let $target = e.target;
			let id = $target.id;
			// let pname = e.propertyName;

			if (id && id === "leaf") {
				let classes = $target.classList;
				if (!classes.contains("on")) classes.add("on");
				else classes.add("animate-pulse");
			} else if (id && id === "splash-overlay") {
				$("splash-overlay").classList.add("none");
				init();
			}
		});

		$("leaf").classList.add("off"); // Start splash animation.
	}
};

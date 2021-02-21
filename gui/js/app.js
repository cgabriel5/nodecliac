"use strict";

let $ACTIVE_PANE;
let $dummy = document.createElement("div");
let DUMMY = {
	name: "DUMMY",
	$cont: $dummy,
	$count: $dummy,
	$tb: $dummy,
	$mcheck: $dummy,
	$tb_loader: $dummy,
	$input: $dummy,
	$input_loader: $dummy,
	$clear: $dummy,
	$entries: $dummy,
	$sbentry: $dummy,
	//
	$pname: $dummy,
	$pdescription: $dummy,
	$pauthor: $dummy,
	$prepository: $dummy,
	$plocation: $dummy,
	$pversion: $dummy,
	$plicense: $dummy,
	//
	jdata: "",
	checked: [],
	checked_all: false,
	jdata_names: [],
	jdata_filtered: [],
};
let PKG_PANES_REFS = DUMMY;
let PKG_INST_REFS = {}, PKG_AVAI_REFS = {}, PKG_OUTD_REFS = {};

let get_active_panel_name = (i) => {
	if (!PKG_PANES_REFS) return "";
	return PKG_PANES_REFS.hasOwnProperty("name") ? PKG_PANES_REFS.name : "";
	// return PKG_PANES_REFS.name || "";
};
let get_panel_by_name = (name) => {
	switch (name) {
		case "packages-installed":
			return PKG_INST_REFS;
		case "packages-available":
			return PKG_AVAI_REFS;
		case "packages-outdated":
			return PKG_OUTD_REFS;
		default:
			return {};
	}
};

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
			let end = value.match(/[A-Z]/) ? type.charAt(0).toUpperCase() + type.substring(1) : type;

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
			let end = value.match(/[A-Z]/) ? type.charAt(0).toUpperCase() + type.substring(1) : type;

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
	// pkg-toolbar
	// PKG_PANES_REFS.$tb.classList[method]("disabled");
	// let $maincheck = f(PKG_PANES_REFS.$tb).all().classes("main-check").getElement();
	// $maincheck.classList[method]("disabled");

	// let $firstaction = f(PKG_PANES_REFS.$tb).all().classes("tb-action-first").getElement();
	// $firstaction.classList[method]("disabled");

	let $actions_cont = f(PKG_PANES_REFS.$tb).all().classes("tb-actions").getElement();
	$actions_cont.classList[method]("disabled");
	// let $btns = f($actions_cont).all().classes("tb-action").getStack();
	// $btns.forEach(($btn) => $btn.classList[method]("none"));
};
const toggle_pkg_sel_action_refresh = (state) => {
	let method = state ? "remove" : "add";
	let $firstaction = f(PKG_PANES_REFS.$tb).all().classes("tb-action-first").getElement();
	$firstaction.classList[method]("disabled");
};

const mass_toggle = (method) => {
	// prettier-ignore
	let list = f(PKG_PANES_REFS.$entries).all().classes("checkmark").getStack();
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

	let PANEL = get_panel_by_name(get_active_panel_name());
	// prettier-ignore
	for (let i = 0, l = ids.length; i < l; i++) {
		// f("pkg-i-" + ids[i]).all().classes("value").getElement().textContent = "--";
		// prettier-ignore
		f(PANEL["$p" + ids[i]]).all().classes("value").getElement().innerHTML = "--";
	}
};
// prettier-ignore
API.set_pkg_info_row = (panel, row, value) => {

	let PANEL = get_panel_by_name(panel);
	f(PANEL["$p" + row]).all().classes("value").getElement().innerHTML = value;
	// f("pkg-i-" + row).all().classes("value").getElement().innerHTML = value;
};

let processes = { packages: {} };
function block_panel(name = "") {
	processes.packages[name || $ACTIVE_PANE.getAttribute("data-row")] = true;
}
function unblock_panel(name) {
	processes.packages[name] = false;
}
let is_panel_blocked = (name) => processes.packages[name];

const init = async () => {
	let $cached_sb = null;
	let $cached_pkg = null;

	// let selected_pkgs = new Set();

	// Setup tippy.
	// let $btnheaders = f("#tb-actions").children().getStack();
	// tippy($btnheaders, {
	tippy("[data-tippy-content]", {
		placement: "bottom",
		delay: 100,
		duration: 0,
		// arrow: false,
		// theme: "light",
		offset: [0, 0]
	});

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
			// case "packages:input-cont":
			// 	{
			// 		// If the clear icon is clicked...
			// 		if ($delegate.classList.contains("search-icon-clear")) {
			// 			let $input = PKG_PANES_REFS.$input;
			// 			$input.value = "";
			// 			let opts = { targets: { target: $input } };
			// 			Interaction.trigger("search-input", opts);
			// 		}

			// 		$delegate.focus();
			// 		e.preventDefault();
			// 	}

			// 	break;

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

						let obj = {
							name: id.slice(10),
							panel: get_active_panel_name(),
							exclude: "location"
						};
						API.get_pkg_info(JSON.stringify(obj));
					}
				}

				break;
			case "sidebar:entry":
				{
					if ($cached_sb === $delegate) {
						$cached_sb.classList.remove("selected");
						let panel = $cached_sb.getAttribute("data-row");
						let $node = $(panel + "-cont");
						if ($node) $node.classList.add("none");
						$cached_sb = null;

						$("default-cont").classList.remove("none");

						$ACTIVE_PANE = null; // Clear active pane.

						return;
					}
					if ($cached_sb) {
						$cached_sb.classList.remove("selected");
						let panel = $cached_sb.getAttribute("data-row");
						let $node = $(panel + "-cont");
						if ($node) $node.classList.add("none");
					}

					if ($delegate) {
						let $default = $("default-cont");
						if (!$default.classList.contains("none")) {
							$default.classList.add("none");
						}

						$delegate.classList.toggle("selected");
						let panel = $delegate.getAttribute("data-row");
						let $node = $(panel + "-cont");
						if ($node) $node.classList.remove("none");
						$cached_sb = $delegate;

						// if (!is_panel_blocked(panel)) {

							set_active_pkg_pane(panel);
							// block_panel(panel);
							let $icon = PKG_PANES_REFS.$mcheck;

							switch (panel) {
								case "packages-installed": {
									let obj = {
										input: PKG_PANES_REFS.$input.value.trim(),
										panel: panel
									};
									API.packages_ints(JSON.stringify(obj));

									break;
								}
								case "packages-available": {
									let obj = {
										input: PKG_PANES_REFS.$input.value.trim(),
										panel: panel
									};
									API.packages_avai(JSON.stringify(obj));

									break;
								}
								// case "packages-outdated": {
								// 	set_active_pkg_pane(panel);
								// 	// block_panel(panel);
								// 	let $icon = PKG_PANES_REFS.$mcheck;

								// 	uncheck($icon);
								// 	toggle_pkg_sel_actions(false);
								// 	mass_toggle("uncheck");
								// 	// selected_pkgs.clear();

								// 	let obj = {
								// 		input: PKG_PANES_REFS.$input.value.trim(),
								// 		panel: panel
								// 	};

								// 	break;
								// }

									// API.packages_outd(JSON.stringify(obj));
								case "settings":
									API.config();
									break;
								// else if (panel === "doctor") API.doctor();
							}
						// }
					}
				}

				break;
		}
	});

	Interaction.addHandler("click:main", async (e, targets, filter) => {
		if (e.which !== 1) return; // Only left button mousedowns.
		let $delegate = targets.delegateTarget;
		let id = $delegate.id;

		switch (filter) {
			case "packages:input-cont":
				{
					// If the clear icon is clicked...
					if ($delegate.classList.contains("search-icon-clear")) {
						let $input = PKG_PANES_REFS.$input;
						$input.value = "";
						PKG_PANES_REFS.checked_all = false;
						PKG_PANES_REFS.checked.length = 0;
						PKG_PANES_REFS.jdata_filtered.length = 0;


						let opts = { targets: { target: $input } };
						Interaction.trigger("search-input", opts);
					}

					$delegate.focus();
					e.preventDefault();
				}

				break;


			case "packages:main-checkmark":
				{
					let panel = get_active_panel_name();
					let PANEL = get_panel_by_name(panel);
					// prettier-ignore
					let $icon = f($delegate).all().classes("fa-check").getElement();
					if (!checked($icon)) {
						check($icon);
						toggle_pkg_sel_actions(true);
						mass_toggle("check");
						PANEL.checked_all = true;
					} else {
						uncheck($icon);
						toggle_pkg_sel_actions(false);
						mass_toggle("uncheck");
						// selected_pkgs.clear();
						PANEL.checked_all = false;
					}
				}

				break;

			case "packages:entry-checkmark":
				{
					let panel = get_active_panel_name()
					let name = $delegate.getAttribute("data-name");
					// prettier-ignore
					let $icon = PKG_PANES_REFS.$mcheck;

					uncheck($icon); // Untoggle main checkmark.

					// prettier-ignore
					let $dicon = f($delegate).all().classes("fa-check").getElement();
					let ischecked = !checked($dicon);
					window[ischecked ? "check" : "uncheck"]($dicon);

					let PANEL = get_panel_by_name(panel);
					if (PANEL.checked_all && !ischecked) {
						PANEL.checked = PANEL.jdata_names;
						PANEL.checked_all = false;
					}
					if (ischecked) PANEL.checked.push(name);
					else {
						let list = PANEL.checked;
						let index = list.indexOf(name);
						if (-~index) list.splice(index, 1)
					}

					// prettier-ignore
					let list = f(PKG_PANES_REFS.$entries).all().classes("checkmark", "selected").getStack();
					toggle_pkg_sel_actions(!!list.length);
				}

				break;

			case "packages:actions":
				{
					let panel = get_active_panel_name();
					// block_panel(panel);

					// let packages = Array.from(selected_pkgs);
					// selected_pkgs.clear();
					let PANEL = get_panel_by_name(panel);

					// if (is_panel_blocked(panel)) return;
					// else block_panel(panel);

					// let isall_checked = f(PKG_PANES_REFS.$mcheck).classes("!none").getElement();
					let isall_checked = PANEL.checked_all;
					let obj = { all: PANEL.checked_all, names: PANEL.checked, panel };

					// Uncheck everything.
					let $icon = PKG_PANES_REFS.$mcheck;

					uncheck($icon);
					mass_toggle("uncheck");
					toggle_pkg_sel_actions(false);

					let action = $delegate.getAttribute("data-tippy-content").toLowerCase();
					// let panel = get_active_panel_name();

					switch (action) {
						case "refresh":
							{}

							break;

						case "remove":
							{
								API.rpkgs(JSON.stringify(obj));
								PANEL.checked.length = 0;
								PANEL.checked_all = false;
							}

							break;

						case "enable":
							{
								API.epkgs(JSON.stringify(obj));
								PANEL.checked.length = 0;
								PANEL.checked_all = false;
							}

							break;

						case "disable":
							{
								API.dpkgs(JSON.stringify(obj));
								PANEL.checked.length = 0;
								PANEL.checked_all = false;
							}

							break;

						case "sync":
							{
								let panel = get_active_panel_name();
								// block_panel(panel);

								let obj = {
									input: PKG_PANES_REFS.$input.value.trim(),
									panel: panel
								};

								API.packages(JSON.stringify(obj));
							}
							break;

						case "install":
							{
								let panel = get_active_panel_name();
								// block_panel(panel);

								// let packages = Array.from(selected_pkgs);
								// selected_pkgs.clear();
								let PANEL = get_panel_by_name(panel);
								let packages = PANEL.checked;
								let obj = { name: "", panel };
								if (PANEL.checked_all) packages = PANEL.jdata_names;
								for (let i = 0, l = packages.length; i < l; i++) {
									obj.name = packages[i];
									API.ipkg(JSON.stringify(obj));
								}
								PANEL.checked.length = 0;
								PANEL.checked_all = false;
							}
							break;



						case "refresh list":
							{







							let panel = get_active_panel_name();
							// block_panel(panel);

							// if (JDATA.PKG_AVAI_REFS) {
							// 	toggle_pkg_sel_action_refresh(true);
							// 	return;
							// }

							set_active_pkg_pane(panel);
							// block_panel(panel);
							let $icon = PKG_PANES_REFS.$mcheck;
							//

							uncheck($icon);
							toggle_pkg_sel_actions(false);
							// mass_toggle("uncheck");
							// selected_pkgs.clear();

							let obj = {
								input: PKG_PANES_REFS.$input.value.trim(),
								panel: panel,
								force: true
							};


							let PANEL = get_panel_by_name(panel);
							PANEL.jdata_names.length = 0;

							API.packages_avai(JSON.stringify(obj));





							}
							break;


					}
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
					} else if (action === "update") {
						API.update();
					} else if (action === "clear-update") {
						let $cont = $("update-output");
						while ($cont.firstChild) {
							$cont.removeChild($cont.lastChild);
						}
					} else if (action === "clear-doctor") {
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

	let PKG_CONT_NAMES = ["packages-installed", "packages-available", "packages-outdated"];
	// prettier-ignore
	// let PKG_INST_REFS = {}, PKG_AVAI_REFS = {}, PKG_OUTD_REFS = {};
	let PKG_OBJS = [PKG_INST_REFS, PKG_AVAI_REFS, PKG_OUTD_REFS];
	for (let i = 0, l = PKG_CONT_NAMES.length; i < l; i++) {
		let name = PKG_CONT_NAMES[i];
		let obj = PKG_OBJS[i];

		obj.name = name;
		let $cont = $(`${name}-cont`);
		obj.$cont = $cont;
		obj.$count = f($sidebar).all().attrs(`[data-row=${name}]`).all().classes("count").getElement()
		obj.$tb = f($cont).all().classes("pkg-toolbar").getElement();
		obj.$mcheck = f($cont).all().classes("main-check").all().classes("fa-check").getElement();
		obj.$tb_loader = f($cont).all().classes("tb-spinner").getElement();
		obj.$input = f($cont).all().classes("header-input").getElement();
		obj.$input_loader = f($cont).all().classes("search-loader").getElement();
		obj.$clear = f($cont).all().classes("search-icon-clear").getElement();
		obj.$entries = f($cont).all().classes("entries").getElement();
		obj.$sbentry = f("#sidebar").all().attrs(`[data-row=${name}]`).all().classes("loader-cont").getElement();
		//
		obj.$pname = f($cont).all().classes("i-name").getElement();
		obj.$pdescription = f($cont).all().classes("i-description").getElement();
		obj.$pauthor = f($cont).all().classes("i-author").getElement();
		obj.$prepository = f($cont).all().classes("i-repository").getElement();
		obj.$plocation = f($cont).all().classes("i-location").getElement();
		obj.$pversion = f($cont).all().classes("i-version").getElement();
		obj.$plicense = f($cont).all().classes("i-license").getElement();
		//
		obj.jdata = "";
		obj.checked = [];
		obj.checked_all = false;
		obj.jdata_names = [];
		obj.jdata_filtered = [];
	}

	const $settings = $("settings-cont");
	const $update = $("update-cont");
	const $doctor = $("doctor-cont");

	function set_active_pkg_pane(name) {
		switch (name) {
			case "packages-installed":
				PKG_PANES_REFS = PKG_INST_REFS;
				break;

			case "packages-available":
				PKG_PANES_REFS = PKG_AVAI_REFS;
				break;

			case "packages-outdated":
				PKG_PANES_REFS = PKG_OUTD_REFS;
				break;
		}
	}

	Interaction.addFilter("packages:main-checkmark", (e, targets) => {
		if (is_panel_blocked(get_active_panel_name())) return;
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		// [FIX/BUG]: Funnel has a bug: gets document element when it should not.
		// let $el = f(targets.target).concat($parents).attrs("id").attrs("id=main-toggle").getElement();
		let $el = f(targets.target).concat($parents).classes("main-check").getElement();
		if (PKG_PANES_REFS.$tb.contains($el)) return $el;
	});
	Interaction.addFilter("packages:entry-checkmark", (e, targets) => {
		if (is_panel_blocked(get_active_panel_name())) return;
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("checkmark").getElement();
		if (PKG_PANES_REFS.$entries.contains($el)) return $el;
	});
	Interaction.addFilter("packages:entry", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("entry").getElement();
		let $cm = f($target).concat($parents).classes("checkmark").getElement();
		if (is_panel_blocked(get_active_panel_name()) && $cm) return;
		if (!$cm && PKG_PANES_REFS.$entries.contains($el)) return $el;
	});
	Interaction.addFilter("packages:actions", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("tb-action").getElement();
		if (PKG_PANES_REFS.$tb.contains($el)) return $el;
	});

	Interaction.addFilter("sidebar:entry", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("row").getElement();
		if ($sidebar.contains($el)) {
			return ($ACTIVE_PANE = $el);
		}
	});
	Interaction.addFilter("settings:action", (e, targets) => {
		let $target = targets.target;
		let $parents = f($target).parents().getStack();
		let $el = f($target).concat($parents).classes("btn-action").getElement();
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
		if ($doctor.contains($el) || $update.contains($el)) return $el;
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
		return $clear || (!$input && $el ? PKG_PANES_REFS.$input : undefined);
	});

	new Interaction()
		.on("mousedown")
		.anchors(document)
		.handler("mousedown:main")
		.filters("sidebar:entry")
		.filters("packages:entry")
		// .filters("packages:input-cont")
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
		.filters("packages:actions")
		.filters("packages:input-cont")
		.filters("doctor:actions")
		.capture(false)
		.enable();

	Interaction.addFilter("packages:input", (e, targets) => {
		return f(targets.target).tags("input").getElement();
	});

	Interaction.addHandler("input:main", (e, targets) => {
		if (targets.delegateTarget) {
			// Reset actions.
			let $icon = PKG_PANES_REFS.$mcheck;

			uncheck($icon);
			toggle_pkg_sel_actions(false);
			// mass_toggle("uncheck");
			// selected_pkgs.clear();

			PKG_PANES_REFS.checked_all = false;
			PKG_PANES_REFS.checked.length = 0;
			PKG_PANES_REFS.jdata_filtered.length = 0;

			let $target = targets.delegateTarget;
			let value = $target.value;

			// let $clear = f(PKG_PANES_REFS.$cont).all().classes("search-icon-clear").getElement();
			let $clear = PKG_PANES_REFS.$clear;
			if (value.length) $clear.classList.remove("opa0", "nointer");
			else $clear.classList.add("opa0", "nointer");

			// let $spinner = f(PKG_PANES_REFS.$cont).all().classes("search-loader").getElement();
			// let $spinner = $input_loader;
			PKG_PANES_REFS.$input_loader.classList.remove("none");

			// let panel = get_active_panel_name();
			// var filterfn = "";
			switch (PKG_PANES_REFS.name) {
				case "packages-installed":
					API.filter_inst(value);
					break;
				case "packages-available":
					API.filter_avai(value);
					break;
				case "packages-outdated":
					// API.filter_outd(value);
					break;
			}


			// API.filter_avai(value);
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
	new Interaction().on("focus").anchors(window).handler("focus:main").debounce(100).enable();

	// window.addEventListener("contextmenu", (event) => event.preventDefault());
};

let main = async function () {
	// [https://stackoverflow.com/a/61839322]
	// d.onreadystatechange = () => {
	// if (d.readyState === "complete") setTimeout(() => init(), 250);

	/* Sniff: [https://stackoverflow.com/a/4702584] */
	if (navigator.platform.includes("Mac")) {
		d.body.classList.add("macosx-no-rubberbanding", "macosx-zoom");
	}

	if (d.readyState === "complete") {
		// FastClick.attach(document.body);

		let handler1 = (e) => {
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
		};

		let handler2 = (e) => {
			let $target = e.target;
			let aname = e.animationName;
			let id = $target.id;

			if ($target.classList.contains("logitem") && aname === "new-highlight") {
				$target.classList.remove("new-highlight");
			}
		};

		let handler3 = (e) => {
			let $target = e.target;
			let id = $target.id;
			let pname = e.propertyName;

			if (id && id === "leaf") {
				let classes = $target.classList;
				if (!classes.contains("on")) {
					classes.remove("off");
					classes.add("on");
				} else {
					classes.add("animate-pulse");
				}
			} else if (id && id === "splash-overlay") {
				let $so = $("splash-overlay");
				$so.classList.add("none");
				$so.parentNode.removeChild($so);

				d.removeEventListener(which_animation_event("start"), handler1);
				d.removeEventListener(which_animation_event("end"), handler2);
				d.removeEventListener(which_transition_event("end"), handler3);

				init();
			}
		};

		d.addEventListener(which_animation_event("start"), handler1);
		d.addEventListener(which_animation_event("end"), handler2);
		d.addEventListener(which_transition_event("end"), handler3);

		$("leaf").classList.add("off"); // Start splash animation.
	}
	// };
};

document.onreadystatechange = function () {
	"use strict";

	// once all resources have loaded
	if (document.readyState == "complete") {
		let $cached = null;
		const { Interaction, Funnel } = window.app.libs;
		Interaction.addFilter("row:F", function (e, targets) {
			let parents = Funnel(targets.target).parents().getStack();
			return Funnel(targets.target)
				.concat(parents)
				.classes("pkg-entry")
				.getElement();
		});
		Interaction.addHandler("mousedown:H", function (e, targets) {
			if (e.which !== 1) return; // Only left button mousedowns.
			if ($cached) $cached.classList.remove("pkg-entry-selected");
			let delegate = targets.delegateTarget;
			if ($cached === delegate) {
				$cached = null;
				return;
			}
			if (delegate) {
				console.log("111");
				delegate.classList.toggle("pkg-entry-selected");
				$cached = delegate;
			}
		});
		var event = new Interaction("Handle onChange events.")
			.on("mousedown")
			.anchors(document)
			.handler("mousedown:H")
			.filters("row:F")
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

		// window.addEventListener("contextmenu", (event) => event.preventDefault());

		/* Sniff: [https://stackoverflow.com/a/4702584] */
		if (navigator.platform.includes("Mac")) {
			document.body.classList.add("macosx-zoom");
		}
	}
};

// let last_clicked = null;
// document.addEventListener('mousedown', function(e) {
// 	const target = e.target;
// 	if (last_clicked) {
// 		last_clicked.classList.remove("vi-row-selected");
// 	}
// 	if (target.classList.contains("vi-row")) {
// 		target.classList.toggle("vi-row-selected");
// 		last_clicked = target;
// 	}
// }, false);

// let $cached = null;
// document.addEventListener("mousedown", function(e) {
// 	var f = window.app.libs.Funnel;
// 	var $target = e.target;
// 	var $el = f($target).parents().classes("vi-row").getElement();
// 	if (!$el && $target.classList.contains("vi-row")) $el = $target;

// 	if ($cached) $cached.classList.remove("vi-row-selected");
// 	if ($el) {
// 		$el.classList.toggle("vi-row-selected");
// 		$cached = $el;
// 	}
// }, false);

let $cached = null;
const { Interaction, Funnel } = window.app.libs;
Interaction.addFilter("rowFilter", function (e, targets) {
	let parents = Funnel(targets.target).parents().getStack();
	return Funnel(targets.target)
		.concat(parents)
		.classes("vi-row")
		.getElement();
});
Interaction.addHandler("mousedownRow", function (e, targets, filter_name) {
	if (e.which !== 1) return; // Only left button mousedowns.
	if ($cached) $cached.classList.remove("vi-row-selected");
	let delegate = targets.delegateTarget;
	if ($cached === delegate) {
		$cached = null;
		return;
	}
	if (delegate) {
		console.log("111");
		delegate.classList.toggle("vi-row-selected");
		$cached = delegate;
	}
});
var event = new Interaction("Handle onChange events.")
	.on("mousedown")
	.anchors(document)
	.handler("mousedownRow")
	.filters("rowFilter")
	.capture(false)
	.enable();

Interaction.addFilter("inputFilter", function (e, targets) {
	return Funnel(targets.target).tags("input").getElement();
});
Interaction.addHandler("inputHandler", function (e, targets, filter_name) {
	if (targets.delegateTarget) {
		let target = targets.delegateTarget;
		let value = target.value;
		console.log(value);
	}
});
var event = new Interaction("Handle onChange events.")
	.on("input")
	.anchors(document)
	.handler("inputHandler")
	.filters("inputFilter")
	.capture(false)
	.debounce(200)
	.enable();

window.addEventListener("contextmenu", (event) => event.preventDefault());

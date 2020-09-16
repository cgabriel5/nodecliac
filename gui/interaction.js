// IIFE start
(function(window) {
    "use strict";
    var library = (function() {
        // =============================== Helper Functions
        /**
         * @description [Generates a simple ID containing letters and numbers.]
         * @param  {Number} length [The length the ID should be. Max length is 22 characters]
         * @return {String}        [The newly generated ID.]
         * @source {http://stackoverflow.com/a/38622545}
         */
        function id(length) {
            return Math.random()
                .toString(36)
                .substr(2, length);
        }
        /**
         * @description [Returns index of given value in provided array.]
         * @param  {Array}    array [The array to check against.]
         * @param  {Integer}  value [The value to check.]
         * @return {Integer}        [Returns the index value. -1 if not in array.]
         */
        function index(array, value) {
            return array.indexOf(value);
        }
        /**
         * @description [Checks if the given value is in provided array or string.]
         * @param  {Array|String}   iterable [The array or string to check against.]
         * @param  {Any}            value    [The value to check.]
         * @return {Boolean}                 [description]
         * @source [https://www.joezimjs.com/javascript/great-mystery-of-the-tilde/]
         * @source [http://stackoverflow.com/questions/12299665/what-does-a-tilde-do-
         * when-it-precedes-an-expression/12299717#12299717]
         */
        function includes(iterable, value) {
            return -~index(iterable, value);
        }
        /**
         * @description [Checks if the provided index exists.]
         * @param  {Number} index [The index (number) to check.]
         * @return {Boolean}       [False if -1. Otherwise, true.]
         */
        function indexed(index) {
            return -~index ? true : false;
        }
        /**
         * @description [Makes an Array from an array like object (ALO). ALO must have a length property
         *               for it to work.]
         * @param  {ALO} alo [The ALO.]
         * @return {Array}   [The created array.]
         */
        function to_array(alo) {
            // vars
            var true_array = [];
            // loop through ALO and pushing items into true_array
            for (var i = 0, l = alo.length; i < l; i++) true_array.push(alo[i]);
            return true_array;
        }
        /**
         * @description [Returns the data type of the provided object.]
         * @param  {Any} object [The object to check.]
         * @return {String}    [The data type of the checked object.]
         */
        var dtype = function(object) {
            // will always return something like "[object {type}]"
            return Object.prototype.toString.call(object)
                .replace(/(\[object |\])/g, "")
                .toLowerCase();
        };
        /**
         * @description [Check if the provided object is of the provided data types.]
         * @param  {Any} object [The object to check.]
         * @param  {String}  types  [The allowed data type the object may be.]
         * @return {Boolean}        [Boolean indicating whether the object is of the
         *                           allowed data types.]
         */
        dtype.is = function(object, types) {
            // get the object type
            var type = this(object);
            // prepare the types
            types = "|" + types.toLowerCase()
                .trim() + "|";
            // check if the object's type is in the list
            return Boolean(-~types.indexOf("|" + type + "|"));
        };
        /**
         * @description [Check if the provided object is not of the provided data types.]
         * @param  {Any} object [The object to check.]
         * @param  {String}  types  [The prohibited data types.]
         * @return {Boolean}        [Boolean indicating whether the object is not of the
         *                           allowed data types.]
         */
        dtype.isnot = function(object, types) {
            // return the inverse of the is method
            return !this.is(object, types);
        };
        /**
         * @description [Debounces provided function.]
         * @param  {Function} func            [The function to debounce.]
         * @param  {Number} time              [The time to debounce by.]
         * @param  {Object} scope             [The scope in which to run function with.]
         * @param  {Boolean} run_immediately  [Flag indicating whether the function
         *                                     should run immediately.]
         * @return {Function}                 [The new debounced function.]
         * @source debouncing function from John Hann
         * @source {http://unscriptable.com/index.php/2009/03/20/debouncing-javascript-methods/}
         * @source {https://www.paulirish.com/2009/throttled-smartresize-jquery-event-handler/}
         * @resource [Another debounce function] {https://davidwalsh.name/javascript-debounce-function}
         */
        function debounce(func, time, scope, run_immediately) {
            var timeout;
            return function() {
                var context = (scope || this),
                    args = arguments;

                function delayed() {
                    if (!run_immediately) {
                        func.apply(context, args);
                    }
                    timeout = null;
                }
                if (timeout) {
                    clearTimeout(timeout);
                } else if (run_immediately) {
                    func.apply(context, args);
                }
                timeout = setTimeout(delayed, time || 100);
            };
        }
        /**
         * @description [Throttles provided function.]
         * @param  {Function} func            [The function to throttle.]
         * @param  {Number} time              [The time to throttle by.]
         * @param  {Object} scope             [The scope in which to run function with.]
         * @return {Function}                 [The new throttled function.]
         * @source {https://remysharp.com/2010/07/21/throttling-function-calls}
         */
        function throttle(func, time, scope) {
            time = (time || 250);
            var last, deferTimer;
            return function() {
                var context = (scope || this),
                    now = +new Date(),
                    args = arguments;
                if (last && now < last + time) {
                    // hold on to it
                    clearTimeout(deferTimer);
                    deferTimer = setTimeout(function() {
                        last = now;
                        func.apply(context, args);
                    }, time);
                } else {
                    last = now;
                    func.apply(context, args);
                }
            };
        }
        /**
         * @description [A class wrapper. Creates a class based on provided object containing class constructor__ and methods__.
         *               If class needs to extend another, provide it under the extend__ property.]
         * @param  {Object} cobject [The class object containing three properties: constructor__, methods__, and extend__.
         *                           .constructor__ {Function}       [The class constructor]
         *                           .methods__     {Object}         [Object containing class methods.]
         *                           .extend__      {Boolean|Object} [Set to false if does not need to extend. Otherwise, provide the
         *                                                            class to extend.]
         *                           ]
         * @return {Function}         [Returns class constructor.]
         */
        function class__(cobject) {
            // cache class data
            var constructor = cobject.constructor__,
                methods = cobject.methods__,
                parent = cobject.extend__;
            // extend if parent class provided
            if (parent) {
                constructor.prototype = Object.create(parent.prototype);
                constructor.prototype.constructor = constructor;
            }
            // cache prototype
            var prototype = constructor.prototype;
            // add class methods to prototype
            for (var method in methods) {
                if (methods.hasOwnProperty(method)) {
                    prototype[method] = methods[method];
                }
            }
            return constructor;
        }
        // =============================== Core Library Functions
        /**
         * @description [Normalizes the Interaction object's options. In essence,
         *               the provided options are combined with the defaults.]
         * @param  {Object} _ [The Interaction object.]
         * @return {Object}   [The normalized options.]
         */
        function normalized(_) {
            // cache object info
            var properties = _.properties,
                options = _.options;
            // combine the objects to normalize
            // {https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign}
            var normalized = Object.assign({
                "id": null, // user changeable ID
                "name": null,
                "events": [],
                "namespace": null,
                "anchors": [],
                "filters": [],
                "fireCount": Infinity,
                "capture": false,
                "passive": false,
                "debounce": null,
                "throttle": null,
                "handler": function() { /* noop */ }
            }, options);
            // check if id needs to be reset
            if (!normalized.id) normalized.id = properties.iid;
            // set the options
            _.options = normalized;
            // return the normalized the object
            return normalized;
        }
        // check functions
        //
        var checks = {
            /**
             * @description [Checks whether the passed in element and target.fromElement
             *               is of the main element and not the main element itself. This
             *               check is run to prevent the handler from firing on the ancestor
             *               elements. Basically, mimicking the "mouseenter" event. Where the
             *               handler is only fired on the main (parent) element.]
             * @param  {HTMLElement} result [The HTML element.]
             * @param  {Object} targets [An objects containing the events target elements.]
             * @return {HTMLElement|Null} [The HTML element if check passes. Otherwise, null.]
             */
            "mouseenter": function(result, targets) {
                return ((result && !result.contains(targets.fromElement)) ? result : null);
            },
            /**
             * @description [Checks whether the passed in element and target.toElement
             *               is of the main element and not the main element itself. This
             *               check is run to prevent the handler from firing on the ancestor
             *               elements. Basically, mimicking the "mouseleave" event. Where the
             *               handler is only fired on the main (parent) element.]
             * @param  {HTMLElement} result [The HTML element.]
             * @param  {Object} targets [An objects containing the events target elements.]
             * @return {HTMLElement|Null} [The HTML element if check passes. Otherwise, null.]
             */
            "mouseleave": function(result, targets) {
                return ((result && !result.contains(targets.toElement)) ? result : null);
            }
        };
        /**
         * @description [Function creates the internally used handler for the event, throttles/debounces if need be, and
         *               attaches the event to the anchor.]
         * @param  {Object} _            [The Interaction object to work with.]
         * @param  {String} id           [The ID of the Interaction object.]
         * @param  {HTMLElement} anchor  [The anchor element to unbind event from.]
         * @param  {String} event        [The event to remove.]
         * @param  {String} event_type   [The events constructor type.]
         * @param  {String} namespace    [The event namespace.]
         * @param  {Number} fire_count   [The amount of times the handler should fire.]
         * @param  {Function} handler    [The event handler.]
         * @param  {Object} options      [The event listener options.]
         * @param  {Array} filters       [The filters that should be run when using delegation.]
         * @return {Undefined}     [Nothing is returned.]
         */
        function create_event(_, id, anchor, event, event_type, namespace, fire_count, handler, options, filters) {
            // the user's event handler gets wrapped with a function to apply
            // libray logic such as: filters (delegation) and fireCount.
            var fn = function(e) {
                // if the Interaction is disabled prevent from firing the handler
                if (!_.properties.enabled) return;
                // get all possible elements used by web browsers
                // currentTarget, fromElement, relatedTarget, srcElement, target, toElement
                // currentTarget, explicitOriginalTarget, originalTarget, relatedTarget, target
                //
                // event targets: {https://developer.mozilla.org/en-US/docs/Web/API/Event/Comparison_of_Event_Targets}
                var targets = {
                    //
                    // **Note: appropriate defaults are set for a better cross browser experience
                    //
                    // -- browser mutual event targets
                    //
                    // the element that trigger/dispatched the event
                    "target": (e.target || null),
                    // event info: {https://developer.mozilla.org/en-US/docs/Web/API/Event/currentTarget}
                    // always refers to the element that the event handler was attached to
                    "currentTarget": (e.currentTarget || null),
                    // event info: {https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/relatedTarget}
                    // a read-only mouseevent property that refers to the secondary element involved in the event.
                    "relatedTarget": (e.relatedTarget || null),
                    //
                    // -- all but ff
                    //
                    // event info: {https://developer.mozilla.org/en-US/docs/Web/API/Event/srcElement}
                    // avoid using this event target and use e.target as this is just an alias for e.target
                    "srcElement": (e.srcElement || e.target),
                    // equivalent to ff's relatedTarget: {http://help.dottoro.com/ljjqfjbs.php}
                    "fromElement": (e.fromElement || e.relatedTarget),
                    // equivalent to ff's relatedTarget: {http://help.dottoro.com/ljltrsom.php}
                    "toElement": (e.toElement || e.relatedTarget),
                    //
                    // -- ff specific
                    //
                    // do not use: {https://developer.mozilla.org/en-US/docs/Web/API/Event/explicitOriginalTarget} {http://stackoverflow.com/questions/179826/crossbrowser-equivalent-of-explicitoriginaltarget-event-parameter}
                    "explicitOriginalTarget": (e.explicitOriginalTarget || null),
                    // do not use: {https://developer.mozilla.org/en-US/docs/Web/API/Event/originalTarget}
                    "originalTarget": (e.originalTarget || null)
                };
                // get the provided (synthetic targets) and combine with the above targets object
                // **Note**: synthetic elements are only provided on trigger events
                if (e.targets) targets = Object.assign(targets, e.targets);
                // check whether it's a mutation event. if so, reset the target & srcElement to the mutation targets
                if (e.detail && e.detail.__MUTATION_RECORD__) {
                    var detail = e.detail.__MUTATION_RECORD__;
                    targets = Object.assign(targets, {
                        "target": detail.target,
                        "srcElement": detail.target
                    });
                }
                // define vars
                var delegate, filter_name;
                // run provided filters
                for (var i = 0, l = filters.length; i < l; i++) {
                    // run the filter
                    var result = filters[i][0].call(anchor, e, targets),
                        // cache the filter return type
                        return_type = filters[i][1],
                        check;
                    // cache the filter name
                    filter_name = filters[i][2];
                    // if there is a result (the filter provided us with a passable element)
                    // fun the middleware return type functions
                    if (result) {
                        // apply the return type (this is the normal return type)
                        // this return type will always return the result of the filter
                        if (return_type === "self") {
                            delegate = result;
                            break;
                        } else if (return_type === "mouseenter") {
                            // return type simulates the mouseenter event, therefore it checks
                            // the target elements are not the main element or an ancestor
                            check = (checks.mouseenter)(result, targets);
                            // if the check passes we have a main target and the delegate
                            // var can be set to the main target that the check returns
                            if (check) {
                                delegate = check;
                                break;
                            }
                        } else if (return_type === "mouseleave") {
                            // return type simulates the mouseleave event, therefore it checks
                            // the target elements are not the main element or an ancestor
                            check = (checks.mouseleave)(result, targets);
                            // if the check passes we have a main target and the delegate
                            // var can be set to the main target that the check returns
                            if (check) {
                                delegate = check;
                                break;
                            }
                        }
                    }
                    // if it's the last filter and no delegate element is
                    // returned, this means the target element failed all
                    // filters and the handler should not be run
                    if (i === (l - 1) && !delegate) return;
                }
                // add the delegate to the targets object
                // if no delegate is detected it defaults to the currentTarget element
                // if (!targets.delegateTarget)
                targets.delegateTarget = (delegate || targets.currentTarget);
                // finally...invoke the user handler
                handler.call((delegate || anchor), e, targets, filter_name);
                // decrease the count
                _.properties.fireCount--;
                // if the fireCount zeroes, zeroe the Interaction (remove)
                if (_.properties.fireCount <= 0) return zeroed(_);
            };
            // check if the user wants the event debounced or throttled
            var options_ = _.options,
                debounce_ = options_.debounce,
                throttle_ = options_.throttle;
            // debounce handler if the user wants it
            if (debounce_) fn = debounce(fn, debounce_);
            // throttle handler if the user wants it
            if (throttle_) fn = throttle(fn, throttle_);
            // add the event
            anchor.addEventListener(event, fn, options);
            // MutationObserver::START
            // if event is a LibraryEvent (mutation) add setup a MutationObserver
            if (event_type === "LibraryEvent") {
                // [https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver]
                // create the mutation observer
                var observer = new MutationObserver(function(mutations) {
                    // loop over the mutations
                    for (var i = 0, l = mutations.length; i < l; i++) {
                        var mutation = mutations[i];
                        // [https://developer.mozilla.org/en-US/docs/Web/Guide/Events/Creating_and_triggering_events]
                        // [https://developer.mozilla.org/en-US/docs/Web/API/Event/Event]
                        // [https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent/CustomEvent]
                        // [https://stackoverflow.com/a/19345563]
                        // trigger the custom event
                        anchor.dispatchEvent(new CustomEvent(event, {
                            // provide the mutation record object via the custom events
                            // detail data property.
                            detail: {
                                "__MUTATION_RECORD__": mutation
                            }
                        }));
                    }
                });
                // pass in the target node, as well as the observer options
                // [add way to allow the passage of an options method to let user pick
                // what mutations to listen to??]
                observer.observe(anchor, {
                    "attributes": true,
                    "childList": true,
                    "characterData": true,
                    "subtree": true,
                    "attributeOldValue": true,
                    "characterDataOldValue": true
                });
                // attach observer to internally made function handler to be able disconnect later
                fn.observer = observer;
            }
            // MutationObserver::END
            // add the new handler to the properties
            if (!_.properties.handlers) _.properties.handlers = [];
            _.properties.handlers.push(fn);
            // store the event
            registry.interactions.push(_);
            // set the option
            _.properties.created = true;
        }
        /**
         * @description [Function removes the provided event from provided anchor element.]
         * @param  {Object} _            [The Interaction object to work with.]
         * @param  {HTMLElement} anchor  [The anchor element to unbind event from.]
         * @param  {String} event        [The event to remove.]
         * @param  {Function} handler    [The event handler.]
         * @param  {Object} options      [The event listener options.]
         * @return {Undefined}     [Nothing is returned.]
         */
        function remove_event(_, anchor, event, handler, options) {
            // remove the event
            anchor.removeEventListener(event, handler, options);
            // stop observing mutations if a mutation observer is present
            if (handler.observer) handler.observer.disconnect();
        }
        /**
         * @description [When an event has zeroed, when the fireCount is not set to
         *               Infinity, this function will remove all events from anchored
         *               elements and remove the Interaction object from the registry.]
         * @param  {Object} _ [The Interaction object to work with.]
         * @return {Undefined}     [Nothing is returned.]
         */
        function zeroed(_) {
            // cache needed info
            var properties = _.properties,
                options = _.options,
                // options not needed
                // id = options.id,
                // filters = options.filters,
                // fire_count = options.fireCount,
                // handler = options.handler,
                // namespace = options.namespace,
                anchors = options.anchors,
                events = options.events,
                handlers = properties.handlers,
                // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
                options_ = {
                    "capture": options.capture,
                    "passive": options.passive
                };
            // remove the event for all the provided anchors
            // loop over anchors
            for (var i = 0, l = anchors.length; i < l; i++) {
                // cache the current anchor
                var anchor = anchors[i];
                // loop over events
                for (var j = 0, ll = events.length; j < ll; j++) {
                    // cache the current event
                    var event = events[j][0];
                    // attach the event
                    remove_event(_, anchor, event, handlers[i], options_);
                }
            }
            // remove the event from the pool
            //
            // cache the interactions from registry
            var interactions = registry.interactions;
            //
            // get the objects position in the interactions array
            var position = index(interactions, _);
            //
            // if index exists remove event object from array
            if (indexed(position)) interactions.splice(position, 1);
            // set the removed property, in the case the user
            // still has a reference to it. however, the library
            // will no longer be tracking the event as it is no
            // longer in the registry
            _.properties.removed = true;
        }
        // =============================== Library Class
        var Library = class__({
            /**
             * @description [The library class constructor.]
             * @param  {String} name [The name of the interaction.]
             * @param  {String} clone_interaction_id [The id of the interaction to clone options of.]
             * @return {Undefined}     [Nothing is returned.]
             */
            "constructor__": function(name, clone_interaction_id) {
                // if user does not invoke library with new keyword we use it for them by
                // returning a new instance of the library with the new keyword.
                if (!(this instanceof Library)) return new Library(name, clone_interaction_id);
                // cloning vars
                var parent, parent_options;
                // if cloning...get the interactions options
                if (clone_interaction_id) {
                    // however, make sure the interaction exists
                    parent = library.interaction(clone_interaction_id);
                    if (parent) {
                        // get the options
                        parent_options = Object.assign({}, parent.options);
                    }
                }
                // user provided options
                this.options = (parent_options || {});
                // object properties
                this.properties = {
                    "iid": id(22), // library ID (internal)
                    "enabled": false,
                    "created": false,
                    "locked": false,
                    "removed": false,
                    "fireCount": Infinity
                };
                // add the name if provided
                if (name) {
                    this.options.name = name;
                    this.properties.name = name;
                }
                // object defaults
                this.defaults = {
                    "id": null, // user changeable ID
                    "name": null,
                    "events": [],
                    "namespace": null,
                    "anchors": [],
                    "filters": [],
                    "fireCount": Infinity,
                    "capture": false,
                    "passive": false,
                    "debounce": null,
                    "throttle": null,
                    "handler": function() { /* noop */ }
                };
            },
            // class methods
            "methods__": {
                /**
                 * @description [Adds id to options object.]
                 * @param  {String} id [The id. Needs to be unique.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "id": function(id) {
                    // cache the object
                    var _ = this;
                    // provided ID must be of specified type
                    // if not, stop function execution
                    if (id && dtype.isnot(id, "string")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.id = id;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the event types to listen to/interact with.]
                 * @param  {String} arguments(n) [The name of event.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "on": function() {
                    // cache the object
                    var _ = this;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // add the option, if it doesn't exists
                    if (!_.options.events) _.options.events = [];
                    // normalize the mousewheel event although the wheel
                    // event should be used:
                    // {https://developer.mozilla.org/en-US/docs/Web/Events/wheel}
                    var args = to_array(arguments),
                        is_ff = /Firefox/.test(navigator.userAgent);
                    args = args.map(function(event) {
                        return ((is_ff && event === "mousewheel") ? "DOMMouseScroll" : event);
                    });
                    // add the best determined event constructor to each event
                    //
                    // supported events are listed below. check what event constructor your specific event needs
                    // as non detected events (anything else that is not listed below) will result in the default
                    // Event constructor. for other events refer to:
                    // [https://developer.mozilla.org/en-US/docs/Web/Events#Standard_events]
                    var UIEvent = " abort error load resize scroll select unload ",
                        MouseEvent = " click contextmenu dblclick mousedown mouseenter mouseleave mousemove mouseout mouseover mouseup show ",
                        // custom library events list:
                        // supports a primitive mutation implementation w/ possible future support of the bottom custom events:
                        // dimensionchange widthchange heightchange contentflowchange contentoverflow contentunderflow
                        LibraryEvent = " mutation ",
                        func;
                    for (var i = 0, l = args.length; i < l; i++) {
                        // cache the current event
                        var event = args[i].toLowerCase();
                        // check if a function constructor name was provided
                        // if one was provided, that one will be used. otherwise,
                        // we do our best to determine what to use.
                        if (event.charAt(0) !== ":") {
                            // determine what best to use...
                            if (-~UIEvent.indexOf(" " + event + " ")) func = "UIEvent";
                            else if (-~MouseEvent.indexOf(" " + event + " ")) func = "MouseEvent";
                            else if (-~LibraryEvent.indexOf(" " + event + " ")) func = "LibraryEvent";
                            else func = "Event"; // default
                        } else func = "CustomEvent";
                        // amend the argument
                        args[i] = [event, func];
                    }
                    // add events to array
                    // {http://stackoverflow.com/a/15444261}
                    Array.prototype.push.apply(_.options.events, args);
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds event namespace to options object.]
                 * @param  {String} namespace [The namespace.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "namespace": function(namespace) {
                    // cache the object
                    var _ = this;
                    // provided namespace must be of specified type
                    // if not, stop function execution
                    if (namespace && dtype.isnot(namespace, "string")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.namespace = namespace;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the elements to which to bind the events to.]
                 * @param  {String|HTMLElement} arguments(n) [The element nodes or
                 *                                            #ID of elements to bind events to.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "anchors": function() {
                    // cache the object
                    var _ = this;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // add the option, if it doesn't exists
                    if (!_.options.anchors) _.options.anchors = [];
                    // add anchors to array
                    // {http://stackoverflow.com/a/15444261}
                    Array.prototype.push.apply(_.options.anchors, to_array(arguments));
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [If using event delegation the filters act as middlware.
                 *               In the sense that they are run before the handler only
                 *               if the filter function returns true.]
                 * @param  {String} arguments(n) [The name of the filters to use.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "filters": function() {
                    // cache the object
                    var _ = this;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // add the option, if it doesn't exists
                    if (!_.options.filters) _.options.filters = [];
                    // add filters to array
                    // {http://stackoverflow.com/a/15444261}
                    var filter_names = to_array(arguments),
                        filters = [];
                    for (var i = 0, l = filter_names.length; i < l; i++) {
                        // define the current filter name
                        var name = filter_names[i],
                            // delegation return type
                            return_type = "self",
                            // check for special delegation return type
                            // will default to "self" if none is found
                            position = index(name, "@");
                        // check for filter return type
                        if (indexed(position)) {
                            // get the return type
                            return_type = name.substring(position + 1, name.length);
                            // reset the name to exclude the return type
                            name = name.substring(0, position);
                        }
                        // get the filter function
                        var filter = registry.filters[name];
                        // if the function exists, add it to the filters for the
                        // interaction
                        if (filter) {
                            filters.push([filter, return_type, name]);
                        }
                    }
                    // add filters to array
                    // {http://stackoverflow.com/a/15444261}
                    Array.prototype.push.apply(_.options.filters, filters);
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the event handler fire count to the options object.]
                 * @param  {Number} fire_count [The handler fire count.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "fireCount": function(fire_count) {
                    // cache the object
                    var _ = this;
                    // provided fireCount must be of specified type
                    // if not, stop function execution
                    if (fire_count && dtype.isnot(fire_count, "number")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.fireCount = fire_count;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the capture flag to options object.
                 *               Flag indicates whether the event captures or not.]
                 * @param  {Boolean} flag [Bool indicating whether to capture.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "capture": function(flag) {
                    // cache the object
                    var _ = this;
                    // provided flag must be of specified type
                    // if not, stop function execution
                    if (flag && dtype.isnot(flag, "boolean")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.capture = flag;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the passive flag to options object.
                 *               Flag indicates whether the event should be passive or not.]
                 * @param  {Boolean} flag [Bool indicating whether to capture.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "passive": function(flag) {
                    // cache the object
                    var _ = this;
                    // provided flag must be of specified type
                    // if not, stop function execution
                    if (flag && dtype.isnot(flag, "boolean")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.passive = flag;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the debounce time to options object.
                 *               Flag indicates whether the handler should be debounced.]
                 * @param  {Number} time [Time to debounce handler by.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "debounce": function(time) {
                    // cache the object
                    var _ = this;
                    // provided time must be of specified type
                    // if not, stop function execution
                    if (time && dtype.isnot(time, "number")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.debounce = time;
                    // set throttle flag to false
                    _.options.throttle = false;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the throttle time to options object.
                 *               Flag indicates whether the handler should be throttled.]
                 * @param  {Number} time [Time to throttle handler by.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "throttle": function(time) {
                    // cache the object
                    var _ = this;
                    // provided time must be of specified type
                    // if not, stop function execution
                    if (time && dtype.isnot(time, "number")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // set the option
                    _.options.throttle = time;
                    // set throttle flag to false
                    _.options.debounce = false;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Adds the event handler function to the options object.]
                 * @param {String} name [The name of the handler.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "handler": function(name) {
                    // cache the object
                    var _ = this;
                    // provided name must be of specified type
                    // if not, stop function execution
                    if (name && dtype.isnot(name, "string")) return _;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // get the handler
                    var handler = registry.handlers[name];
                    if (!handler) return;
                    // set the option
                    _.options.handler = handler;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Enables the Interaction.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "enable": function() {
                    // cache the object
                    var _ = this;
                    // if event has not been created, create it
                    if (!_.properties.created) {
                        // get the Interaction object
                        // normalize the options
                        var options = normalized(_);
                        // get normalized options
                        var id = options.id,
                            anchors = options.anchors,
                            events = options.events,
                            namespace = options.namespace,
                            filters = options.filters,
                            fire_count = options.fireCount,
                            handler = options.handler,
                            // https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
                            options_ = {
                                "capture": options.capture,
                                "passive": options.passive
                            };
                        // set the fireCount to the properties
                        _.properties.fireCount = fire_count;
                        // loop over anchors
                        for (var i = 0, l = anchors.length; i < l; i++) {
                            // cache the current anchor
                            var anchor = anchors[i];
                            // loop over events
                            for (var j = 0, ll = events.length; j < ll; j++) {
                                // cache the current event
                                var event = events[j];
                                var event_name = event[0];
                                var event_type = event[1];
                                // attach the event
                                create_event(_, id, anchor, event_name, event_type, namespace, fire_count, handler, options_, filters);
                            }
                        }
                    }
                    // finally, enable the object to allow the interaction to run
                    _.properties.enabled = true;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Disables the interaction.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "disable": function() {
                    // cache the object
                    var _ = this;
                    // set the option
                    _.properties.enabled = false;
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Unbinds the event(s) from its anchors.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "remove": function() {
                    // cache the object
                    var _ = this,
                        properties = _.properties;
                    // if the object has not been created
                    // there is no event to remove. simple unstore
                    // the event object from the stored interactions.
                    if (!_.properties.created) {
                        // remove the event from the pool
                        //
                        // cache the interactions from registry
                        var interactions = registry.interactions;
                        //
                        // get the objects position in the interactions array
                        var position = index(interactions, _);
                        //
                        // if index exists remove event object from array
                        if (indexed(position)) interactions.splice(position, 1);
                        // set the removed property, in the case the user
                        // still has a reference to it. however, the library
                        // will no longer be tracking the event as it is no
                        // longer in the registry
                        properties.removed = true;
                    } else { // else...remove the event listener
                        // remove the event
                        zeroed(_);
                    }
                    // return self to chain methods
                    return _;
                },
                /**
                 * @description [Resets the provided interaction options.]
                 * @param {String} arguments [The N amount of properties to reset.]
                 * @return {Undefined}     [Nothing is returned.]
                 */
                "reset": function() {
                    // cache the object
                    var _ = this,
                        defaults = _.defaults,
                        options = _.options;
                    // option cannot be set if object has been enabled
                    if (_.properties.locked) return _;
                    // get the properties in need of a reset
                    var args = to_array(arguments);
                    // loop over args and reset
                    for (var i = 0, l = args.length; i < l; i++) {
                        // cache the property
                        var prop = args[i];
                        // check that the property is indeed a library prop
                        if (prop in defaults && defaults.hasOwnProperty(prop)) {
                            // reset the property
                            options[prop] = defaults[prop];
                        }
                    }
                    // return self to chain methods
                    return _;
                }
            },
            // class to extend
            "extend__": false
        });
        // return library to add to global scope later...
        return Library;
    })();
    // =============================== Global Library Functions/Methods/Vars
    // registry to track of interactions, filters, and handlers
    var registry = {
        "interactions": [],
        "filters": {},
        "handlers": {}
    };
    /**
     * @description [Returns all interactions.]
     * @return {Array} [The interactions in an array.]
     */
    library.interactions = function() {
        return registry.interactions;
    };
    /**
     * @description [Returns all interactions where the provided element was used as an anchor.]
     * @return {Array} [An array of the interactions where the provided element was used as an anchor.]
     */
    library.interactionsFor = function(anchor) {
        // get the interactions
        var interactions = library.interactions(),
            list = [];
        // loop over interactions...
        for (var i = 0, l = interactions.length; i < l; i++) {
            // cache the interaction...
            var interaction = interactions[i];
            // cache the anchors list
            var anchors = interaction.options.anchors;
            // add the interaction to the list...
            if (-~anchors.indexOf(anchor)) list.push(interaction);
        }
        // return the associated interactions
        return list;
    };
    /**
     * @description [Gets the interaction with the provided ID.]
     * @param {String} name   [The interaction ID.]
     * @return {Null|Object} [The interaction if found or null if otherwise.]
     */
    library.interaction = function(id) {
        // return if no ID provided
        if (!id) return null;
        // get the interactions
        var interactions = library.interactions();
        // loop over interactions until the ID is matched...
        for (var i = 0, l = interactions.length; i < l; i++) {
            // cache the interaction...
            var interaction = interactions[i];
            if (interaction.options.id === id) {
                // return the interaction
                return interaction;
            }
        }
        return null; // no interaction found
    };
    /**
     * @description [Creates the synthetic event used by the trigger method.]
     * @param  {String} type         [The event name.]
     * @param  {String} func         [The event's event constructor function name.]
     * @param  {HTMLElement} anchor  [The anchor the event is bound to.]
     * @param  {Object} options      [The event options to use.]
     * @return {EventObject}         [The newly created synthetic event object.]
     */
    function create_event_object(type, func, anchor, options) {
        // create the event object
        var event;
        if (func === "LibraryEvent") { // mutation event
            event = new CustomEvent(type, {
                detail: {
                    "data": (options.data || null)
                }
            });
        } else { // custom event via constructor
            event = new window[func](type, Object.assign({
                "bubbles": true,
                "cancelable": false,
                "scoped": false,
                "composed": false,
                // "detail": data // a custom "data" property is used instead (▼ below)
            }, (options.options || {})));
        }
        // add the func type to distinguish in Library.trigger() if it's a LibraryEvent or
        // an actual EventConstructor --> new window[func]...
        event.syntheticType = func;
        // add custom properties to synthetic event object
        //
        // custom isSynthetic property denotes the event is a synthetic event
        event.isSynthetic = true;
        // custom data property contains the provided data, is provided
        event.data = (options.data || null);
        // create the targets object
        var targets = Object.assign({
            "target": null,
            "currentTarget": anchor,
            "relatedTarget": null,
            "srcElement": null,
            "fromElement": null,
            "toElement": null,
            "explicitOriginalTarget": null,
            "originalTarget": null
        }, (options.targets || {}));
        // add the targets to the event object
        // **Note: they are added as a single object as the actual
        // targets are read-only and cannot be modified. they are
        // looked up in the "create_event" event.
        event.targets = targets;
        // return the synthetic event object
        return event;
    }
    /**
     * @description [Trigger an interaction.]
     * @param  {String} id           [The ID of the interaction to trigger.]
     * @param  {Object} arguments[1] [The event options to use.]
     * @return {Undefined}           [Nothing is returned.]
     */
    library.trigger = function(id) {
        // get the interaction
        var interaction = library.interaction(id);
        // if no interaction is found, return
        if (!interaction) return;
        // cache the interaction options, properties
        var opts = interaction.options,
            properties = interaction.properties;
        // get the anchors, events, handlers from the interaction
        var anchors = opts.anchors,
            events = opts.events,
            handler = properties.handlers[0];
        // cache the options argument
        var options = (arguments[1] || {});
        // run the handler
        for (var i = 0, l = anchors.length; i < l; i++) {
            for (var j = 0, ll = events.length; j < ll; j++) {
                // create the event object
                var event = create_event_object(events[j][0], events[j][1], anchors[i], options);
                // call the event handler
                if (event.syntheticType === "LibraryEvent") {
                    anchors[i].dispatchEvent(event);
                } else { // CustomEvent made with constructor
                    handler.call(event, event);
                }
            }
        }
    };
    /**
     * @description [Disables all interactions.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.disableAll = function() {
        // get the interactions
        var interactions = library.interactions();
        // loop over interactions...
        for (var i = 0, l = interactions.length; i < l; i++) {
            // cache the interaction...
            var interaction = interactions[i];
            // disable the interaction
            interaction.disable();
        }
    };
    /**
     * @description [Enables all interactions.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.enableAll = function() {
        // get the interactions
        var interactions = library.interactions();
        // loop over interactions...
        for (var i = 0, l = interactions.length; i < l; i++) {
            // cache the interaction...
            var interaction = interactions[i];
            // enable the interaction
            interaction.enable();
        }
    };
    /**
     * @description [Remove specific interaction.]
     * @param {String} id   [The interaction ID.]
     * @return {Boolean} [Boolean indicating whether the interaction was removed or not.]
     */
    library.remove = function(id) {
        // return if no ID provided
        if (!id) return false;
        // get the interactions
        var interactions = library.interactions();
        // loop over interactions until the ID is matched...
        for (var i = 0, l = interactions.length; i < l; i++) {
            // cache the interaction...
            var interaction = interactions[i];
            if (interaction.options.id === id) {
                // remove interaction...
                interaction.remove();
                return true; // the interaction was removed!
            }
        }
        return false; // no interaction removed
    };
    /**
     * @description [Removes all interactions.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.removeAll = function() {
        // get the interactions
        var interactions = library.interactions();
        // loop over interactions until the ID is matched...
        // **loop in reverse as the interaction remove method
        // mutates the interactions array and therefore changes
        // the arrays length.
        for (var i = (interactions.length - 1); i >= 0; i--) {
            // remove interaction...
            interactions[i].remove();
        }
    };
    /**
     * @description [Returns all handlers.]
     * @return {Array} [The handlers in an array.]
     */
    library.handlers = function() {
        return registry.handlers;
    };
    /**
     * @description [Returns all filters.]
     * @return {Array} [The filters in an array.]
     */
    library.filters = function() {
        return registry.filters;
    };
    /**
     * @description [Add a delegation filter.]
     * @param {String} name   [The name of the filter.]
     * @param {Function} filter [The filter function.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.addFilter = function(name, filter) {
        registry.filters[name] = filter; // store the filter
    };
    /**
     * @description [Remove a delegation filter.]
     * @param {String} name   [The name of the filter.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.removeFilter = function(name) {
        delete registry.filters[name]; // remove the handler
    };
    /**
     * @description [Add a handler.]
     * @param {String} name   [The name of the handler.]
     * @param {Function} handler [The handler function.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.addHandler = function(name, handler) {
        registry.handlers[name] = handler; // store the handler
    };
    /**
     * @description [Remove a handler.]
     * @param {String} name   [The name of the handler.]
     * @return {Undefined}     [Nothing is returned.]
     */
    library.removeHandler = function(name, handler) {
        delete registry.handlers[name]; // remove the handler
    };
    // =============================== Attach Library To Global Scope
    // add to global scope for ease of use
    // use global app var or create it if not present
    var app = window.app || (window.app = {});
    // get the libs object from within the app object
    // if it does not exist create it
    var libs = app.libs || (app.libs = {});
    // add the library to the libs object
    libs.Interaction = library;
    // IIFE end
})(window);

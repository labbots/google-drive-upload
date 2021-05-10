(function () {
    'use strict';

    function noop() { }
    const identity = x => x;
    function run(fn) {
        return fn();
    }
    function blank_object() {
        return Object.create(null);
    }
    function run_all(fns) {
        fns.forEach(run);
    }
    function is_function(thing) {
        return typeof thing === 'function';
    }
    function safe_not_equal(a, b) {
        return a != a ? b == b : a !== b || ((a && typeof a === 'object') || typeof a === 'function');
    }

    const is_client = typeof window !== 'undefined';
    let now = is_client
        ? () => window.performance.now()
        : () => Date.now();
    let raf = cb => requestAnimationFrame(cb);

    const tasks = new Set();
    let running = false;
    function run_tasks() {
        tasks.forEach(task => {
            if (!task[0](now())) {
                tasks.delete(task);
                task[1]();
            }
        });
        running = tasks.size > 0;
        if (running)
            raf(run_tasks);
    }
    function loop(fn) {
        let task;
        if (!running) {
            running = true;
            raf(run_tasks);
        }
        return {
            promise: new Promise(fulfil => {
                tasks.add(task = [fn, fulfil]);
            }),
            abort() {
                tasks.delete(task);
            }
        };
    }

    function append(target, node) {
        target.appendChild(node);
    }
    function insert(target, node, anchor) {
        target.insertBefore(node, anchor || null);
    }
    function detach(node) {
        node.parentNode.removeChild(node);
    }
    function destroy_each(iterations, detaching) {
        for (let i = 0; i < iterations.length; i += 1) {
            if (iterations[i])
                iterations[i].d(detaching);
        }
    }
    function element(name) {
        return document.createElement(name);
    }
    function text(data) {
        return document.createTextNode(data);
    }
    function space() {
        return text(' ');
    }
    function empty() {
        return text('');
    }
    function listen(node, event, handler, options) {
        node.addEventListener(event, handler, options);
        return () => node.removeEventListener(event, handler, options);
    }
    function attr(node, attribute, value) {
        if (value == null)
            node.removeAttribute(attribute);
        else
            node.setAttribute(attribute, value);
    }
    function children(element) {
        return Array.from(element.childNodes);
    }
    function set_data(text, data) {
        data = '' + data;
        if (text.data !== data)
            text.data = data;
    }
    function toggle_class(element, name, toggle) {
        element.classList[toggle ? 'add' : 'remove'](name);
    }
    function custom_event(type, detail) {
        const e = document.createEvent('CustomEvent');
        e.initCustomEvent(type, false, false, detail);
        return e;
    }

    let stylesheet;
    let active = 0;
    let current_rules = {};
    // https://github.com/darkskyapp/string-hash/blob/master/index.js
    function hash(str) {
        let hash = 5381;
        let i = str.length;
        while (i--)
            hash = ((hash << 5) - hash) ^ str.charCodeAt(i);
        return hash >>> 0;
    }
    function create_rule(node, a, b, duration, delay, ease, fn, uid = 0) {
        const step = 16.666 / duration;
        let keyframes = '{\n';
        for (let p = 0; p <= 1; p += step) {
            const t = a + (b - a) * ease(p);
            keyframes += p * 100 + `%{${fn(t, 1 - t)}}\n`;
        }
        const rule = keyframes + `100% {${fn(b, 1 - b)}}\n}`;
        const name = `__svelte_${hash(rule)}_${uid}`;
        if (!current_rules[name]) {
            if (!stylesheet) {
                const style = element('style');
                document.head.appendChild(style);
                stylesheet = style.sheet;
            }
            current_rules[name] = true;
            stylesheet.insertRule(`@keyframes ${name} ${rule}`, stylesheet.cssRules.length);
        }
        const animation = node.style.animation || '';
        node.style.animation = `${animation ? `${animation}, ` : ``}${name} ${duration}ms linear ${delay}ms 1 both`;
        active += 1;
        return name;
    }
    function delete_rule(node, name) {
        node.style.animation = (node.style.animation || '')
            .split(', ')
            .filter(name
                ? anim => anim.indexOf(name) < 0 // remove specific animation
                : anim => anim.indexOf('__svelte') === -1 // remove all Svelte animations
            )
            .join(', ');
        if (name && !--active)
            clear_rules();
    }
    function clear_rules() {
        raf(() => {
            if (active)
                return;
            let i = stylesheet.cssRules.length;
            while (i--)
                stylesheet.deleteRule(i);
            current_rules = {};
        });
    }

    let current_component;
    function set_current_component(component) {
        current_component = component;
    }
    function get_current_component() {
        if (!current_component)
            throw new Error(`Function called outside component initialization`);
        return current_component;
    }
    function onMount(fn) {
        get_current_component().$$.on_mount.push(fn);
    }
    function createEventDispatcher() {
        const component = current_component;
        return (type, detail) => {
            const callbacks = component.$$.callbacks[type];
            if (callbacks) {
                // TODO are there situations where events could be dispatched
                // in a server (non-DOM) environment?
                const event = custom_event(type, detail);
                callbacks.slice().forEach(fn => {
                    fn.call(component, event);
                });
            }
        };
    }

    const dirty_components = [];
    const resolved_promise = Promise.resolve();
    let update_scheduled = false;
    const binding_callbacks = [];
    const render_callbacks = [];
    const flush_callbacks = [];
    function schedule_update() {
        if (!update_scheduled) {
            update_scheduled = true;
            resolved_promise.then(flush);
        }
    }
    function add_render_callback(fn) {
        render_callbacks.push(fn);
    }
    function flush() {
        const seen_callbacks = new Set();
        do {
            // first, call beforeUpdate functions
            // and update components
            while (dirty_components.length) {
                const component = dirty_components.shift();
                set_current_component(component);
                update(component.$$);
            }
            while (binding_callbacks.length)
                binding_callbacks.shift()();
            // then, once components are updated, call
            // afterUpdate functions. This may cause
            // subsequent updates...
            while (render_callbacks.length) {
                const callback = render_callbacks.pop();
                if (!seen_callbacks.has(callback)) {
                    callback();
                    // ...so guard against infinite loops
                    seen_callbacks.add(callback);
                }
            }
        } while (dirty_components.length);
        while (flush_callbacks.length) {
            flush_callbacks.pop()();
        }
        update_scheduled = false;
    }
    function update($$) {
        if ($$.fragment) {
            $$.update($$.dirty);
            run_all($$.before_render);
            $$.fragment.p($$.dirty, $$.ctx);
            $$.dirty = null;
            $$.after_render.forEach(add_render_callback);
        }
    }

    let promise;
    function wait() {
        if (!promise) {
            promise = Promise.resolve();
            promise.then(() => {
                promise = null;
            });
        }
        return promise;
    }
    function dispatch(node, direction, kind) {
        node.dispatchEvent(custom_event(`${direction ? 'intro' : 'outro'}${kind}`));
    }
    const outroing = new Set();
    let outros;
    function group_outros() {
        outros = {
            remaining: 0,
            callbacks: []
        };
    }
    function check_outros() {
        if (!outros.remaining) {
            run_all(outros.callbacks);
        }
    }
    function transition_in(block, local) {
        if (block && block.i) {
            outroing.delete(block);
            block.i(local);
        }
    }
    function transition_out(block, local, callback) {
        if (block && block.o) {
            if (outroing.has(block))
                return;
            outroing.add(block);
            outros.callbacks.push(() => {
                outroing.delete(block);
                if (callback) {
                    block.d(1);
                    callback();
                }
            });
            block.o(local);
        }
    }
    function create_bidirectional_transition(node, fn, params, intro) {
        let config = fn(node, params);
        let t = intro ? 0 : 1;
        let running_program = null;
        let pending_program = null;
        let animation_name = null;
        function clear_animation() {
            if (animation_name)
                delete_rule(node, animation_name);
        }
        function init(program, duration) {
            const d = program.b - t;
            duration *= Math.abs(d);
            return {
                a: t,
                b: program.b,
                d,
                duration,
                start: program.start,
                end: program.start + duration,
                group: program.group
            };
        }
        function go(b) {
            const { delay = 0, duration = 300, easing = identity, tick: tick$$1 = noop, css } = config;
            const program = {
                start: now() + delay,
                b
            };
            if (!b) {
                // @ts-ignore todo: improve typings
                program.group = outros;
                outros.remaining += 1;
            }
            if (running_program) {
                pending_program = program;
            }
            else {
                // if this is an intro, and there's a delay, we need to do
                // an initial tick and/or apply CSS animation immediately
                if (css) {
                    clear_animation();
                    animation_name = create_rule(node, t, b, duration, delay, easing, css);
                }
                if (b)
                    tick$$1(0, 1);
                running_program = init(program, duration);
                add_render_callback(() => dispatch(node, b, 'start'));
                loop(now$$1 => {
                    if (pending_program && now$$1 > pending_program.start) {
                        running_program = init(pending_program, duration);
                        pending_program = null;
                        dispatch(node, running_program.b, 'start');
                        if (css) {
                            clear_animation();
                            animation_name = create_rule(node, t, running_program.b, running_program.duration, 0, easing, config.css);
                        }
                    }
                    if (running_program) {
                        if (now$$1 >= running_program.end) {
                            tick$$1(t = running_program.b, 1 - t);
                            dispatch(node, running_program.b, 'end');
                            if (!pending_program) {
                                // we're done
                                if (running_program.b) {
                                    // intro — we can tidy up immediately
                                    clear_animation();
                                }
                                else {
                                    // outro — needs to be coordinated
                                    if (!--running_program.group.remaining)
                                        run_all(running_program.group.callbacks);
                                }
                            }
                            running_program = null;
                        }
                        else if (now$$1 >= running_program.start) {
                            const p = now$$1 - running_program.start;
                            t = running_program.a + running_program.d * easing(p / running_program.duration);
                            tick$$1(t, 1 - t);
                        }
                    }
                    return !!(running_program || pending_program);
                });
            }
        }
        return {
            run(b) {
                if (is_function(config)) {
                    wait().then(() => {
                        // @ts-ignore
                        config = config();
                        go(b);
                    });
                }
                else {
                    go(b);
                }
            },
            end() {
                clear_animation();
                running_program = pending_program = null;
            }
        };
    }
    function mount_component(component, target, anchor) {
        const { fragment, on_mount, on_destroy, after_render } = component.$$;
        fragment.m(target, anchor);
        // onMount happens after the initial afterUpdate. Because
        // afterUpdate callbacks happen in reverse order (inner first)
        // we schedule onMount callbacks before afterUpdate callbacks
        add_render_callback(() => {
            const new_on_destroy = on_mount.map(run).filter(is_function);
            if (on_destroy) {
                on_destroy.push(...new_on_destroy);
            }
            else {
                // Edge case - component was destroyed immediately,
                // most likely as a result of a binding initialising
                run_all(new_on_destroy);
            }
            component.$$.on_mount = [];
        });
        after_render.forEach(add_render_callback);
    }
    function destroy_component(component, detaching) {
        if (component.$$.fragment) {
            run_all(component.$$.on_destroy);
            if (detaching)
                component.$$.fragment.d(1);
            // TODO null out other refs, including component.$$ (but need to
            // preserve final state?)
            component.$$.on_destroy = component.$$.fragment = null;
            component.$$.ctx = {};
        }
    }
    function make_dirty(component, key) {
        if (!component.$$.dirty) {
            dirty_components.push(component);
            schedule_update();
            component.$$.dirty = blank_object();
        }
        component.$$.dirty[key] = true;
    }
    function init(component, options, instance, create_fragment, not_equal$$1, prop_names) {
        const parent_component = current_component;
        set_current_component(component);
        const props = options.props || {};
        const $$ = component.$$ = {
            fragment: null,
            ctx: null,
            // state
            props: prop_names,
            update: noop,
            not_equal: not_equal$$1,
            bound: blank_object(),
            // lifecycle
            on_mount: [],
            on_destroy: [],
            before_render: [],
            after_render: [],
            context: new Map(parent_component ? parent_component.$$.context : []),
            // everything else
            callbacks: blank_object(),
            dirty: null
        };
        let ready = false;
        $$.ctx = instance
            ? instance(component, props, (key, value) => {
                if ($$.ctx && not_equal$$1($$.ctx[key], $$.ctx[key] = value)) {
                    if ($$.bound[key])
                        $$.bound[key](value);
                    if (ready)
                        make_dirty(component, key);
                }
            })
            : props;
        $$.update();
        ready = true;
        run_all($$.before_render);
        $$.fragment = create_fragment($$.ctx);
        if (options.target) {
            if (options.hydrate) {
                // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
                $$.fragment.l(children(options.target));
            }
            else {
                // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
                $$.fragment.c();
            }
            if (options.intro)
                transition_in(component.$$.fragment);
            mount_component(component, options.target, options.anchor);
            flush();
        }
        set_current_component(parent_component);
    }
    class SvelteComponent {
        $destroy() {
            destroy_component(this, 1);
            this.$destroy = noop;
        }
        $on(type, callback) {
            const callbacks = (this.$$.callbacks[type] || (this.$$.callbacks[type] = []));
            callbacks.push(callback);
            return () => {
                const index = callbacks.indexOf(callback);
                if (index !== -1)
                    callbacks.splice(index, 1);
            };
        }
        $set() {
            // overridden by instance, if it has props
        }
    }

    function unwrapExports(x) {
        return x && x.__esModule && Object.prototype.hasOwnProperty.call(x, 'default') ? x['default'] : x;
    }

    function createCommonjsModule(fn, module) {
        return module = { exports: {} }, fn(module, module.exports), module.exports;
    }

    var cookieUniversalCommon = createCommonjsModule(function (module) {
        module.exports = function (e) { function t(o) { if (r[o]) return r[o].exports; var n = r[o] = { i: o, l: !1, exports: {} }; return e[o].call(n.exports, n, n.exports, t), n.l = !0, n.exports } var r = {}; return t.m = e, t.c = r, t.d = function (e, r, o) { t.o(e, r) || Object.defineProperty(e, r, { configurable: !1, enumerable: !0, get: o }); }, t.n = function (e) { var r = e && e.__esModule ? function () { return e.default } : function () { return e }; return t.d(r, "a", r), r }, t.o = function (e, t) { return Object.prototype.hasOwnProperty.call(e, t) }, t.p = "", t(t.s = 0) }([function (e, t, r) { var o = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (e) { return typeof e } : function (e) { return e && "function" == typeof Symbol && e.constructor === Symbol && e !== Symbol.prototype ? "symbol" : typeof e }, n = r(1); e.exports = function (t, r) { var i = !(arguments.length > 2 && void 0 !== arguments[2]) || arguments[2], a = "object" === ("undefined" == typeof document ? "undefined" : o(document)) && "string" == typeof document.cookie, s = "object" === (void 0 === t ? "undefined" : o(t)) && "object" === (void 0 === r ? "undefined" : o(r)) && void 0 !== e, u = !a && !s || a && s, f = function (e) { if (s) { var o = t.headers.cookie || ""; return e && (o = r.getHeaders(), o = o["set-cookie"] ? o["set-cookie"].map(function (e) { return e.split(";")[0] }).join(";") : ""), o } if (a) return document.cookie || "" }, c = function () { var e = r.getHeader("Set-Cookie"); return (e = "string" == typeof e ? [e] : e) || [] }, p = function (e) { return r.setHeader("Set-Cookie", e) }, d = function (e, t) { if (!t) return e; try { return JSON.parse(e) } catch (t) { return e } }, l = { parseJSON: i, set: function () { var e = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : "", t = arguments.length > 1 && void 0 !== arguments[1] ? arguments[1] : "", r = arguments.length > 2 && void 0 !== arguments[2] ? arguments[2] : { path: "/" }; if (!u) if (t = "object" === (void 0 === t ? "undefined" : o(t)) ? JSON.stringify(t) : t, s) { var i = c(); i.push(n.serialize(e, t, r)), p(i); } else document.cookie = n.serialize(e, t, r); }, setAll: function () { var e = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : []; u || Array.isArray(e) && e.forEach(function (e) { var t = e.name, r = void 0 === t ? "" : t, o = e.value, n = void 0 === o ? "" : o, i = e.opts, a = void 0 === i ? { path: "/" } : i; l.set(r, n, a); }); }, get: function () { var e = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : "", t = arguments.length > 1 && void 0 !== arguments[1] ? arguments[1] : { fromRes: !1, parseJSON: l.parseJSON }; if (u) return ""; var r = n.parse(f(t.fromRes)), o = r[e]; return d(o, t.parseJSON) }, getAll: function () { var e = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : { fromRes: !1, parseJSON: l.parseJSON }; if (u) return {}; var t = n.parse(f(e.fromRes)); for (var r in t) t[r] = d(t[r], e.parseJSON); return t }, remove: function () { var e = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : "", t = arguments.length > 1 && void 0 !== arguments[1] ? arguments[1] : { path: "/" }; if (!u) { var r = l.get(e); t.expires = new Date(0), r && l.set(e, "", t); } }, removeAll: function () { if (!u) { var e = n.parse(f()); for (var t in e) l.remove(t); } }, nodeCookie: n }; return l }; }, function (e, t, r) {
            function o(e, t) { if ("string" != typeof e) throw new TypeError("argument str must be a string"); for (var r = {}, o = t || {}, n = e.split(u), s = o.decode || a, f = 0; f < n.length; f++) { var c = n[f], p = c.indexOf("="); if (!(p < 0)) { var d = c.substr(0, p).trim(), l = c.substr(++p, c.length).trim(); '"' == l[0] && (l = l.slice(1, -1)), void 0 == r[d] && (r[d] = i(l, s)); } } return r } function n(e, t, r) { var o = r || {}, n = o.encode || s; if ("function" != typeof n) throw new TypeError("option encode is invalid"); if (!f.test(e)) throw new TypeError("argument name is invalid"); var i = n(t); if (i && !f.test(i)) throw new TypeError("argument val is invalid"); var a = e + "=" + i; if (null != o.maxAge) { var u = o.maxAge - 0; if (isNaN(u)) throw new Error("maxAge should be a Number"); a += "; Max-Age=" + Math.floor(u); } if (o.domain) { if (!f.test(o.domain)) throw new TypeError("option domain is invalid"); a += "; Domain=" + o.domain; } if (o.path) { if (!f.test(o.path)) throw new TypeError("option path is invalid"); a += "; Path=" + o.path; } if (o.expires) { if ("function" != typeof o.expires.toUTCString) throw new TypeError("option expires is invalid"); a += "; Expires=" + o.expires.toUTCString(); } if (o.httpOnly && (a += "; HttpOnly"), o.secure && (a += "; Secure"), o.sameSite) { switch ("string" == typeof o.sameSite ? o.sameSite.toLowerCase() : o.sameSite) { case !0: a += "; SameSite=Strict"; break; case "lax": a += "; SameSite=Lax"; break; case "strict": a += "; SameSite=Strict"; break; default: throw new TypeError("option sameSite is invalid") } } return a } function i(e, t) { try { return t(e) } catch (t) { return e } }/*!
     * cookie
     * Copyright(c) 2012-2014 Roman Shtylman
     * Copyright(c) 2015 Douglas Christopher Wilson
     * MIT Licensed
     */
            t.parse = o, t.serialize = n; var a = decodeURIComponent, s = encodeURIComponent, u = /; */, f = /^[\u0009\u0020-\u007e\u0080-\u00ff]+$/;
        }]);
    });

    var Cookie = unwrapExports(cookieUniversalCommon);

    var validate = function (choice, cookie) {
        const choices = Object.keys(choice);
        const chosen = Object.keys(cookie.choices);

        if (chosen.length !== choices.length) {
            return false
        }

        return chosen.every(c => choices.includes(c))
    };

    function fade(node, { delay = 0, duration = 400 }) {
        const o = +getComputedStyle(node).opacity;
        return {
            delay,
            duration,
            css: t => `opacity: ${t * o}`
        };
    }

    /* src/components/Banner.svelte generated by Svelte v3.5.4 */

    function get_each_context(ctx, list, i) {
        const child_ctx = Object.create(ctx);
        child_ctx.choice = list[i];
        return child_ctx;
    }

    // (125:0) {#if showEditIcon}
    function create_if_block_3(ctx) {
        var button, button_transition, current, dispose;

        return {
            c() {
                button = element("button");
                button.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path d="M510.52 255.82c-69.97-.85-126.47-57.69-126.47-127.86-70.17
			        0-127-56.49-127.86-126.45-27.26-4.14-55.13.3-79.72 12.82l-69.13
			        35.22a132.221 132.221 0 0 0-57.79 57.81l-35.1 68.88a132.645 132.645 0 0
			        0-12.82 80.95l12.08 76.27a132.521 132.521 0 0 0 37.16 72.96l54.77
			        54.76a132.036 132.036 0 0 0 72.71 37.06l76.71 12.15c27.51 4.36 55.7-.11
			        80.53-12.76l69.13-35.21a132.273 132.273 0 0 0
			        57.79-57.81l35.1-68.88c12.56-24.64 17.01-52.58 12.91-79.91zM176
			        368c-17.67 0-32-14.33-32-32s14.33-32 32-32 32 14.33 32 32-14.33 32-32
			        32zm32-160c-17.67 0-32-14.33-32-32s14.33-32 32-32 32 14.33 32 32-14.33
			        32-32 32zm160 128c-17.67 0-32-14.33-32-32s14.33-32 32-32 32 14.33 32
			        32-14.33 32-32 32z"></path></svg>`;
                attr(button, "class", "cookieConsentToggle");
                dispose = listen(button, "click", ctx.click_handler);
            },

            m(target, anchor) {
                insert(target, button, anchor);
                current = true;
            },

            i(local) {
                if (current) return;
                add_render_callback(() => {
                    if (!button_transition) button_transition = create_bidirectional_transition(button, fade, {}, true);
                    button_transition.run(1);
                });

                current = true;
            },

            o(local) {
                if (!button_transition) button_transition = create_bidirectional_transition(button, fade, {}, false);
                button_transition.run(0);

                current = false;
            },

            d(detaching) {
                if (detaching) {
                    detach(button);
                    if (button_transition) button_transition.end();
                }

                dispose();
            }
        };
    }

    // (147:0) {#if shown}
    function create_if_block_2(ctx) {
        var div4, div3, div1, div0, p0, t0, t1, p1, t2, div2, button0, t3, t4, button1, t5, div4_transition, current, dispose;

        return {
            c() {
                div4 = element("div");
                div3 = element("div");
                div1 = element("div");
                div0 = element("div");
                p0 = element("p");
                t0 = text(ctx.heading);
                t1 = space();
                p1 = element("p");
                t2 = space();
                div2 = element("div");
                button0 = element("button");
                t3 = text(ctx.settingsLabel);
                t4 = space();
                button1 = element("button");
                t5 = text(ctx.acceptLabel);
                attr(p0, "class", "cookieConsent__Title");
                attr(p1, "class", "cookieConsent__Description");
                attr(div0, "class", "cookieConsent__Content");
                attr(div1, "class", "cookieConsent__Left");
                attr(button0, "type", "button");
                attr(button0, "class", "cookieConsent__Button");
                attr(button1, "type", "submit");
                attr(button1, "class", "cookieConsent__Button");
                attr(div2, "class", "cookieConsent__Right");
                attr(div3, "class", "cookieConsent");
                attr(div4, "class", "cookieConsentWrapper");

                dispose = [
                    listen(button0, "click", ctx.click_handler_1),
                    listen(button1, "click", ctx.choose)
                ];
            },

            m(target, anchor) {
                insert(target, div4, anchor);
                append(div4, div3);
                append(div3, div1);
                append(div1, div0);
                append(div0, p0);
                append(p0, t0);
                append(div0, t1);
                append(div0, p1);
                p1.innerHTML = ctx.description;
                append(div3, t2);
                append(div3, div2);
                append(div2, button0);
                append(button0, t3);
                append(div2, t4);
                append(div2, button1);
                append(button1, t5);
                current = true;
            },

            p(changed, ctx) {
                if (!current || changed.heading) {
                    set_data(t0, ctx.heading);
                }

                if (!current || changed.description) {
                    p1.innerHTML = ctx.description;
                }

                if (!current || changed.settingsLabel) {
                    set_data(t3, ctx.settingsLabel);
                }

                if (!current || changed.acceptLabel) {
                    set_data(t5, ctx.acceptLabel);
                }
            },

            i(local) {
                if (current) return;
                add_render_callback(() => {
                    if (!div4_transition) div4_transition = create_bidirectional_transition(div4, fade, {}, true);
                    div4_transition.run(1);
                });

                current = true;
            },

            o(local) {
                if (!div4_transition) div4_transition = create_bidirectional_transition(div4, fade, {}, false);
                div4_transition.run(0);

                current = false;
            },

            d(detaching) {
                if (detaching) {
                    detach(div4);
                    if (div4_transition) div4_transition.end();
                }

                run_all(dispose);
            }
        };
    }

    // (173:0) {#if settingsShown}
    function create_if_block(ctx) {
        var div1, div0, t0, button, t1, div1_transition, current, dispose;

        var each_value = ctx.choicesArr;

        var each_blocks = [];

        for (var i = 0; i < each_value.length; i += 1) {
            each_blocks[i] = create_each_block(get_each_context(ctx, each_value, i));
        }

        return {
            c() {
                div1 = element("div");
                div0 = element("div");

                for (var i = 0; i < each_blocks.length; i += 1) {
                    each_blocks[i].c();
                }

                t0 = space();
                button = element("button");
                t1 = text(ctx.closeLabel);
                attr(button, "type", "submit");
                attr(button, "class", "cookieConsent__Button cookieConsent__Button--Close");
                attr(div0, "class", "cookieConsentOperations__List");
                attr(div1, "class", "cookieConsentOperations");
                dispose = listen(button, "click", ctx.click_handler_3);//ctx.click_handler_2);
            },

            m(target, anchor) {
                insert(target, div1, anchor);
                append(div1, div0);

                for (var i = 0; i < each_blocks.length; i += 1) {
                    each_blocks[i].m(div0, null);
                }

                append(div0, t0);
                append(div0, button);
                append(button, t1);
                current = true;
            },

            p(changed, ctx) {
                if (changed.choicesMerged || changed.choicesArr) {
                    each_value = ctx.choicesArr;

                    for (var i = 0; i < each_value.length; i += 1) {
                        const child_ctx = get_each_context(ctx, each_value, i);

                        if (each_blocks[i]) {
                            each_blocks[i].p(changed, child_ctx);
                        } else {
                            each_blocks[i] = create_each_block(child_ctx);
                            each_blocks[i].c();
                            each_blocks[i].m(div0, t0);
                        }
                    }

                    for (; i < each_blocks.length; i += 1) {
                        each_blocks[i].d(1);
                    }
                    each_blocks.length = each_value.length;
                }

                if (!current || changed.closeLabel) {
                    set_data(t1, ctx.closeLabel);
                }
            },

            i(local) {
                if (current) return;
                add_render_callback(() => {
                    if (!div1_transition) div1_transition = create_bidirectional_transition(div1, fade, {}, true);
                    div1_transition.run(1);
                });

                current = true;
            },

            o(local) {
                if (!div1_transition) div1_transition = create_bidirectional_transition(div1, fade, {}, false);
                div1_transition.run(0);

                current = false;
            },

            d(detaching) {
                if (detaching) {
                    detach(div1);
                }

                destroy_each(each_blocks, detaching);

                if (detaching) {
                    if (div1_transition) div1_transition.end();
                }

                dispose();
            }
        };
    }

    // (177:6) {#if choicesMerged.hasOwnProperty(choice.id) && choicesMerged[choice.id]}
    function create_if_block_1(ctx) {
        var div, input, input_id_value, input_disabled_value, t0, label, t1_value = ctx.choice.label, t1, label_for_value, t2, span, t3_value = ctx.choice.description, t3, dispose;

        function input_change_handler() {
            ctx.input_change_handler.call(input, ctx);
        }

        return {
            c() {
                div = element("div");
                input = element("input");
                t0 = space();
                label = element("label");
                t1 = text(t1_value);
                t2 = space();
                span = element("span");
                t3 = text(t3_value);
                attr(input, "type", "checkbox");
                attr(input, "id", input_id_value = `gdpr-check-${ctx.choice.id}`);
                input.disabled = input_disabled_value = ctx.choice.id === 'necessary';
                attr(label, "for", label_for_value = `gdpr-check-${ctx.choice.id}`);
                attr(span, "class", "cookieConsentOperations__ItemLabel");
                attr(div, "class", "cookieConsentOperations__Item");
                toggle_class(div, "disabled", ctx.choice.id === 'necessary');
                dispose = listen(input, "change", input_change_handler);
            },

            m(target, anchor) {
                insert(target, div, anchor);
                append(div, input);

                input.checked = ctx.choicesMerged[ctx.choice.id].value;

                append(div, t0);
                append(div, label);
                append(label, t1);
                append(div, t2);
                append(div, span);
                append(span, t3);
            },

            p(changed, new_ctx) {
                ctx = new_ctx;
                if ((changed.choicesMerged || changed.choicesArr)) input.checked = ctx.choicesMerged[ctx.choice.id].value;

                if ((changed.choicesArr) && input_id_value !== (input_id_value = `gdpr-check-${ctx.choice.id}`)) {
                    attr(input, "id", input_id_value);
                }

                if ((changed.choicesArr) && input_disabled_value !== (input_disabled_value = ctx.choice.id === 'necessary')) {
                    input.disabled = input_disabled_value;
                }

                if ((changed.choicesArr) && t1_value !== (t1_value = ctx.choice.label)) {
                    set_data(t1, t1_value);
                }

                if ((changed.choicesArr) && label_for_value !== (label_for_value = `gdpr-check-${ctx.choice.id}`)) {
                    attr(label, "for", label_for_value);
                }

                if ((changed.choicesArr) && t3_value !== (t3_value = ctx.choice.description)) {
                    set_data(t3, t3_value);
                }

                if (changed.choicesArr) {
                    toggle_class(div, "disabled", ctx.choice.id === 'necessary');
                }
            },

            d(detaching) {
                if (detaching) {
                    detach(div);
                }

                dispose();
            }
        };
    }

    // (176:4) {#each choicesArr as choice}
    function create_each_block(ctx) {
        var if_block_anchor;

        var if_block = (ctx.choicesMerged.hasOwnProperty(ctx.choice.id) && ctx.choicesMerged[ctx.choice.id]) && create_if_block_1(ctx);

        return {
            c() {
                if (if_block) if_block.c();
                if_block_anchor = empty();
            },

            m(target, anchor) {
                if (if_block) if_block.m(target, anchor);
                insert(target, if_block_anchor, anchor);
            },

            p(changed, ctx) {
                if (ctx.choicesMerged.hasOwnProperty(ctx.choice.id) && ctx.choicesMerged[ctx.choice.id]) {
                    if (if_block) {
                        if_block.p(changed, ctx);
                    } else {
                        if_block = create_if_block_1(ctx);
                        if_block.c();
                        if_block.m(if_block_anchor.parentNode, if_block_anchor);
                    }
                } else if (if_block) {
                    if_block.d(1);
                    if_block = null;
                }
            },

            d(detaching) {
                if (if_block) if_block.d(detaching);

                if (detaching) {
                    detach(if_block_anchor);
                }
            }
        };
    }

    function create_fragment(ctx) {
        var t0, t1, if_block2_anchor, current;

        var if_block0 = (ctx.showEditIcon) && create_if_block_3(ctx);

        var if_block1 = (ctx.shown) && create_if_block_2(ctx);

        var if_block2 = (ctx.settingsShown) && create_if_block(ctx);

        return {
            c() {
                if (if_block0) if_block0.c();
                t0 = space();
                if (if_block1) if_block1.c();
                t1 = space();
                if (if_block2) if_block2.c();
                if_block2_anchor = empty();
            },

            m(target, anchor) {
                if (if_block0) if_block0.m(target, anchor);
                insert(target, t0, anchor);
                if (if_block1) if_block1.m(target, anchor);
                insert(target, t1, anchor);
                if (if_block2) if_block2.m(target, anchor);
                insert(target, if_block2_anchor, anchor);
                current = true;
            },

            p(changed, ctx) {
                if (ctx.showEditIcon) {
                    if (!if_block0) {
                        if_block0 = create_if_block_3(ctx);
                        if_block0.c();
                        transition_in(if_block0, 1);
                        if_block0.m(t0.parentNode, t0);
                    } else {
                        transition_in(if_block0, 1);
                    }
                } else if (if_block0) {
                    group_outros();
                    transition_out(if_block0, 1, () => {
                        if_block0 = null;
                    });
                    check_outros();
                }

                if (ctx.shown) {
                    if (if_block1) {
                        if_block1.p(changed, ctx);
                        transition_in(if_block1, 1);
                    } else {
                        if_block1 = create_if_block_2(ctx);
                        if_block1.c();
                        transition_in(if_block1, 1);
                        if_block1.m(t1.parentNode, t1);
                    }
                } else if (if_block1) {
                    group_outros();
                    transition_out(if_block1, 1, () => {
                        if_block1 = null;
                    });
                    check_outros();
                }

                if (ctx.settingsShown) {
                    if (if_block2) {
                        if_block2.p(changed, ctx);
                        transition_in(if_block2, 1);
                    } else {
                        if_block2 = create_if_block(ctx);
                        if_block2.c();
                        transition_in(if_block2, 1);
                        if_block2.m(if_block2_anchor.parentNode, if_block2_anchor);
                    }
                } else if (if_block2) {
                    group_outros();
                    transition_out(if_block2, 1, () => {
                        if_block2 = null;
                    });
                    check_outros();
                }
            },

            i(local) {
                if (current) return;
                transition_in(if_block0);
                transition_in(if_block1);
                transition_in(if_block2);
                current = true;
            },

            o(local) {
                transition_out(if_block0);
                transition_out(if_block1);
                transition_out(if_block2);
                current = false;
            },

            d(detaching) {
                if (if_block0) if_block0.d(detaching);

                if (detaching) {
                    detach(t0);
                }

                if (if_block1) if_block1.d(detaching);

                if (detaching) {
                    detach(t1);
                }

                if (if_block2) if_block2.d(detaching);

                if (detaching) {
                    detach(if_block2_anchor);
                }
            }
        };
    }

    function instance($$self, $$props, $$invalidate) {


        const dispatch = createEventDispatcher();
        const cookies = Cookie();

        let { cookieName = null, showEditIcon = true } = $$props;

        let shown = false;
        let settingsShown = false;

        let { heading = 'GDPR Notice', description =
            'We use cookies to offer a better browsing experience, analyze site traffic, personalize content, and serve targeted advertisements. Please review our privacy policy & cookies information page. By clicking accept, you consent to our privacy policy & use of cookies.', categories = {
                analytics: function () { },
                tracking: function () { },
                marketing: function () { },
                necessary: function () { }
            } } = $$props;

        let { cookieConfig = {}, choices = {} } = $$props;
        const choicesDefaults = {
            necessary: {
                label: 'Necessary cookies',
                description: "Used for cookie control. Can't be turned off.",
                value: true
            },
            tracking: {
                label: 'Tracking cookies',
                description: 'Used for advertising purposes.',
                value: true
            },
            analytics: {
                label: 'Analytics cookies',
                description:
                    'Used to control Google Analytics, a 3rd party tool offered by Google to track user behavior.',
                value: true
            },
            marketing: {
                label: 'Marketing cookies',
                description: 'Used for marketing data.',
                value: true
            }
        };

        const choicesMerged = Object.assign({}, choicesDefaults, choices);

        let { acceptLabel = 'Accept cookies', settingsLabel = 'Cookie settings', closeLabel = 'Close settings' } = $$props;

        onMount(() => {
            if (!cookieName) {
                throw 'You must set gdpr cookie name'
            }

            const cookie = cookies.get(cookieName);
            if (cookie && chosenMatchesChoice(cookie)) {
                execute(cookie.choices);
            } else {
                removeCookie();
                $$invalidate('shown', shown = true);
            }
        });

        function setCookie(choices) {
            const expires = new Date();
            expires.setDate(expires.getDate() + 365);

            const options = Object.assign({}, cookieConfig, { expires });
            cookies.set(cookieName, { choices }, options);
        }

        function removeCookie() {
            const { path } = cookieConfig;
            cookies.remove(cookieName, Object.assign({}, path ? { path } : {}));
        }

        function chosenMatchesChoice(cookie) {
            return validate(cookieChoices, cookie)
        }

        function execute(chosen) {
            const types = Object.keys(cookieChoices);

            types.forEach(t => {
                const agreed = chosen[t];
                choicesMerged[t] ? (choicesMerged[t].value = agreed) : false; $$invalidate('choicesMerged', choicesMerged);
                if (agreed) {
                    if(typeof categories[t] !== 'undefined' && categories[t].hasOwnProperty('enabled')){
                    categories[t]['enabled']();
                    dispatch(`${t}`);
                    }
                }
                if (!agreed) {
                    if(typeof categories[t] !== 'undefined' && categories[t].hasOwnProperty('disabled')){
                    categories[t]['disabled']();
                    dispatch(`${t}`);
                    }
                }
            });
            $$invalidate('shown', shown = false);
        }

        function choose() {
            setCookie(cookieChoices);
            execute(cookieChoices);
        }

        function click_handler() {
            const $$result = (shown = true);
            $$invalidate('shown', shown);
            return $$result;
        }

        function click_handler_1() {
            const $$result = settingsShown = true;
            $$invalidate('settingsShown', settingsShown);
            return $$result;
        }

        function input_change_handler({ choice }) {
            choicesMerged[choice.id].value = this.checked;
            $$invalidate('choicesMerged', choicesMerged);
            $$invalidate('choicesArr', choicesArr), $$invalidate('choicesMerged', choicesMerged);
        }

        function click_handler_2() {
            const $$result = settingsShown = false;
            $$invalidate('settingsShown', settingsShown);
            return $$result;
        }

        function click_handler_3() {
            const $$result = settingsShown = false;
            $$invalidate('settingsShown', settingsShown);
            setCookie(cookieChoices);
            execute(cookieChoices);
            return $$result;
        }

        $$self.$set = $$props => {
            if ('cookieName' in $$props) $$invalidate('cookieName', cookieName = $$props.cookieName);
            if ('showEditIcon' in $$props) $$invalidate('showEditIcon', showEditIcon = $$props.showEditIcon);
            if ('heading' in $$props) $$invalidate('heading', heading = $$props.heading);
            if ('description' in $$props) $$invalidate('description', description = $$props.description);
            if ('categories' in $$props) $$invalidate('categories', categories = $$props.categories);
            if ('cookieConfig' in $$props) $$invalidate('cookieConfig', cookieConfig = $$props.cookieConfig);
            if ('choices' in $$props) $$invalidate('choices', choices = $$props.choices);
            if ('acceptLabel' in $$props) $$invalidate('acceptLabel', acceptLabel = $$props.acceptLabel);
            if ('settingsLabel' in $$props) $$invalidate('settingsLabel', settingsLabel = $$props.settingsLabel);
            if ('closeLabel' in $$props) $$invalidate('closeLabel', closeLabel = $$props.closeLabel);
        };

        let choicesArr, cookieChoices;

        $$self.$$.update = ($$dirty = { choicesMerged: 1, choicesArr: 1 }) => {
            if ($$dirty.choicesMerged) {
                $$invalidate('choicesArr', choicesArr = Object.values(choicesMerged).map((item, index) => {
                    return Object.assign(
                        {},
                        item,
                        { id: Object.keys(choicesMerged)[index] }
                    )
                }));
            }
            if ($$dirty.choicesArr) {
                cookieChoices = choicesArr.reduce(function (result, item, index, array) {
                    result[item.id] = item.value ? item.value : false;
                    return result
                }, {});
            }
        };

        return {
            cookieName,
            showEditIcon,
            shown,
            settingsShown,
            heading,
            description,
            categories,
            cookieConfig,
            choices,
            choicesMerged,
            acceptLabel,
            settingsLabel,
            closeLabel,
            choose,
            choicesArr,
            click_handler,
            click_handler_1,
            input_change_handler,
            click_handler_2,
            click_handler_3
        };
    }

    class Banner extends SvelteComponent {
        constructor(options) {
            super();
            init(this, options, instance, create_fragment, safe_not_equal, ["cookieName", "showEditIcon", "heading", "description", "categories", "cookieConfig", "choices", "acceptLabel", "settingsLabel", "closeLabel"]);
        }
    }

    function attachBanner(target, props = {}) {
        const banner = new Banner({
            target,
            props
        });
        return banner;
    }

    function showBanner(Banner){
        Banner.$$.ctx.click_handler_1()
    }

    function cookies(){
        const cookies = Cookie();
        return cookies;
    }
    window.GdprConsent = window.GdprConsent || {};
    window.GdprConsent.attachBanner = attachBanner;
    window.GdprConsent.showBanner = showBanner;
    window.GdprConsent.cookies = cookies;


}());

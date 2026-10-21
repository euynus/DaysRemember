// A small stand-in for the browser: only what docs/assets/site.js touches, so its behaviour can be
// checked in Node without dependencies. Timers, frames and intersections run only when a test asks.
import { readFileSync } from "node:fs";
import vm from "node:vm";

const siteScript = readFileSync(new URL("../../docs/assets/site.js", import.meta.url), "utf8");

export class Element {
  constructor(tag, attributes = {}, children = []) {
    this.tagName = tag.toUpperCase();
    this.attributes = { ...attributes };
    this.children = [];
    this.parent = null;
    this.listeners = {};
    this.style = {};
    this.text = "";
    this.value = attributes.value ?? "";
    this.placeholder = attributes.placeholder ?? "";
    this.checked = "checked" in attributes;
    const classes = new Set((attributes.class || "").split(/\s+/).filter(Boolean));
    this.classList = {
      add: (...names) => names.forEach((name) => classes.add(name)),
      remove: (...names) => names.forEach((name) => classes.delete(name)),
      contains: (name) => classes.has(name),
      toggle: (name, force) => {
        const on = force ?? !classes.has(name);
        if (on) classes.add(name); else classes.delete(name);
        return on;
      }
    };
    for (const child of children) this.appendChild(typeof child === "string" ? text(child) : child);
  }

  get id() { return this.attributes.id; }
  get lang() { return this.attributes.lang || ""; }
  get src() { return this.attributes.src || ""; }
  set src(value) { this.attributes.src = String(value); }
  get type() { return this.attributes.type || ""; }
  set type(value) { this.attributes.type = String(value); }
  get className() { return this.attributes.class || ""; }
  getAttribute(name) { return name in this.attributes ? this.attributes[name] : null; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  removeAttribute(name) { delete this.attributes[name]; }
  hasAttribute(name) { return name in this.attributes; }

  appendChild(child) {
    child.parent = this;
    this.children.push(child);
    return child;
  }

  insertBefore(child, reference) {
    child.parent = this;
    const index = this.children.indexOf(reference);
    this.children.splice(index < 0 ? this.children.length : index, 0, child);
    return child;
  }

  addEventListener(type, listener) { (this.listeners[type] ||= []).push(listener); }
  removeEventListener(type, listener) {
    this.listeners[type] = (this.listeners[type] || []).filter((each) => each !== listener);
  }
  dispatchEvent(event) {
    if (!event.target) event.target = this;
    for (const listener of this.listeners[event.type] || []) listener.call(this, event);
    return true;
  }
  click() { this.dispatchEvent({ type: "click", preventDefault() {} }); }

  get textContent() {
    return this.tagName === "#TEXT" || !this.children.length
      ? this.text : this.children.map((child) => child.textContent).join("");
  }
  set textContent(value) {
    this.children = [];
    this.text = String(value);
  }

  getBoundingClientRect() { return { width: 40, height: 20 }; }

  descendants() { return this.children.flatMap((child) => [child, ...child.descendants()]); }

  // Compound selectors (`tag.class#id[attribute]`) joined by descendant combinators.
  matches(compound) {
    const tag = /^[a-z][\w-]*/i.exec(compound);
    if (tag && tag[0].toUpperCase() !== this.tagName) return false;
    for (const [, name] of compound.matchAll(/\.([\w-]+)/g)) if (!this.classList.contains(name)) return false;
    for (const [, id] of compound.matchAll(/#([\w-]+)/g)) if (this.id !== id) return false;
    for (const [, name] of compound.matchAll(/\[([\w-]+)\]/g)) if (!this.hasAttribute(name)) return false;
    return true;
  }

  querySelectorAll(selector) {
    const parts = selector.trim().split(/\s+/);
    const last = parts.pop();
    return this.descendants().filter((element) => {
      if (element.tagName === "#TEXT" || !element.matches(last)) return false;
      let ancestor = element.parent;
      for (let index = parts.length - 1; index >= 0; index--) {
        while (ancestor && !ancestor.matches(parts[index])) ancestor = ancestor.parent;
        if (!ancestor) return false;
        ancestor = ancestor.parent;
      }
      return true;
    });
  }

  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
}

export function el(tag, attributes, ...children) { return new Element(tag, attributes || {}, children); }

export function text(value) {
  const node = new Element("#text");
  node.text = value;
  return node;
}

/// Runs site.js against `body` at `now`. Returns handles to drive what a browser would.
export function runSite({ lang = "zh-Hans", motion = false, now = Date.now(), body = [] } = {}) {
  const html = el("html", { lang, ...(motion ? { class: "motion" } : {}) }, el("body", {}, ...body));
  const document = Object.assign(new Element("#document"), { documentElement: html, readyState: "complete", hidden: false });
  document.appendChild(html);
  document.createElement = (tag) => new Element(tag);

  let clock = now;
  let timers = [];
  let frames = [];
  const observers = [];
  const window = new Element("#window");

  class FakeDate extends Date {
    constructor(...args) { if (args.length) super(...args); else super(clock); }
    static now() { return clock; }
  }

  class Image extends Element {
    constructor() { super("img"); this.complete = true; this.naturalWidth = 1; }
  }

  class IntersectionObserver {
    constructor(callback) { this.callback = callback; this.targets = []; observers.push(this); }
    observe(target) { this.targets.push(target); }
    unobserve(target) { this.targets = this.targets.filter((each) => each !== target); }
  }

  const schedule = (repeat) => (callback, delay = 0) => {
    const timer = { callback, delay, due: clock + delay, repeat };
    timers.push(timer);
    return timer;
  };

  const context = vm.createContext({
    document, window, Date: FakeDate, Image, IntersectionObserver,
    CustomEvent: class { constructor(type, init = {}) { this.type = type; this.detail = init.detail; } },
    setTimeout: schedule(false), setInterval: schedule(true),
    clearTimeout: (timer) => { timers = timers.filter((each) => each !== timer); },
    clearInterval: (timer) => { timers = timers.filter((each) => each !== timer); },
    requestAnimationFrame: (callback) => { frames.push(callback); return frames.length; },
    cancelAnimationFrame: () => {}
  });
  vm.runInContext(siteScript, context);

  return {
    document, window,
    $: (selector) => document.querySelector(selector),
    $$: (selector) => document.querySelectorAll(selector),
    /// Moves the clock on, running timers that come due.
    advance(milliseconds) {
      const end = clock + milliseconds;
      for (;;) {
        const next = timers.filter((timer) => timer.due <= end).sort((a, b) => a.due - b.due)[0];
        if (!next) break;
        clock = next.due;
        if (next.repeat) next.due += Math.max(next.delay, 1); else timers = timers.filter((each) => each !== next);
        next.callback();
      }
      clock = end;
    },
    /// Runs animation frames until none are left, one frame every 16 ms.
    flushFrames() {
      for (let guard = 0; frames.length && guard < 1000; guard++) {
        const pending = frames;
        frames = [];
        clock += 16;
        for (const callback of pending) callback(clock);
      }
    },
    /// Reports `target` as scrolled into view.
    intersect(target) {
      for (const observer of observers) {
        if (observer.targets.includes(target)) observer.callback([{ target, isIntersecting: true }]);
      }
    }
  };
}

/// Noon on a calendar date on this machine's clock, as a timestamp.
export function localNoon(date) { return new Date(date + "T12:00:00").getTime(); }

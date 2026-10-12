// Checks for the product site (docs/). Run with `node --test scripts/site-tests`.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { beijingNoon, el, runSite } from "./dom.mjs";

const docs = new URL("../../docs/", import.meta.url);
const read = (path) => readFileSync(new URL(path, docs), "utf8");

function heroDate(lang, date) {
  const site = runSite({ lang, now: beijingNoon(date), body: [el("p", { class: "today", "data-today": "" })] });
  return site.$("[data-today]").textContent;
}

// The app's Lunar.fmt for these dates. Upstream ICU, in Chrome, Edge and Firefox, is a day off
// from 2027-02-06 to 03-07 and from 2030-02-02 to 03-03.
test("the hero's lunar date matches the app", () => {
  const app = {
    "2027-02-06": "正月初一", "2027-03-07": "正月三十", "2027-03-08": "二月初一",
    "2030-02-03": "正月初一", "2030-03-03": "正月廿九", "2026-10-12": "九月初三",
    "2023-03-22": "闰二月初一", "2025-01-28": "腊月廿九", "2033-12-22": "闰冬月初一"
  };
  for (const [date, lunar] of Object.entries(app)) {
    assert.ok(heroDate("zh-Hans", date).endsWith(" · " + lunar), date + ": " + heroDate("zh-Hans", date));
  }
  assert.ok(heroDate("zh-Hant", "2025-01-28").endsWith(" · 臘月廿九"));
  assert.ok(heroDate("en", "2023-03-22").endsWith(" · Leap month 2, Day 1"));
  assert.ok(heroDate("en", "2027-02-06").endsWith(" · Month 1, Day 1"));
});

const css = read("assets/site.css").replace(/\/\*[\s\S]*?\*\//g, "");

/// The declarations of the first rule whose selector is exactly `selector`.
function rule(selector) {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = new RegExp("(?:^|\\n|\\})\\s*" + escaped + "\\s*\\{([^}]*)\\}").exec(css);
  assert.ok(match, "no rule for " + selector);
  return Object.fromEntries(match[1].split(";").map((part) => part.split(":").map((each) => each.trim()))
    .filter(([name, value]) => name && value));
}

function color(value) {
  const root = rule(":root");
  const resolved = value.replace(/var\((--[\w-]+)\)/, (_, name) => root[name]);
  const hex = /^#([0-9a-f]{6})$/i.exec(resolved);
  assert.ok(hex, "not a hex colour: " + value);
  return [0, 2, 4].map((index) => parseInt(hex[1].slice(index, index + 2), 16) / 255);
}

function contrast(foreground, background) {
  const luminance = (rgb) => rgb.map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    .reduce((sum, c, index) => sum + c * [0.2126, 0.7152, 0.0722][index], 0);
  const [light, dark] = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (light + 0.05) / (dark + 0.05);
}

// 16px semibold text is not large text, so WCAG 1.4.3 asks for 4.5:1.
test("the coming-soon badge has enough contrast", () => {
  const badge = rule(".cta.is-soon");
  const ratio = contrast(color(badge.color), color(badge.background));
  assert.ok(ratio >= 4.5, "contrast " + ratio.toFixed(2) + ":1");
});

/// The body of the `@media <query>` block.
function media(query) {
  const start = css.indexOf("@media " + query + " {");
  assert.ok(start >= 0, "no @media " + query);
  let depth = 0;
  for (let index = css.indexOf("{", start); index < css.length; index++) {
    if (css[index] === "{") depth++;
    if (css[index] === "}" && --depth === 0) return css.slice(css.indexOf("{", start) + 1, index);
  }
  assert.fail("unclosed @media " + query);
}

function features() {
  return el("ul", { class: "rows" },
    el("li", { class: "row reveal" }, el("p", { class: "figure" }, el("b", {}, "24"), el("small", {}, "个节气"))),
    el("li", { class: "row reveal" }, el("p", { class: "figure" }, el("b", {}, "30"), el("small", {}, "天内可恢复"))));
}

function demo() {
  return [
    el("form", { class: "demo-form reveal", "data-demo": "" },
      el("input", { id: "demo-title", value: "结婚纪念日", placeholder: "结婚纪念日" }),
      el("input", { id: "demo-date", value: "2019-10-12" }),
      el("input", { id: "demo-recurring", checked: "" })),
    el("article", { class: "day-card reveal", "data-demo-card": "" },
      el("h3", { "data-title": "" }), el("p", { "data-date": "" }),
      el("p", { class: "figure" }, el("b", {}, "0"), el("small", {})), el("p", { "data-elapsed": "" }))
  ];
}

// Print never scrolls anything into view, and a reveal that just started is still transparent.
test("printing shows every section with its final figures", () => {
  const site = runSite({ motion: true, now: beijingNoon("2026-10-12"), body: [features(), ...demo()] });
  const figures = site.$$(".row .figure b");
  assert.deepEqual(figures.map((figure) => figure.textContent), ["0", "0"], "figures wait for their rows");
  const card = site.$("[data-demo-card]");
  site.intersect(card);
  site.flushFrames();
  const days = card.querySelector(".figure b").textContent;

  const counting = runSite({ motion: true, now: beijingNoon("2026-10-12"), body: [features(), ...demo()] });
  counting.intersect(counting.$("[data-demo-card]"));
  counting.window.dispatchEvent({ type: "beforeprint" });
  assert.deepEqual(counting.$$(".row .figure b").map((figure) => figure.textContent), ["24", "30"]);
  assert.equal(counting.$("[data-demo-card] .figure b").textContent, days, "the demo shows its final count");

  const print = media("print");
  assert.match(print, /\.motion \.reveal:not\(\.in\)\s*\{[^}]*opacity:\s*1/);
  assert.match(print, /animation:\s*none/);
});

// WCAG 2.2.2: an on-page control pauses content that moves on its own for more than 5 s.
test("the hero slideshow can be paused", () => {
  const phone = el("div", { class: "phone" }, el("img", { src: "home.jpg", alt: "首页" }));
  const shots = el("div", { class: "shots" }, ...["home.jpg", "detail.jpg", "calendar.jpg"]
    .map((src) => el("figure", {}, el("img", { src }))));
  const site = runSite({ motion: true, body: [el("section", { class: "hero" }, phone), shots] });
  const showing = () => phone.querySelectorAll("img.is-current").map((frame) => frame.src);
  site.advance(3200 + 900);
  assert.deepEqual(showing(), ["detail.jpg"]);

  const toggle = phone.querySelector("button");
  assert.ok(toggle, "a pause button");
  assert.equal(toggle.getAttribute("aria-pressed"), "false");
  assert.equal(toggle.getAttribute("aria-label"), "暂停截图轮播");
  toggle.click();
  assert.equal(toggle.getAttribute("aria-pressed"), "true");
  site.advance(20000);
  assert.deepEqual(showing(), ["detail.jpg"], "paused");
  toggle.click();
  site.advance(3200 + 900);
  assert.deepEqual(showing(), ["calendar.jpg"], "playing again");
});

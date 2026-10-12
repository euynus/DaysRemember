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

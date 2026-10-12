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

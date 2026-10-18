// Checks for the product site's layout and colours (docs/). Run with `node --test scripts/site-tests`.
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import test from "node:test";

const docs = new URL("../../docs/", import.meta.url);
const read = (path) => readFileSync(new URL(path, docs), "utf8");
const PRODUCT = ["index.html", "zh-Hant/index.html", "en/index.html"];
const css = read("assets/site.css").replace(/\/\*[\s\S]*?\*\//g, "");

// Attributes that hold words, or paths that differ with each page's depth.
const WORDED = new Set(["alt", "content", "href", "lang", "title", "aria-label", "aria-current", "value", "placeholder", "maxlength"]);

/// The page's body as a list of tags and their attributes, with words and page-relative paths left out.
function skeleton(page) {
  const body = read(page).split("<body>")[1].split("</body>")[0].replace(/<!--[\s\S]*?-->/g, "");
  return [...body.matchAll(/<(\/?)([a-z0-9]+)([^>]*)>/g)].map(([, slash, tag, attributes]) => {
    const kept = [...attributes.matchAll(/([a-z-]+)(?:="([^"]*)")?/g)]
      .filter(([, name]) => !WORDED.has(name))
      .map(([, name, value]) => {
        if (value === undefined) return name;
        if (name === "src") value = value.replace(/^(\.\.\/)+/, "").replace(/\/(zh-Hans|zh-Hant|en)\//, "/LANG/");
        return `${name}="${value}"`;
      });
    return `<${slash}${tag}${kept.length ? " " + kept.join(" ") : ""}>`;
  });
}

test("the three product pages are built the same way", () => {
  const [simplified, ...others] = PRODUCT.map(skeleton);
  assert.ok(simplified.length > 200, "a page's worth of tags");
  for (const [index, other] of others.entries()) {
    assert.deepEqual(other, simplified, PRODUCT[index + 1] + " differs from index.html");
  }
});

const imagesOf = (page) => [...read(page).matchAll(/<img\b([^>]*)>/g)].map((match) => {
  const attribute = (name) => new RegExp(`\\b${name}="([^"]*)"`).exec(match[1])?.[1];
  return { src: attribute("src"), alt: attribute("alt"), raw: match[0] };
});

test("every illustration says what it shows, the same way each time", () => {
  for (const page of PRODUCT) {
    const descriptions = {};
    for (const image of imagesOf(page)) {
      assert.notEqual(image.alt, undefined, page + ": " + image.raw);
      const cover = /assets\/covers\/([a-z]+)\.svg$/.exec(image.src || "");
      if (!cover) continue;
      assert.ok(image.alt.trim(), page + ": " + image.raw);
      descriptions[cover[1]] ??= image.alt;
      assert.equal(image.alt, descriptions[cover[1]], page + ": " + cover[1]);
    }
    // The covers tile shows all twelve, which are the files in docs/assets/covers.
    const files = readdirSync(new URL("assets/covers/", docs)).filter((name) => name.endsWith(".svg"))
      .map((name) => name.replace(/\.svg$/, "")).sort();
    assert.equal(files.length, 12);
    assert.deepEqual(Object.keys(descriptions).sort(), files, page);
  }
});

test("every image and stylesheet a product page names exists", () => {
  for (const page of PRODUCT) {
    const base = new URL(page, docs);
    for (const match of read(page).matchAll(/(?:src|href)="([^"#:]+\.(?:svg|jpg|png|css|js))"/g)) {
      assert.ok(existsSync(new URL(match[1], base)), page + ": " + match[1]);
    }
  }
});

function hex(value) {
  const match = /^#([0-9a-f]{6})$/i.exec(value.trim());
  assert.ok(match, "not a hex colour: " + value);
  return [0, 2, 4].map((index) => parseInt(match[1].slice(index, index + 2), 16) / 255);
}

function contrast(foreground, background) {
  const luminance = (rgb) => rgb.map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    .reduce((sum, c, index) => sum + c * [0.2126, 0.7152, 0.0722][index], 0);
  const [light, dark] = [luminance(hex(foreground)), luminance(hex(background))].sort((a, b) => b - a);
  return (light + 0.05) / (dark + 0.05);
}

/// The custom properties set by the first rule whose selector is exactly `selector`.
function properties(selector) {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = new RegExp("(?:^|\\n|\\})\\s*" + escaped + "\\s*\\{([^}]*)\\}").exec(css);
  assert.ok(match, "no rule for " + selector);
  return Object.fromEntries(match[1].split(";").map((part) => part.split(":").map((each) => each.trim()))
    .filter(([name, value]) => name && value));
}

const root = properties(":root");
/// A colour, with a `var(--name)` reference looked up in :root.
function resolve(value) {
  const name = /^var\((--[\w-]+)\)$/.exec(value)?.[1];
  return name ? root[name] : value;
}

// WCAG 1.4.3: tiles carry body text in ink-2 and figures in their tone's ink, both at least 4.5:1.
test("text on every pastel tone is readable", () => {
  const tones = [...css.matchAll(/\.(tone-[a-z]+) \{/g)].map((match) => "." + match[1]);
  assert.ok(tones.length >= 7, "tones");
  for (const selector of [...tones, ".day-card.is-past"]) {
    const tone = properties(selector);
    for (const [name, colour] of [["--tone-ink", resolve(tone["--tone-ink"])], ["--ink", root["--ink"]], ["--ink-2", root["--ink-2"]]]) {
      const ratio = contrast(colour, resolve(tone["--tone"]));
      assert.ok(ratio >= 4.5, `${name} on ${selector}: ${ratio.toFixed(2)}:1`);
    }
  }
  // The tiles take the category colours from :root rather than repeating them.
  for (const name of ["rose", "apricot", "sky", "mint", "lemon", "lavender"]) {
    const tone = properties(".tone-" + name);
    assert.equal(tone["--tone"], `var(--${name})`, name);
    assert.equal(tone["--tone-ink"], `var(--${name}-ink)`, name);
    assert.ok(root["--" + name] && root[`--${name}-ink`], name);
  }
  // Every tone a page uses has a rule.
  for (const page of PRODUCT) {
    for (const match of read(page).matchAll(/\b(tone-[a-z]+)\b/g)) properties("." + match[1]);
  }
});

test("secondary text is readable on the ground, the cards and the ink", () => {
  for (const background of ["--bg", "--bg-2", "--card"]) {
    for (const foreground of ["--ink", "--ink-2", "--muted"]) {
      const ratio = contrast(root[foreground], root[background]);
      assert.ok(ratio >= 4.5, `${foreground} on ${background}: ${ratio.toFixed(2)}:1`);
    }
  }
  const promise = /\.promise-text p \{ color: (#[0-9A-Fa-f]{6}); \}/.exec(css);
  assert.ok(promise, "the privacy card's text colour");
  assert.ok(contrast(promise[1], root["--ink"]) >= 4.5, "privacy text on ink");
  assert.ok(contrast(root["--card"], root["--ink"]) >= 4.5, "white on ink");
});

// The pages must read completely without motion: nothing is hidden outside html.motion.
test("only html.motion hides anything", () => {
  for (const match of css.matchAll(/([^{}]+)\{[^}]*opacity:\s*0[;\s}]/g)) {
    const selector = match[1].trim();
    if (selector.startsWith("@") || /^(from|to|\d+%)$/.test(selector)) continue;
    assert.ok(selector.split(",").every((part) => part.trim().startsWith(".motion") || part.includes("img + img")),
      "hidden without motion: " + selector);
  }
});

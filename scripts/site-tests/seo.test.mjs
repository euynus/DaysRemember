// Checks for the product site's search and sharing metadata (docs/). Run with `node --test scripts/site-tests`.
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const docs = new URL("../../docs/", import.meta.url);
const read = (path) => readFileSync(new URL(path, docs), "utf8");
const SITE = "https://days.gooday.dev/";

const PRODUCT = {
  "index.html": { lang: "zh-Hans", url: SITE, title: "时光 – 纪念日倒数日 App｜农历生日提醒、iPhone 小组件", free: "免费" },
  "zh-Hant/index.html": { lang: "zh-Hant", url: SITE + "zh-Hant/", title: "時光 – 紀念日倒數日 App｜農曆生日提醒、iPhone 小工具", free: "免費" },
  "en/index.html": { lang: "en", url: SITE + "en/", title: "Days Remember – Anniversary & Countdown App for iPhone", free: "free" }
};
const DOCUMENTS = {
  "privacy/index.html": { url: SITE + "privacy/", title: "隐私政策 Privacy Policy – 时光 · Days Remember" },
  "support/index.html": { url: SITE + "support/", title: "支持 Support – 时光 · Days Remember" }
};

const decode = (text) => text.replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&#x27;|&#39;/g, "'")
  .replace(/&lt;/g, "<").replace(/&gt;/g, ">");

function head(page) {
  return read(page).split("</head>")[0];
}

/// The content of the <meta> whose `name` or `property` is `key`; null when there is none.
function meta(page, key) {
  const match = new RegExp(`<meta (?:name|property)="${key.replace(/[.:]/g, "\\$&")}" content="([^"]*)">`).exec(head(page));
  return match ? decode(match[1]) : null;
}

function title(page) {
  return decode(/<title>([^<]*)<\/title>/.exec(head(page))[1]);
}

function link(page, rel) {
  const match = new RegExp(`<link rel="${rel}" href="([^"]*)">`).exec(head(page));
  return match ? match[1] : null;
}

function hreflangs(page) {
  return Object.fromEntries([...head(page).matchAll(/<link rel="alternate" hreflang="([^"]+)" href="([^"]+)">/g)]
    .map((match) => [match[1], match[2]]));
}

function jsonLD(page) {
  const match = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/.exec(head(page));
  assert.ok(match, page + " has no JSON-LD");
  return JSON.parse(match[1]);
}

/// A site URL's file in docs/, as Cloudflare serves it: directories hold index.html.
function local(url) {
  assert.ok(url.startsWith(SITE), url);
  const path = url.slice(SITE.length);
  return new URL(path === "" || path.endsWith("/") ? path + "index.html" : path, docs);
}

/// Width and height from a JPEG's start-of-frame marker.
function jpegSize(file) {
  const bytes = readFileSync(file);
  assert.equal(bytes.readUInt16BE(0), 0xffd8, "not a JPEG: " + file);
  for (let offset = 2; offset < bytes.length;) {
    const marker = bytes[offset + 1];
    const length = bytes.readUInt16BE(offset + 2);
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      return { height: bytes.readUInt16BE(offset + 5), width: bytes.readUInt16BE(offset + 7) };
    }
    offset += 2 + length;
  }
  assert.fail("no frame in " + file);
}

function checkShareImage(page) {
  const image = meta(page, "og:image");
  assert.equal(meta(page, "twitter:image"), image, page);
  assert.equal(meta(page, "twitter:card"), "summary_large_image", page);
  assert.ok(meta(page, "og:image:alt"), page + " og:image:alt");
  assert.equal(meta(page, "twitter:image:alt"), meta(page, "og:image:alt"), page);
  const file = local(image);
  assert.ok(existsSync(file), image);
  const size = jpegSize(file);
  assert.deepEqual([String(size.width), String(size.height)], [meta(page, "og:image:width"), meta(page, "og:image:height")], page);
  assert.deepEqual([size.width, size.height], [1200, 630], image);
}

test("each product page has its title, description, alternates and share card", () => {
  for (const [page, expected] of Object.entries(PRODUCT)) {
    assert.equal(title(page), expected.title, page);
    assert.equal(meta(page, "og:title"), expected.title, page);
    assert.equal(meta(page, "twitter:title"), expected.title, page);
    const description = meta(page, "description");
    assert.ok(description.toLowerCase().includes(expected.free), page + ": " + description);
    assert.equal(meta(page, "og:description"), description, page);
    assert.equal(meta(page, "twitter:description"), description, page);
    assert.equal(link(page, "canonical"), expected.url, page);
    assert.equal(meta(page, "og:url"), expected.url, page);
    assert.deepEqual(hreflangs(page), {
      "zh-Hans": SITE, "zh-Hant": SITE + "zh-Hant/", en: SITE + "en/", "x-default": SITE
    }, page);
    assert.match(read(page), new RegExp(`<html lang="${expected.lang}">`), page);
    checkShareImage(page);
  }
});

test("the privacy and support pages have their own titles and share card", () => {
  for (const [page, expected] of Object.entries(DOCUMENTS)) {
    assert.equal(title(page), expected.title, page);
    assert.equal(meta(page, "og:title"), expected.title, page);
    assert.equal(link(page, "canonical"), expected.url, page);
    assert.equal(meta(page, "og:url"), expected.url, page);
    // One URL holds all three languages, so there are no alternates to name.
    assert.deepEqual(hreflangs(page), {}, page);
    checkShareImage(page);
  }
});

// The App Store ID doesn't exist until release; a placeholder in the tag would break Smart App Banners.
test("no App Store banner tag before there is a real App Store ID", () => {
  for (const page of [...Object.keys(PRODUCT), ...Object.keys(DOCUMENTS)]) {
    const banner = /<meta name="apple-itunes-app" content="([^"]*)">/.exec(head(page).replace(/<!--[\s\S]*?-->/g, ""));
    if (banner) assert.match(banner[1], /^app-id=\d+/, page);
  }
});

test("the product pages describe the app in JSON-LD, as the page does", () => {
  for (const [page, expected] of Object.entries(PRODUCT)) {
    const app = jsonLD(page);
    assert.equal(app["@context"], "https://schema.org");
    assert.equal(app["@type"], "MobileApplication");
    // Each language describes the app in its own words, so each is its own entity.
    assert.equal(app["@id"], expected.url + "#app", page);
    assert.equal(app.url, expected.url, page);
    assert.equal(app.inLanguage, expected.lang, page);
    assert.equal(app.description, meta(page, "description"), page);
    assert.equal(app.operatingSystem, "iOS");
    assert.equal(app.isAccessibleForFree, true);
    assert.equal(app.offers["@type"], "Offer");
    assert.equal(app.offers.price, "0", page);
    for (const invented of ["aggregateRating", "review", "downloadUrl", "installUrl"]) {
      assert.ok(!(invented in app), page + " claims " + invented);
    }
    assert.ok(existsSync(local(app.image)), app.image);
    const shown = [...read(page).matchAll(/<img src="([^"]*screenshots\/[^"]+)"/g)]
      .map((match) => new URL(match[1], new URL(page, SITE)).href);
    assert.deepEqual([...new Set(shown)].sort(), [...app.screenshot].sort(), page + ": the screenshots the page shows");
    for (const shot of app.screenshot) assert.ok(existsSync(local(shot)), shot);
  }
});

const text = (fragment) => decode(fragment.replace(/<[^>]+>/g, "")).trim();

test("the support page's FAQPage mirrors its questions and answers", () => {
  const page = read("support/index.html");
  const graph = jsonLD("support/index.html")["@graph"];
  for (const lang of ["zh-Hans", "zh-Hant", "en"]) {
    const article = new RegExp(`<article id="${lang}" lang="${lang}">([\\s\\S]*?)</article>`).exec(page)[1];
    const shown = [...article.matchAll(/<div class="qa">\s*<h3>([\s\S]*?)<\/h3>\s*<p>([\s\S]*?)<\/p>\s*<\/div>/g)]
      .map((match) => [text(match[1]), text(match[2])]);
    assert.ok(shown.length >= 8, lang + " questions");
    const faq = graph.find((node) => node["@id"] === `${SITE}support/#${lang}`);
    assert.ok(faq, lang);
    assert.equal(faq["@type"], "FAQPage");
    assert.equal(faq.inLanguage, lang);
    assert.deepEqual(faq.mainEntity.map((question) => {
      assert.equal(question["@type"], "Question");
      assert.equal(question.acceptedAnswer["@type"], "Answer");
      return [question.name, question.acceptedAnswer.text];
    }), shown, lang);
  }
});

const PAGES = [...Object.values(PRODUCT), ...Object.values(DOCUMENTS)].map((page) => page.url);

test("the sitemap lists every page, and robots.txt points to it", () => {
  const sitemap = read("sitemap.xml");
  assert.match(sitemap, /^<\?xml version="1.0" encoding="UTF-8"\?>\n<urlset xmlns="http:\/\/www.sitemaps.org\/schemas\/sitemap\/0.9"/);
  const locations = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
  assert.deepEqual([...locations].sort(), [...PAGES].sort());
  for (const location of locations) assert.ok(existsSync(local(location)), location);
  // The product pages' alternates match the ones in their heads.
  for (const [page, expected] of Object.entries(PRODUCT)) {
    const entry = new RegExp(`<url>\\s*<loc>${expected.url}</loc>([\\s\\S]*?)</url>`).exec(sitemap)[1];
    const alternates = Object.fromEntries([...entry.matchAll(/<xhtml:link rel="alternate" hreflang="([^"]+)" href="([^"]+)"\/>/g)]
      .map((match) => [match[1], match[2]]));
    assert.deepEqual(alternates, hreflangs(page), page);
  }
  const robots = read("robots.txt");
  assert.match(robots, /^User-agent: \*$/m);
  assert.doesNotMatch(robots, /^Disallow: \/$/m);
  assert.match(robots, new RegExp(`^Sitemap: ${SITE}sitemap.xml$`, "m"));
});

test("llms.txt names the app and links only to pages that exist", () => {
  const llms = read("llms.txt");
  assert.match(llms, /^# 时光 · Days Remember\n\n> /);
  assert.match(llms, /not on the App Store yet/);
  const links = [...llms.matchAll(/\]\((https:\/\/days\.gooday\.dev\/[^)]*)\)/g)].map((match) => match[1]);
  assert.deepEqual([...links].sort(), [...PAGES].sort());
});

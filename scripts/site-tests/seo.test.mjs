// Checks for the product site's search and sharing metadata (docs/). Run with `node --test scripts/site-tests`.
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const docs = new URL("../../docs/", import.meta.url);
const read = (path) => readFileSync(new URL(path, docs), "utf8");
const SITE = "https://days.gooday.dev/";

const PRODUCT = {
  "index.html": { lang: "zh-Hans", url: SITE, title: "时光 – 纪念日倒数日 App｜农历生日提醒、iPhone 小组件", free: "免费" },
  "zh-Hant/index.html": { lang: "zh-Hant", url: SITE + "zh-Hant/", title: "時光 – 紀念日倒數日 App｜農曆生日提醒、iPhone 小工具", free: "免費" },
  "en/index.html": { lang: "en", url: SITE + "en/", title: "Days Remember – Anniversary & Countdown App for iPhone", free: "free" }
};
// The privacy policy and support pages, one per language like the product pages.
const PREFIX = { "zh-Hans": "", "zh-Hant": "zh-Hant/", en: "en/" };
const DOCUMENTS = Object.fromEntries(Object.entries({
  privacy: { "zh-Hans": "隐私政策 – 时光", "zh-Hant": "隱私權政策 – 時光", en: "Privacy Policy – Days Remember" },
  support: { "zh-Hans": "支持 – 时光", "zh-Hant": "支援 – 時光", en: "Support – Days Remember" }
}).flatMap(([name, titles]) => Object.entries(titles).map(([lang, title]) => [
  `${PREFIX[lang]}${name}/index.html`, { lang, title, name, url: `${SITE}${PREFIX[lang]}${name}/` }
])));
const alternatesOf = (name) => ({
  "zh-Hans": SITE + name, "zh-Hant": SITE + "zh-Hant/" + name, en: SITE + "en/" + name, "x-default": SITE + name
});

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
    assert.deepEqual(hreflangs(page), alternatesOf(""), page);
    assert.match(read(page), new RegExp(`<html lang="${expected.lang}">`), page);
    checkShareImage(page);
  }
});

test("each privacy and support page is in one language, with its alternates and share card", () => {
  for (const [page, expected] of Object.entries(DOCUMENTS)) {
    assert.match(read(page), new RegExp(`<html lang="${expected.lang}">`), page);
    assert.equal(title(page), expected.title, page);
    assert.equal(meta(page, "og:title"), expected.title, page);
    assert.ok(meta(page, "description"), page);
    assert.equal(meta(page, "og:description"), meta(page, "description"), page);
    assert.equal(link(page, "canonical"), expected.url, page);
    assert.equal(meta(page, "og:url"), expected.url, page);
    assert.deepEqual(hreflangs(page), alternatesOf(expected.name + "/"), page);
    assert.equal(meta(page, "og:image"), `${SITE}assets/og/${expected.lang}.jpg`, page);
    checkShareImage(page);
    // One language per page: no section of the page switches to another.
    assert.doesNotMatch(read(page).split("</head>")[1].replace(/<a [^>]*lang="[^"]+"[^>]*>[^<]*<\/a>/g, ""),
                        / lang="/, page);
  }
});

// App Store review and readers look for a way to reach the developer on both pages.
test("each privacy and support page gives the support email", () => {
  for (const page of Object.keys(DOCUMENTS)) {
    assert.match(read(page), /<a href="mailto:support@gooday\.dev">support@gooday\.dev<\/a>/, page);
  }
});

// Links shared before the split pointed at /support/#en and the like; the Simplified page sends them on.
test("the old section links still reach their language", () => {
  for (const name of ["privacy", "support"]) {
    const script = /<script>([\s\S]*?)<\/script>/.exec(head(`${name}/index.html`))[1];
    let replaced = null;
    for (const hash of ["#zh-Hant", "#en", "#zh-Hans", ""]) {
      replaced = null;
      new Function("location", script)({ hash, replace: (to) => { replaced = to; } });
      const expected = { "#zh-Hant": "../zh-Hant/" + name + "/", "#en": "../en/" + name + "/" }[hash] ?? null;
      assert.equal(replaced, expected, name + hash);
      if (expected) assert.ok(existsSync(new URL(`${name}/${expected}index.html`, docs)), expected);
    }
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
    const shown = [...read(page).matchAll(/<img src="([^"]*assets\/screens\/[^"]+)"/g)]
      .map((match) => new URL(match[1], new URL(page, SITE)).href);
    assert.deepEqual([...new Set(shown)].sort(), [...app.screenshot].sort(), page + ": the screenshots the page shows");
    for (const shot of app.screenshot) assert.ok(existsSync(local(shot)), shot);
  }
});

// The pages show 900 px WebP copies (scripts/web-screenshots.sh); the 1320 px JPEGs are for the App Store.
test("the pages show a WebP copy of every App Store screenshot", () => {
  for (const lang of ["zh-Hans", "zh-Hant", "en"]) {
    const store = readdirSync(new URL(`screenshots/${lang}/`, docs)).filter((name) => name.endsWith(".jpg"));
    const web = readdirSync(new URL(`assets/screens/${lang}/`, docs)).filter((name) => name.endsWith(".webp"));
    assert.deepEqual(web.sort(), store.map((name) => name.replace(/\.jpg$/, ".webp")).sort(), lang);
    for (const name of web) {
      const bytes = readFileSync(new URL(`assets/screens/${lang}/${name}`, docs));
      assert.equal(bytes.toString("ascii", 8, 12), "WEBP", name);
      assert.ok(bytes.length < 120 * 1024, `${lang}/${name}: ${bytes.length} bytes`);
    }
  }
  for (const page of Object.keys(PRODUCT)) {
    for (const match of read(page).matchAll(/<img src="[^"]*assets\/screens\/[^"]+" width="(\d+)" height="(\d+)"/g)) {
      assert.deepEqual([match[1], match[2]], ["900", "1956"], page);
    }
  }
});

const text = (fragment) => decode(fragment.replace(/<[^>]+>/g, "")).trim();

test("each support page has one FAQPage that mirrors its questions and answers", () => {
  for (const [page, expected] of Object.entries(DOCUMENTS).filter(([, document]) => document.name === "support")) {
    const lang = expected.lang;
    assert.equal(read(page).match(/<script type="application\/ld\+json">/g).length, 1, page);
    const article = /<article>([\s\S]*?)<\/article>/.exec(read(page))[1];
    const shown = [...article.matchAll(/<div class="qa">\s*<h3>([\s\S]*?)<\/h3>\s*<p>([\s\S]*?)<\/p>\s*<\/div>/g)]
      .map((match) => [text(match[1]), text(match[2])]);
    assert.ok(shown.length >= 8, lang + " questions");
    const faq = jsonLD(page);
    assert.equal(faq["@context"], "https://schema.org");
    assert.equal(faq["@type"], "FAQPage");
    assert.equal(faq["@id"], expected.url + "#faq");
    assert.equal(faq.url, expected.url);
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
  // Every page's alternates match the ones in its head.
  for (const [page, expected] of Object.entries({ ...PRODUCT, ...DOCUMENTS })) {
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

// Cloudflare answers /en and /en/index.html with a temporary 307 unless _redirects says otherwise.
test("every other address of a page redirects permanently to it, without loops", () => {
  const rules = read("_redirects").split("\n").filter((line) => line && !line.startsWith("#"))
    .map((line) => line.split(/\s+/));
  for (const rule of rules) assert.equal(rule.length, 3, rule.join(" "));
  const redirects = Object.fromEntries(rules.map(([from, to, status]) => [from, { to, status }]));
  assert.equal(Object.keys(redirects).length, rules.length, "one rule per source");
  for (const url of PAGES) {
    const path = "/" + url.slice(SITE.length);
    const others = path === "/" ? ["/index.html"] : [path.slice(0, -1), path + "index.html"];
    for (const other of others) assert.deepEqual(redirects[other], { to: path, status: "301" }, other);
  }
  for (const { to } of Object.values(redirects)) {
    assert.ok(PAGES.includes(SITE + to.slice(1)), to);
    assert.ok(!(to in redirects), "loops at " + to);
  }
});

test("llms.txt names the app and links only to pages that exist", () => {
  const llms = read("llms.txt");
  assert.match(llms, /^# 时光 · Days Remember\n\n> /);
  assert.match(llms, /not on the App Store yet/);
  const links = [...llms.matchAll(/\]\((https:\/\/days\.gooday\.dev\/[^)]*)\)/g)].map((match) => match[1]);
  assert.deepEqual([...links].sort(), [...PAGES].sort());
});

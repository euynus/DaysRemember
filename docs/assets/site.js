// Today's date line, the countdown demo and the page's motion. Like the app, days turn over at
// midnight Beijing time.
(function () {
  "use strict";

  var TIME_ZONE = "Asia/Shanghai";
  var DAY = 86400000;
  var root = document.documentElement;
  var lang = root.lang;
  // Set by the head script unless reduced motion is asked for.
  var motion = root.classList.contains("motion");

  var TEXT = {
    "zh-Hans": {
      locale: "zh-CN",
      ahead: "天后", ago: "天前", today: "今天",
      elapsed: function (n) { return "已过 " + n + " 天"; },
      anniversary: function (n) { return "第" + n + "周年"; },
      months: ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"],
      leap: "闰",
      fullDate: function (y, m, d) { return y + "年" + m + "月" + d + "日"; }
    },
    "zh-Hant": {
      locale: "zh-TW",
      ahead: "天後", ago: "天前", today: "今天",
      elapsed: function (n) { return "已過 " + n + " 天"; },
      anniversary: function (n) { return "第" + n + "週年"; },
      months: ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "臘"],
      leap: "閏",
      fullDate: function (y, m, d) { return y + "年" + m + "月" + d + "日"; }
    },
    en: {
      locale: "en-US",
      ahead: "days to go", aheadOne: "day to go", ago: "days ago", agoOne: "day ago", today: "Today",
      elapsed: function (n, raw) { return n + (raw === 1 ? " day elapsed" : " days elapsed"); },
      anniversary: function (n) { return "Anniversary " + n; },
      fullDate: function (y, m, d) {
        return new Intl.DateTimeFormat("en-US", { timeZone: "UTC", year: "numeric", month: "long", day: "numeric" })
          .format(new Date(Date.UTC(y, m - 1, d)));
      }
    }
  }[lang];
  if (!TEXT) return;

  var number = new Intl.NumberFormat(TEXT.locale);

  // Counts the text of `element` from `from` to `to`, easing out; returns a function that stops it.
  function countTo(element, from, to, duration, done) {
    var start = null;
    var frame = requestAnimationFrame(function step(now) {
      if (start === null) start = now;
      var progress = Math.min((now - start) / duration, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      element.textContent = number.format(Math.round(from + (to - from) * eased));
      if (progress < 1) frame = requestAnimationFrame(step);
      else if (done) done();
    });
    return function () { cancelAnimationFrame(frame); };
  }

  function beijingToday() {
    var parts = {};
    new Intl.DateTimeFormat("en-US", { timeZone: TIME_ZONE, year: "numeric", month: "numeric", day: "numeric" })
      .formatToParts(new Date())
      .forEach(function (part) { parts[part.type] = Number(part.value); });
    return { y: parts.year, m: parts.month, d: parts.day };
  }

  function dayNumber(y, m, d) { return Math.round(Date.UTC(y, m - 1, d) / DAY); }

  function isLeapYear(y) { return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0; }

  // February 29 falls on March 1 in common years, as in the app.
  function anniversaryIn(year, m, d) {
    if (m === 2 && d === 29 && !isLeapYear(year)) return dayNumber(year, 3, 1);
    return dayNumber(year, m, d);
  }

  function lunarDay(d) {
    var ones = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"];
    if (d === 10) return "初十";
    if (d === 20) return "二十";
    if (d === 30) return "三十";
    return ["初", "十", "廿", "卅"][Math.floor(d / 10)] + ones[(d % 10) - 1];
  }

  // The app's 1900–2100 lunar table (LunarTable.swift), one word a year: bits 4–15 give months 12–1
  // 30 days, bits 0–3 the leap month, bit 16 a 30-day leap month. Browsers' Chinese calendars are
  // computed and can put a new moon on the wrong side of Beijing midnight (2027 and 2030 in ICU).
  var LUNAR_INFO = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x06566, 0x0d4a0, 0x0ea50, 0x16a95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x05ac0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06aa0, 0x1a6c4, 0x0aae0,
    0x092e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
    0x0d520
  ];

  function monthDays(year, month) { return LUNAR_INFO[year - 1900] & (0x10000 >> month) ? 30 : 29; }

  function leapMonth(year) { return LUNAR_INFO[year - 1900] & 0xf; }

  function leapDays(year) { return leapMonth(year) ? (LUNAR_INFO[year - 1900] & 0x10000 ? 30 : 29) : 0; }

  function lunarDate(y, m, d) {
    var offset = dayNumber(y, m, d) - dayNumber(1900, 1, 31);
    for (var year = 1900; offset >= 0 && year < 1900 + LUNAR_INFO.length; year++) {
      for (var month = 1; month <= 12; month++) {
        var length = monthDays(year, month);
        if (offset < length) return { month: month, day: offset + 1, leap: false };
        offset -= length;
        if (month === leapMonth(year)) {
          if (offset < leapDays(year)) return { month: month, day: offset + 1, leap: true };
          offset -= leapDays(year);
        }
      }
    }
    return null;
  }

  function lunarToday() {
    var today = beijingToday();
    var lunar = lunarDate(today.y, today.m, today.d);
    if (!lunar) return "";
    if (lang === "en") return (lunar.leap ? "Leap month " : "Month ") + lunar.month + ", Day " + lunar.day;
    return (lunar.leap ? TEXT.leap : "") + TEXT.months[lunar.month - 1] + "月" + lunarDay(lunar.day);
  }

  function renderToday() {
    var target = document.querySelector("[data-today]");
    if (!target) return;
    var now = new Date();
    var solar = lang === "en"
      ? new Intl.DateTimeFormat("en-US", { timeZone: TIME_ZONE, weekday: "long", month: "long", day: "numeric" }).format(now)
      : new Intl.DateTimeFormat(TEXT.locale, { timeZone: TIME_ZONE, month: "long", day: "numeric" }).format(now) + " " +
        new Intl.DateTimeFormat(TEXT.locale, { timeZone: TIME_ZONE, weekday: "long" }).format(now);
    var lunar = lunarToday();
    target.textContent = lunar ? solar + " · " + lunar : solar;
  }

  function renderDemo() {
    var form = document.querySelector("[data-demo]");
    if (!form) return;
    var titleInput = form.querySelector("#demo-title");
    var dateInput = form.querySelector("#demo-date");
    var recurringInput = form.querySelector("#demo-recurring");
    var card = document.querySelector("[data-demo-card]");
    var titleOut = card.querySelector("[data-title]");
    var dateOut = card.querySelector("[data-date]");
    var figure = card.querySelector(".figure");
    var valueOut = figure.querySelector("b");
    var unitOut = figure.querySelector("small");
    var elapsedOut = card.querySelector("[data-elapsed]");
    var revealed = false;
    var stop = function () {};
    var target = null;

    function shownCount() {
      var digits = valueOut.textContent.replace(/\D/g, "");
      return digits ? Number(digits) : null;
    }

    // Counts on from the number already shown. The card is a live region, so it stays busy while
    // counting and only the final number is announced.
    function show(count, from) {
      target = count;
      stop();
      card.removeAttribute("aria-busy");
      if (!motion || !revealed || from === null || from === count) {
        valueOut.textContent = number.format(count);
        return;
      }
      card.setAttribute("aria-busy", "true");
      stop = countTo(valueOut, from, count, 600, function () { card.removeAttribute("aria-busy"); });
    }

    function update() {
      titleOut.textContent = titleInput.value.trim() || titleInput.placeholder;
      var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateInput.value);
      if (!match) return;
      var y = Number(match[1]), m = Number(match[2]), d = Number(match[3]);
      if (y < 1900 || y > 2100) return;
      var today = beijingToday();
      var t = dayNumber(today.y, today.m, today.d);
      var original = dayNumber(y, m, d);
      var target = original;
      var label = TEXT.fullDate(y, m, d);
      var elapsed = "";

      if (recurringInput.checked && original < t) {
        var year = today.y;
        target = anniversaryIn(year, m, d);
        if (target < t) { year += 1; target = anniversaryIn(year, m, d); }
        var next = new Date(target * DAY);
        label = TEXT.anniversary(year - y) + " · " +
          TEXT.fullDate(next.getUTCFullYear(), next.getUTCMonth() + 1, next.getUTCDate());
        elapsed = TEXT.elapsed(number.format(t - original), t - original);
      }

      var diff = target - t;
      dateOut.textContent = label;
      elapsedOut.textContent = elapsed;
      figure.classList.toggle("is-today", diff === 0);
      if (diff === 0) {
        target = null;
        stop();
        card.removeAttribute("aria-busy");
        valueOut.textContent = TEXT.today;
        unitOut.textContent = "";
      } else {
        var count = Math.abs(diff);
        show(count, shownCount());
        unitOut.textContent = diff > 0
          ? (count === 1 && TEXT.aheadOne) || TEXT.ahead
          : (count === 1 && TEXT.agoOne) || TEXT.ago;
      }
    }

    form.addEventListener("input", update);
    form.addEventListener("submit", function (event) { event.preventDefault(); });
    // Counts up from zero the first time the card comes into view.
    card.addEventListener("reveal", function () {
      revealed = true;
      var count = shownCount();
      if (count !== null) show(count, 0);
    });
    window.addEventListener("beforeprint", function () {
      stop();
      card.removeAttribute("aria-busy");
      if (target !== null) valueOut.textContent = number.format(target);
    });
    update();
  }

  // Feature figures count up as their rows come into view; 7·3·1 stays as it is.
  function countUpFigures() {
    if (!motion) return;
    var rows = document.querySelectorAll(".row.reveal");
    Array.prototype.forEach.call(rows, function (row) {
      var figure = row.querySelector(".figure b");
      if (!figure || !/^\d+$/.test(figure.textContent)) return;
      var to = Number(figure.textContent);
      // Holding the final width keeps the row from reflowing while the digits change.
      figure.style.minWidth = figure.getBoundingClientRect().width + "px";
      figure.textContent = number.format(0);
      var stop = function () {};
      row.addEventListener("reveal", function () {
        stop = countTo(figure, 0, to, 900, function () { figure.style.minWidth = ""; });
      });
      // Print shows every row at once (site.css), with nothing left to count.
      window.addEventListener("beforeprint", function () {
        stop();
        figure.textContent = number.format(to);
        figure.style.minWidth = "";
      });
    });
  }

  // Each .reveal shows as it comes into view (site.css) and gets a "reveal" event. Marking the page
  // ready stops the head script from taking .motion back.
  function revealOnScroll() {
    if (!motion) return;
    root.setAttribute("data-motion-ready", "");
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("in");
        entry.target.dispatchEvent(new CustomEvent("reveal"));
        observer.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
    var targets = document.querySelectorAll(".reveal");
    for (var i = 0; i < targets.length; i++) observer.observe(targets[i]);
  }

  // The hero phone cross-fades through the screenshots below it, once the page has loaded and only
  // while it is on screen.
  function cyclePhone() {
    var phone = document.querySelector(".hero .phone");
    var shots = document.querySelectorAll(".shots img");
    if (!motion || !phone || shots.length < 2) return;

    function start() {
      var frames = Array.prototype.map.call(shots, function (shot) {
        var frame = new Image();
        frame.alt = "";
        frame.decoding = "async";
        frame.src = shot.src;
        phone.appendChild(frame);
        return frame;
      });
      var current = 0;
      var layer = 1;
      var visible = true;
      frames[current].classList.add("is-current");
      new IntersectionObserver(function (entries) { visible = entries[0].isIntersecting; }).observe(phone);
      setInterval(function () {
        var index = (current + 1) % frames.length;
        var next = frames[index];
        if (!visible || document.hidden || !next.complete || !next.naturalWidth) return;
        var previous = frames[current];
        current = index;
        next.style.zIndex = String(++layer);
        next.classList.add("is-current");
        setTimeout(function () { previous.classList.remove("is-current"); }, 900);
      }, 3200);
    }

    if (document.readyState === "complete") start();
    else window.addEventListener("load", start);
  }

  renderToday();
  renderDemo();
  countUpFigures();
  revealOnScroll();
  cyclePhone();
})();

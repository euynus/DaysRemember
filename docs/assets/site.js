// Today's date line and the countdown demo. Like the app, days turn over at midnight Beijing time.
(function () {
  "use strict";

  var TIME_ZONE = "Asia/Shanghai";
  var DAY = 86400000;
  var lang = document.documentElement.lang;

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

  function lunarToday() {
    try {
      var parts = {};
      new Intl.DateTimeFormat("en-u-ca-chinese", { timeZone: TIME_ZONE, month: "numeric", day: "numeric" })
        .formatToParts(new Date())
        .forEach(function (part) { parts[part.type] = part.value; });
      var month = parseInt(parts.month, 10);
      var day = parseInt(parts.day, 10);
      var leap = /bis/.test(parts.month);
      if (!(month >= 1 && month <= 12 && day >= 1 && day <= 30)) return "";
      if (lang === "en") return (leap ? "Leap month " : "Month ") + month + ", Day " + day;
      return (leap ? TEXT.leap : "") + TEXT.months[month - 1] + "月" + lunarDay(day);
    } catch (error) {
      return "";
    }
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

    function update() {
      titleOut.textContent = titleInput.value.trim() || titleInput.placeholder;
      var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateInput.value);
      if (!match) return;
      var y = Number(match[1]), m = Number(match[2]), d = Number(match[3]);
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
        valueOut.textContent = TEXT.today;
        unitOut.textContent = "";
      } else {
        var count = Math.abs(diff);
        valueOut.textContent = number.format(count);
        unitOut.textContent = diff > 0
          ? (count === 1 && TEXT.aheadOne) || TEXT.ahead
          : (count === 1 && TEXT.agoOne) || TEXT.ago;
      }
    }

    form.addEventListener("input", update);
    form.addEventListener("submit", function (event) { event.preventDefault(); });
    update();
  }

  renderToday();
  renderDemo();
})();

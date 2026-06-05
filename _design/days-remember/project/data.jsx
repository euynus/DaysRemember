/* Shared data — today is 2026-04-23 */

const TODAY = new Date(2026, 3, 23); // April 23, 2026

function daysBetween(a, b) {
  const ms = new Date(b.getFullYear(), b.getMonth(), b.getDate()) - new Date(a.getFullYear(), a.getMonth(), a.getDate());
  return Math.round(ms / 86400000);
}
function fmtCN(d) {
  return `${d.getFullYear()}年${d.getMonth()+1}月${d.getDate()}日`;
}
function fmtCNShort(d) {
  return `${d.getMonth()+1}月${d.getDate()}日`;
}
const WEEKDAY = ['日','一','二','三','四','五','六'];
function weekday(d) { return '星期' + WEEKDAY[d.getDay()]; }

// Sample days — mix past anniversaries & future countdowns
const DAYS = [
  {
    id: 'wedding',
    title: '结婚纪念日',
    date: new Date(2019, 9, 12), // 2019-10-12 (past, recurring)
    recurring: true,
    category: 'love',
    categoryLabel: '爱情',
    photo: 'photo-wedding',
    note: '那天下了一场小雨，你笑着说是天使撒花。',
    location: '杭州 · 西湖',
    pinned: true,
  },
  {
    id: 'baby',
    title: '小年糕出生',
    date: new Date(2023, 1, 14), // past
    recurring: false,
    category: 'family',
    categoryLabel: '家人',
    photo: 'photo-baby',
    note: '6斤3两，凌晨3:47。',
    location: '上海 · 第一妇婴',
    pinned: true,
  },
  {
    id: 'birthday',
    title: '妈妈生日',
    date: new Date(1962, 5, 18), // recurring
    recurring: true,
    lunar: true, // 农历生日 — 1962 五月十七
    category: 'family',
    categoryLabel: '家人',
    photo: 'photo-birthday',
    note: '今年是 64 岁，要订桂花糖藕。',
    location: '',
    pinned: false,
  },
  {
    id: 'midautumn',
    title: '中秋团圆',
    date: new Date(2025, 9, 6), // 农历 8/15
    recurring: true,
    lunar: true,
    category: 'family',
    categoryLabel: '家人',
    photo: 'photo-home',
    note: '今年回家吃妈妈做的月饼。',
    location: '',
    pinned: false,
  },
  {
    id: 'japan',
    title: '北海道旅行',
    date: new Date(2026, 6, 20), // future
    recurring: false,
    category: 'travel',
    categoryLabel: '旅行',
    photo: 'photo-japan',
    note: '札幌→小樽→函馆，记得提前订民宿。',
    location: '日本 · 北海道',
    pinned: false,
  },
  {
    id: 'kaoyan',
    title: '考研初试',
    date: new Date(2026, 11, 20), // future
    recurring: false,
    category: 'work',
    categoryLabel: '学业',
    photo: 'photo-study',
    note: '今天背了 80 个单词，还差 1200。',
    location: '',
    pinned: false,
  },
  {
    id: 'firstmet',
    title: '与他相遇',
    date: new Date(2017, 2, 8), // past
    recurring: false,
    category: 'love',
    categoryLabel: '爱情',
    photo: 'photo-memorial',
    note: '图书馆三楼，靠窗的位置。',
    location: '',
    pinned: false,
  },
  {
    id: 'work',
    title: '入职周年',
    date: new Date(2021, 7, 1),
    recurring: true,
    category: 'work',
    categoryLabel: '工作',
    photo: 'photo-work',
    note: '',
    location: '',
    pinned: false,
  },
  {
    id: 'dog',
    title: '领养豆豆',
    date: new Date(2020, 4, 30),
    recurring: false,
    category: 'family',
    categoryLabel: '家人',
    photo: 'photo-pet',
    note: '从流浪动物救助站带回家的那天。',
    location: '',
    pinned: false,
  },
  {
    id: 'moved',
    title: '搬进新家',
    date: new Date(2024, 10, 5),
    recurring: false,
    category: 'life',
    categoryLabel: '生活',
    photo: 'photo-home',
    note: '',
    location: '上海 · 徐汇',
    pinned: false,
  },
];

// Compute display info
function dayInfo(d, today = TODAY) {
  let displayDate = d.date;
  let isPast = false;
  if (d.recurring) {
    if (d.lunar && typeof solarToLunar === 'function') {
      // find next lunar anniversary
      const srcLunar = solarToLunar(d.date);
      for (let y = today.getFullYear(); y <= today.getFullYear() + 2; y++) {
        const try1 = lunarToSolar(y, srcLunar.lMonth, srcLunar.lDay, srcLunar.isLeap);
        if (try1 >= today) { displayDate = try1; break; }
      }
    } else {
      const thisYear = new Date(today.getFullYear(), d.date.getMonth(), d.date.getDate());
      if (thisYear < today) {
        displayDate = new Date(today.getFullYear() + 1, d.date.getMonth(), d.date.getDate());
      } else {
        displayDate = thisYear;
      }
    }
  }
  const diff = daysBetween(today, displayDate);
  isPast = diff < 0;
  return {
    days: Math.abs(diff),
    isPast,
    isToday: diff === 0,
    displayDate,
    yearsAgo: d.recurring ? today.getFullYear() - d.date.getFullYear() : null,
    totalDaysSinceBirth: d.recurring ? daysBetween(d.date, today) : null,
  };
}

const CATEGORY_COLORS = {
  love: 'var(--cat-love)',
  family: 'var(--cat-family)',
  travel: 'var(--cat-travel)',
  work: 'var(--cat-work)',
  life: 'var(--cat-life)',
};
const CATEGORY_SOFT = {
  love: 'var(--note-pink)',
  family: 'var(--note-peach)',
  travel: 'var(--note-blue)',
  work: 'var(--note-green)',
  life: 'var(--note-yellow)',
};

Object.assign(window, { TODAY, DAYS, dayInfo, daysBetween, fmtCN, fmtCNShort, weekday, CATEGORY_COLORS, CATEGORY_SOFT });

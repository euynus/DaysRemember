/* Chinese lunar calendar — compact implementation
   Data covers 1900-2100. Adapted from classic lunar tables. */

const LUNAR_INFO = [
  0x04bd8,0x04ae0,0x0a570,0x054d5,0x0d260,0x0d950,0x16554,0x056a0,0x09ad0,0x055d2,
  0x04ae0,0x0a5b6,0x0a4d0,0x0d250,0x1d255,0x0b540,0x0d6a0,0x0ada2,0x095b0,0x14977,
  0x04970,0x0a4b0,0x0b4b5,0x06a50,0x06d40,0x1ab54,0x02b60,0x09570,0x052f2,0x04970,
  0x06566,0x0d4a0,0x0ea50,0x06e95,0x05ad0,0x02b60,0x186e3,0x092e0,0x1c8d7,0x0c950,
  0x0d4a0,0x1d8a6,0x0b550,0x056a0,0x1a5b4,0x025d0,0x092d0,0x0d2b2,0x0a950,0x0b557,
  0x06ca0,0x0b550,0x15355,0x04da0,0x0a5b0,0x14573,0x052b0,0x0a9a8,0x0e950,0x06aa0,
  0x0aea6,0x0ab50,0x04b60,0x0aae4,0x0a570,0x05260,0x0f263,0x0d950,0x05b57,0x056a0,
  0x096d0,0x04dd5,0x04ad0,0x0a4d0,0x0d4d4,0x0d250,0x0d558,0x0b540,0x0b6a0,0x195a6,
  0x095b0,0x049b0,0x0a974,0x0a4b0,0x0b27a,0x06a50,0x06d40,0x0af46,0x0ab60,0x09570,
  0x04af5,0x04970,0x064b0,0x074a3,0x0ea50,0x06b58,0x055c0,0x0ab60,0x096d5,0x092e0,
  0x0c960,0x0d954,0x0d4a0,0x0da50,0x07552,0x056a0,0x0abb7,0x025d0,0x092d0,0x0cab5,
  0x0a950,0x0b4a0,0x0baa4,0x0ad50,0x055d9,0x04ba0,0x0a5b0,0x15176,0x052b0,0x0a930,
  0x07954,0x06aa0,0x0ad50,0x05b52,0x04b60,0x0a6e6,0x0a4e0,0x0d260,0x0ea65,0x0d530,
  0x05aa0,0x076a3,0x096d0,0x04afb,0x04ad0,0x0a4d0,0x1d0b6,0x0d250,0x0d520,0x0dd45,
  0x0b5a0,0x056d0,0x055b2,0x049b0,0x0a577,0x0a4b0,0x0aa50,0x1b255,0x06d20,0x0ada0,
  0x14b63,0x09370,0x049f8,0x04970,0x064b0,0x168a6,0x0ea50,0x06b20,0x1a6c4,0x0aae0,
  0x0a2e0,0x0d2e3,0x0c960,0x0d557,0x0d4a0,0x0da50,0x05d55,0x056a0,0x0a6d0,0x055d4,
  0x052d0,0x0a9b8,0x0a950,0x0b4a0,0x0b6a6,0x0ad50,0x055a0,0x0aba4,0x0a5b0,0x052b0,
  0x0b273,0x06930,0x07337,0x06aa0,0x0ad50,0x14b55,0x04b60,0x0a570,0x054e4,0x0d160,
  0x0e968,0x0d520,0x0daa0,0x16aa6,0x056d0,0x04ae0,0x0a9d4,0x0a2d0,0x0d150,0x0f252,
  0x0d520 // 2100
];

const GAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const ZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
const ZODIAC = ['鼠','牛','虎','兔','龙','蛇','马','羊','猴','鸡','狗','猪'];
const CN_MONTH = ['正','二','三','四','五','六','七','八','九','十','冬','腊'];
const CN_DAY_PREFIX = ['初','十','廿','卅'];
const CN_NUM = ['一','二','三','四','五','六','七','八','九','十'];

function leapMonth(y) { return LUNAR_INFO[y - 1900] & 0xf; }
function leapDays(y) { return leapMonth(y) ? (LUNAR_INFO[y - 1900] & 0x10000 ? 30 : 29) : 0; }
function monthDays(y, m) { return (LUNAR_INFO[y - 1900] & (0x10000 >> m)) ? 30 : 29; }
function yearDays(y) {
  let sum = 348;
  for (let i = 0x8000; i > 0x8; i >>= 1) sum += (LUNAR_INFO[y - 1900] & i) ? 1 : 0;
  return sum + leapDays(y);
}

// Convert Gregorian Date -> { lYear, lMonth, lDay, isLeap }
function solarToLunar(date) {
  const BASE = new Date(1900, 0, 31);
  let offset = Math.floor((date - BASE) / 86400000);
  let y = 1900, temp = 0;
  for (; y < 2101 && offset > 0; y++) {
    temp = yearDays(y);
    offset -= temp;
  }
  if (offset < 0) { offset += temp; y--; }

  const leap = leapMonth(y);
  let isLeap = false, m = 1;
  for (; m < 13 && offset > 0; m++) {
    if (leap > 0 && m === leap + 1 && !isLeap) {
      --m; isLeap = true; temp = leapDays(y);
    } else {
      temp = monthDays(y, m);
    }
    if (isLeap && m === leap + 1) isLeap = false;
    offset -= temp;
  }
  if (offset === 0 && leap > 0 && m === leap + 1) {
    if (isLeap) isLeap = false; else { isLeap = true; --m; }
  }
  if (offset < 0) { offset += temp; --m; }
  return { lYear: y, lMonth: m, lDay: offset + 1, isLeap };
}

// Convert lunar back to solar (offset from 1900-01-31)
function lunarToSolar(lYear, lMonth, lDay, isLeap = false) {
  let offset = 0;
  for (let y = 1900; y < lYear; y++) offset += yearDays(y);
  const leap = leapMonth(lYear);
  for (let m = 1; m < lMonth; m++) offset += monthDays(lYear, m);
  if (leap > 0 && lMonth > leap) offset += leapDays(lYear);
  if (isLeap && lMonth === leap) offset += monthDays(lYear, lMonth);
  offset += lDay - 1;
  const BASE = new Date(1900, 0, 31);
  return new Date(BASE.getTime() + offset * 86400000);
}

function lunarDayCN(d) {
  if (d === 10) return '初十';
  if (d === 20) return '二十';
  if (d === 30) return '三十';
  const t = Math.floor(d / 10);
  return CN_DAY_PREFIX[t] + CN_NUM[(d % 10 || 10) - 1];
}
function lunarMonthCN(m, isLeap) {
  return (isLeap ? '闰' : '') + CN_MONTH[m - 1] + '月';
}
function ganZhi(y) { return GAN[(y - 4) % 10] + ZHI[(y - 4) % 12]; }
function zodiac(y) { return ZODIAC[(y - 4) % 12]; }

function fmtLunar(date) {
  const { lYear, lMonth, lDay, isLeap } = solarToLunar(date);
  return lunarMonthCN(lMonth, isLeap) + lunarDayCN(lDay);
}
function fmtLunarFull(date) {
  const { lYear, lMonth, lDay, isLeap } = solarToLunar(date);
  return `农历${ganZhi(lYear)}${zodiac(lYear)}年 · ${lunarMonthCN(lMonth, isLeap)}${lunarDayCN(lDay)}`;
}

// 24 solar terms — simplified approximation; returns name if date matches closely
const SOLAR_TERMS = [
  [1,6,'小寒'],[1,20,'大寒'],[2,4,'立春'],[2,19,'雨水'],[3,6,'惊蛰'],[3,21,'春分'],
  [4,5,'清明'],[4,20,'谷雨'],[5,6,'立夏'],[5,21,'小满'],[6,6,'芒种'],[6,21,'夏至'],
  [7,7,'小暑'],[7,23,'大暑'],[8,8,'立秋'],[8,23,'处暑'],[9,8,'白露'],[9,23,'秋分'],
  [10,8,'寒露'],[10,24,'霜降'],[11,8,'立冬'],[11,22,'小雪'],[12,7,'大雪'],[12,22,'冬至'],
];
function solarTerm(date) {
  const m = date.getMonth()+1, d = date.getDate();
  const hit = SOLAR_TERMS.find(([mm,dd]) => mm===m && dd===d);
  return hit ? hit[2] : null;
}

// Common lunar holidays
function lunarHoliday(date) {
  const { lMonth, lDay } = solarToLunar(date);
  const holidays = {
    '1-1':'春节','1-15':'元宵','2-2':'龙抬头','5-5':'端午',
    '7-7':'七夕','7-15':'中元','8-15':'中秋','9-9':'重阳','12-8':'腊八','12-23':'小年',
  };
  return holidays[`${lMonth}-${lDay}`] || null;
}

Object.assign(window, {
  solarToLunar, lunarToSolar, fmtLunar, fmtLunarFull,
  lunarDayCN, lunarMonthCN, ganZhi, zodiac, solarTerm, lunarHoliday,
});

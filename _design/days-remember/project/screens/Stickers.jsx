/* Scrapbook shared components — flat stickers, sticky notes, paperclips, polaroids */

/* ─── Flat vector stickers (white outline + drop shadow via .sticker) ─── */
function Sticker({ name, size = 48, rotate = 0, style = {} }) {
  const s = STICKERS[name];
  if (!s) return null;
  return (
    <div className="sticker" style={{ transform: `rotate(${rotate}deg)`, ...style }}>
      <svg width={size} height={size} viewBox="0 0 64 64" style={{ display: 'block' }}>
        {/* white outline backing */}
        <g stroke="#fff" strokeWidth="6" strokeLinejoin="round" strokeLinecap="round" fill="#fff">{s}</g>
        <g strokeLinejoin="round" strokeLinecap="round">{s}</g>
      </svg>
    </div>
  );
}

const STICKERS = {
  plane: <g>
    <path d="M6 36l52-18-14 30-9-10-9 14-3-15-17-1z" fill="#7FCBE6" stroke="#2E6E88" strokeWidth="2"/>
    <path d="M44 48l-9-10 9 14 3-15z" fill="#5BB0D0" stroke="#2E6E88" strokeWidth="2"/>
  </g>,
  heart: <g>
    <path d="M32 56C12 42 8 30 8 22a13 13 0 0124-7 13 13 0 0124 7c0 8-4 20-24 34z" fill="#F2778E" stroke="#B23E55" strokeWidth="2"/>
  </g>,
  cake: <g>
    <rect x="12" y="30" width="40" height="24" rx="4" fill="#F7B7C8" stroke="#B05670" strokeWidth="2"/>
    <path d="M12 40c6 4 10 4 16 0s10-4 16 0 8 4 8 0" fill="none" stroke="#B05670" strokeWidth="2"/>
    <rect x="30" y="14" width="4" height="12" rx="2" fill="#FBD34D" stroke="#9B7A1E" strokeWidth="2"/>
    <circle cx="32" cy="12" r="3" fill="#F2778E" stroke="#B23E55" strokeWidth="2"/>
  </g>,
  balloon: <g>
    <ellipse cx="32" cy="26" rx="17" ry="20" fill="#F5A623" stroke="#A86A12" strokeWidth="2"/>
    <path d="M32 46l-2 8 4 4-2 4" fill="none" stroke="#A86A12" strokeWidth="2"/>
    <path d="M28 18a8 8 0 014-4" stroke="#fff" strokeWidth="3" fill="none"/>
  </g>,
  ring: <g>
    <circle cx="32" cy="38" r="16" fill="none" stroke="#F5C84B" strokeWidth="6"/>
    <path d="M24 20l8-10 8 10-8 8-8-8z" fill="#9FE0F0" stroke="#3A7CA0" strokeWidth="2"/>
  </g>,
  camera: <g>
    <rect x="8" y="22" width="48" height="32" rx="6" fill="#EF8A5A" stroke="#A8542C" strokeWidth="2"/>
    <path d="M22 22l4-6h12l4 6" fill="#EF8A5A" stroke="#A8542C" strokeWidth="2"/>
    <circle cx="32" cy="38" r="10" fill="#9FE0F0" stroke="#2E6E88" strokeWidth="2"/>
    <circle cx="32" cy="38" r="4" fill="#fff"/>
  </g>,
  star: <g>
    <path d="M32 6l8 16 18 2-13 13 3 18-16-9-16 9 3-18L6 24l18-2z" fill="#FBD34D" stroke="#A8841E" strokeWidth="2"/>
  </g>,
  sun: <g>
    <circle cx="32" cy="32" r="13" fill="#FBD34D" stroke="#A8841E" strokeWidth="2"/>
    <g stroke="#FBD34D" strokeWidth="5"><path d="M32 6v8M32 50v8M6 32h8M50 32h8M14 14l5 5M45 45l5 5M50 14l-5 5M19 45l-5 5"/></g>
  </g>,
  gift: <g>
    <rect x="12" y="28" width="40" height="26" rx="3" fill="#7FCBE6" stroke="#2E6E88" strokeWidth="2"/>
    <rect x="10" y="22" width="44" height="10" rx="2" fill="#5BB0D0" stroke="#2E6E88" strokeWidth="2"/>
    <path d="M32 22V54" stroke="#fff" strokeWidth="4"/>
    <path d="M32 22c-8-12-18-4-10 2M32 22c8-12 18-4 10 2" fill="#F2778E" stroke="#B23E55" strokeWidth="2"/>
  </g>,
  house: <g>
    <path d="M10 30L32 12l22 18v22a2 2 0 01-2 2H12a2 2 0 01-2-2z" fill="#E0795A" stroke="#A8542C" strokeWidth="2"/>
    <rect x="26" y="38" width="12" height="16" fill="#9FE0F0" stroke="#2E6E88" strokeWidth="2"/>
  </g>,
  paw: <g>
    <ellipse cx="32" cy="42" rx="13" ry="11" fill="#F5A623" stroke="#A86A12" strokeWidth="2"/>
    <circle cx="18" cy="26" r="6" fill="#F5A623" stroke="#A86A12" strokeWidth="2"/>
    <circle cx="32" cy="20" r="6" fill="#F5A623" stroke="#A86A12" strokeWidth="2"/>
    <circle cx="46" cy="26" r="6" fill="#F5A623" stroke="#A86A12" strokeWidth="2"/>
  </g>,
  cap: <g>
    <path d="M6 28L32 18l26 10-26 10z" fill="#3A4254" stroke="#1B2230" strokeWidth="2"/>
    <path d="M48 33v10c0 4-32 4-32 0V33" fill="#3A4254" stroke="#1B2230" strokeWidth="2"/>
    <path d="M58 28v12" stroke="#FBD34D" strokeWidth="3"/>
    <circle cx="58" cy="42" r="3" fill="#FBD34D"/>
  </g>,
  sparkle: <g>
    <path d="M32 10c2 12 8 18 20 22-12 4-18 10-20 22-2-12-8-18-20-22 12-4 18-10 20-22z" fill="#9FE0F0" stroke="#3A7CA0" strokeWidth="2"/>
  </g>,
};

// Map a day to its sticker + note color
const DAY_STICKER = {
  wedding: 'ring', baby: 'balloon', birthday: 'cake', japan: 'plane',
  kaoyan: 'cap', firstmet: 'heart', work: 'star', dog: 'paw',
  moved: 'house', midautumn: 'sparkle',
};
const CAT_STICKER = { love: 'heart', family: 'balloon', travel: 'plane', work: 'star', life: 'house' };
const NOTE_COLORS = [
  ['var(--note-blue)', 'var(--note-blue-ink)'],
  ['var(--note-yellow)', 'var(--note-yellow-ink)'],
  ['var(--note-pink)', 'var(--note-pink-ink)'],
  ['var(--note-green)', 'var(--note-green-ink)'],
  ['var(--note-peach)', 'var(--note-peach-ink)'],
];
function noteColorFor(id) {
  let h = 0; for (const c of String(id)) h = (h * 31 + c.charCodeAt(0)) % NOTE_COLORS.length;
  return NOTE_COLORS[h];
}
function stickerFor(day) {
  return DAY_STICKER[day.id] || CAT_STICKER[day.category] || 'star';
}

/* ─── Paperclip ─── */
function Paperclip({ size = 26, color = '#B9BEC6', style = {} }) {
  return (
    <svg width={size} height={size * 1.7} viewBox="0 0 20 34" fill="none" style={style}>
      <path d="M14.5 9v15a5.5 5.5 0 01-11 0V7.5a3.5 3.5 0 017 0V22a1.6 1.6 0 01-3.2 0V9"
        stroke={color} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

/* ─── Sticky note (optionally clipped with a paperclip) ─── */
function StickyNote({ children, color = 'var(--note-blue)', ink = 'var(--note-blue-ink)', rotate = -3, clip = false, size = 'm', style = {} }) {
  const pad = size === 's' ? '8px 10px' : size === 'l' ? '14px 16px' : '10px 12px';
  const fs = size === 's' ? 18 : size === 'l' ? 30 : 22;
  return (
    <div style={{ position: 'relative', display: 'inline-block', transform: `rotate(${rotate}deg)`, ...style }}>
      {clip && (
        <div style={{ position: 'absolute', top: -14, left: '50%', transform: 'translateX(-50%)', zIndex: 3 }}>
          <Paperclip/>
        </div>
      )}
      <div className="sticky" style={{ background: color, color: ink, padding: pad, fontSize: fs, transform: 'none' }}>
        {children}
      </div>
    </div>
  );
}

/* ─── Tape strip (washi tape) ─── */
function Tape({ color = 'rgba(160,210,230,0.7)', w = 64, style = {} }) {
  return (
    <div style={{
      width: w, height: 22, background: color,
      borderLeft: '1px dashed rgba(255,255,255,0.5)', borderRight: '1px dashed rgba(255,255,255,0.5)',
      boxShadow: '0 1px 3px rgba(21,23,28,0.12)', ...style,
    }}/>
  );
}

Object.assign(window, { Sticker, STICKERS, Paperclip, StickyNote, Tape, stickerFor, noteColorFor, DAY_STICKER, CAT_STICKER });

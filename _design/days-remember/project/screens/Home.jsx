/* Screen: Home — travel scrapbook feed of polaroids */

function HomeScreen({ onOpenDay, onAdd }) {
  const [filter, setFilter] = React.useState('all');
  const filters = [
    { id: 'all', label: '全部' },
    { id: 'pinned', label: '置顶' },
    { id: 'love', label: '爱情' },
    { id: 'family', label: '家人' },
    { id: 'travel', label: '旅行' },
    { id: 'work', label: '工作' },
  ];
  const filtered = DAYS.filter(d => filter === 'all' ? true : filter === 'pinned' ? d.pinned : d.category === filter);

  // nearest upcoming as hero
  const hero = DAYS.map(d => ({ d, info: dayInfo(d) }))
    .filter(x => !x.info.isPast).sort((a,b) => a.info.days - b.info.days)[0];
  const rest = filtered.filter(d => !hero || d.id !== hero.d.id);

  const lunar = typeof fmtLunarFull === 'function' ? fmtLunarFull(TODAY) : '';
  const term = typeof solarTerm === 'function' ? solarTerm(TODAY) : null;

  return (
    <div className="sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div style={{ padding: '60px 22px 6px', flexShrink: 0, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 34, fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.05 }}>你好，今天</h1>
          <div className="meta" style={{ marginTop: 8 }}>
            <span>4月23日 星期四</span>
            <span className="dot"/>
            <span>{lunar.replace('农历','').split('·').pop().trim()}</span>
            {term && <><span className="dot"/><span style={{ color: 'var(--cat-travel)', fontWeight: 700 }}>{term}</span></>}
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, flexShrink: 0, marginTop: 2 }}>
          <button className="fab" style={{ width: 42, height: 42 }}>
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="8" cy="8" r="5.5"/><path d="M12 12l4 4"/></svg>
          </button>
          <button className="fab" onClick={onAdd} style={{ width: 42, height: 42, background: 'var(--ink)', color: '#fff' }}>
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round"><path d="M9 3v12M3 9h12"/></svg>
          </button>
        </div>
      </div>

      {/* Filter chips */}
      <div style={{ display: 'flex', gap: 9, padding: '14px 22px 8px', overflowX: 'auto', flexShrink: 0, scrollbarWidth: 'none' }}>
        {filters.map(f => (
          <button key={f.id} className={`chip ${filter===f.id?'on':''}`} style={{ flexShrink: 0 }} onClick={() => setFilter(f.id)}>{f.label}</button>
        ))}
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '12px 22px 130px' }}>
        {/* Hero polaroid */}
        {hero && (filter === 'all') && <HeroPolaroid day={hero.d} info={hero.info} onOpen={onOpenDay}/>}

        {/* Feed grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, marginTop: hero && filter==='all' ? 26 : 4 }}>
          {rest.map((d, i) => <DayPolaroid key={d.id} day={d} idx={i} onOpen={onOpenDay}/>)}
        </div>
      </div>
    </div>
  );
}

function HeroPolaroid({ day, info, onOpen }) {
  const [nc, ni] = noteColorFor(day.id);
  return (
    <div className="sg-tap" onClick={() => onOpen && onOpen(day)} style={{ position: 'relative', cursor: 'pointer', paddingTop: 10 }}>
      <div className="polaroid" style={{ transform: 'rotate(-1.2deg)' }}>
        <div className={`photo ${day.photo}`} style={{ height: 230, position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0) 45%, rgba(0,0,0,0.4) 100%)' }}/>
          {/* eyebrow on photo */}
          <div style={{ position: 'absolute', left: 14, bottom: 12, color: '#fff' }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', opacity: 0.9 }}>即将到来</div>
          </div>
        </div>
        {/* caption strip */}
        <div style={{ padding: '12px 8px 6px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 20, fontWeight: 800, letterSpacing: '-0.02em' }}>{day.title}</div>
            <div className="sg-hand" style={{ fontSize: 22, color: 'var(--ink-2)', lineHeight: 1, marginTop: 2 }}>{enDate(info.displayDate)}</div>
          </div>
          <Sticker name={stickerFor(day)} size={44} rotate={8} style={{ flexShrink: 0 }}/>
        </div>
      </div>
      {/* sticky note clipped, countdown */}
      <div style={{ position: 'absolute', top: -2, right: 6, zIndex: 4 }}>
        <StickyNote color={nc} ink={ni} clip rotate={5} size="m">
          <div style={{ textAlign: 'center', lineHeight: 0.95 }}>
            <div style={{ fontSize: 34, fontWeight: 700 }} className="sg-tnum">{info.days}</div>
            <div style={{ fontSize: 15 }}>天后</div>
          </div>
        </StickyNote>
      </div>
    </div>
  );
}

function DayPolaroid({ day, idx, onOpen }) {
  const info = dayInfo(day);
  const [nc, ni] = noteColorFor(day.id);
  const rot = [(-1.6), 1.4, -1.0, 1.8, -1.3, 1.1][idx % 6];
  const label = info.isToday ? '今天' : info.isPast ? '天前' : '天后';
  return (
    <div className="sg-tap" onClick={() => onOpen && onOpen(day)} style={{ position: 'relative', cursor: 'pointer', paddingTop: 12 }}>
      <div className="polaroid" style={{ transform: `rotate(${rot}deg)`, padding: '7px 7px 7px' }}>
        <div className={`photo ${day.photo}`} style={{ height: 132, position: 'relative' }}>
          {day.pinned && (
            <div style={{ position: 'absolute', top: 7, left: 7, width: 22, height: 22, borderRadius: '50%', background: 'rgba(255,255,255,0.9)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="10" height="10" viewBox="0 0 11 11" fill="var(--cat-love)"><path d="M5.5 0L7 3.5L10.5 4L8 6.5L8.7 10L5.5 8.3L2.3 10L3 6.5L0.5 4L4 3.5Z"/></svg>
            </div>
          )}
        </div>
        <div style={{ padding: '8px 4px 2px' }}>
          <div style={{ fontSize: 14, fontWeight: 800, letterSpacing: '-0.02em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{day.title}</div>
          <div className="sg-hand" style={{ fontSize: 18, color: 'var(--ink-2)', lineHeight: 1, marginTop: 1 }}>{enDate(info.displayDate)}</div>
        </div>
      </div>
      {/* countdown sticky note */}
      <div style={{ position: 'absolute', top: 2, right: -4, zIndex: 4 }}>
        <StickyNote color={nc} ink={ni} rotate={6} size="s">
          <div style={{ textAlign: 'center', lineHeight: 0.9, padding: '0 1px' }}>
            <div style={{ fontSize: 22, fontWeight: 700 }} className="sg-tnum">{info.days}</div>
            <div style={{ fontSize: 11 }}>{label}</div>
          </div>
        </StickyNote>
      </div>
      {/* category sticker peek */}
      <div style={{ position: 'absolute', bottom: 6, left: -8, zIndex: 4 }}>
        <Sticker name={stickerFor(day)} size={30} rotate={-10}/>
      </div>
    </div>
  );
}

// English-style date for handwritten accent: "03 Jun 2026"
function enDate(d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getMonth()];
  return `${String(d.getDate()).padStart(2,'0')} ${m} ${d.getFullYear()}`;
}

Object.assign(window, { HomeScreen, DayPolaroid, enDate });

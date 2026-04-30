/* Screen: Home — asymmetric photo grid */

function HomeScreen({ dark, onOpenDay, onAdd, density = 'comfy', variant = 'mosaic' }) {
  const [filter, setFilter] = React.useState('all');
  const [showSwipe, setShowSwipe] = React.useState(null);

  const filters = [
    { id: 'all', label: '全部' },
    { id: 'pinned', label: '置顶' },
    { id: 'love', label: '爱情' },
    { id: 'family', label: '家人' },
    { id: 'travel', label: '旅行' },
    { id: 'work', label: '工作' },
  ];

  const filtered = DAYS.filter(d => {
    if (filter === 'all') return true;
    if (filter === 'pinned') return d.pinned;
    return d.category === filter;
  });

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      {/* Header */}
      <div style={{ padding: '62px 20px 8px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontSize: 12, color: 'var(--muted)', letterSpacing: '0.3em', textTransform: 'uppercase', marginBottom: 2 }}>4月23日 · 星期四</div>
            <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 30, fontWeight: 600, letterSpacing: '-0.02em' }}>你好，今天</h1>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <IconBtn icon="search"/>
            <IconBtn icon="plus" onClick={onAdd} accent/>
          </div>
        </div>
      </div>

      {/* Filter chips */}
      <div style={{ display: 'flex', gap: 8, padding: '14px 20px 12px', overflowX: 'auto', flexShrink: 0, scrollbarWidth: 'none' }}>
        {filters.map(f => (
          <button key={f.id} onClick={() => setFilter(f.id)} style={{
            border: 'none', flexShrink: 0,
            background: filter === f.id ? 'var(--ink)' : 'var(--card)',
            color: filter === f.id ? 'var(--bg)' : 'var(--ink-2)',
            padding: '7px 14px', borderRadius: 999,
            font: '500 13px var(--sans)', cursor: 'pointer',
            boxShadow: filter === f.id ? 'none' : '0 1px 2px rgba(0,0,0,0.04)',
          }}>{f.label}</button>
        ))}
      </div>

      {/* Today spotlight */}
      <TodaySpotlight/>
      <TodayStrip/>

      {/* Grid */}
      <div className="sg-scroll" style={{ flex: 1, padding: '16px 20px 24px' }}>
        <MosaicGrid days={filtered} onOpen={onOpenDay} showSwipe={showSwipe} setShowSwipe={setShowSwipe}/>
      </div>
    </div>
  );
}

function IconBtn({ icon, onClick, accent }) {
  return (
    <button onClick={onClick} style={{
      width: 40, height: 40, borderRadius: 14, border: 'none',
      background: accent ? 'var(--ink)' : 'var(--card)',
      color: accent ? 'var(--bg)' : 'var(--ink)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer', boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
    }}>
      {icon === 'search' && <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="8" cy="8" r="5.5"/><path d="M12 12l4 4"/></svg>}
      {icon === 'plus' && <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M9 3v12M3 9h12"/></svg>}
    </button>
  );
}

function TodayStrip() {
  if (typeof fmtLunar !== 'function') return null;
  const lunar = fmtLunarFull(TODAY);
  const term = typeof solarTerm === 'function' ? solarTerm(TODAY) : null;
  const holi = typeof lunarHoliday === 'function' ? lunarHoliday(TODAY) : null;
  return (
    <div style={{ padding: '10px 20px 0', flexShrink: 0 }}>
      <div style={{ fontSize: 11, color: 'var(--muted)', fontFamily: 'var(--serif)', display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
        <span>{lunar}</span>
        {term && <span style={{ color: 'var(--terracotta)', fontWeight: 600 }}>· {term}</span>}
        {holi && <span style={{ color: 'var(--terracotta)', fontWeight: 600 }}>· {holi}</span>}
      </div>
    </div>
  );
}

function TodaySpotlight() {
  // Find the nearest upcoming within 10 days
  const soon = DAYS
    .map(d => ({ d, info: dayInfo(d) }))
    .filter(x => !x.info.isPast && x.info.days <= 100)
    .sort((a,b) => a.info.days - b.info.days)[0];
  if (!soon) return null;
  const { d, info } = soon;
  return (
    <div style={{ padding: '0 20px 4px', flexShrink: 0 }}>
      <div className="sg-tap" style={{
        position: 'relative', borderRadius: 20, overflow: 'hidden',
        background: 'linear-gradient(100deg, oklch(0.96 0.02 30) 0%, oklch(0.9 0.04 35) 100%)',
        padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14,
        border: '1px solid var(--hairline)',
      }}>
        <div className={`photo ${d.photo} photo-flat`} style={{ width: 52, height: 52, borderRadius: 14, flexShrink: 0 }}/>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 11, color: 'var(--terracotta)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 2, fontWeight: 600 }}>即将到来</div>
          <div style={{ fontSize: 15, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.title}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 28, fontWeight: 600, color: 'var(--terracotta)', lineHeight: 1 }} className="sg-tnum">{info.days}</div>
          <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 2 }}>天后</div>
        </div>
      </div>
    </div>
  );
}

function MosaicGrid({ days, onOpen, showSwipe, setShowSwipe }) {
  // Asymmetric tile plan — first is hero 2x2, then mix
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
      {days.map((d, i) => {
        const plan = tilePlan(i, days.length);
        return <DayTile key={d.id} day={d} size={plan} onClick={() => onOpen(d)} showSwipe={showSwipe===d.id} onSwipe={() => setShowSwipe(showSwipe===d.id?null:d.id)}/>;
      })}
    </div>
  );
}

function tilePlan(i, total) {
  // Hero at 0, wide at 3, hero again at 7 etc.
  if (i === 0) return 'hero';        // 2x2
  if (i === 3) return 'wide';        // 2x1
  if (i === 6) return 'wide';
  return 'sq';                        // 1x1
}

function DayTile({ day, size, onClick, showSwipe, onSwipe }) {
  const info = dayInfo(day);
  const label = info.isToday ? '就是今天' : info.isPast ? '已过' : '还有';
  const accent = info.isPast ? '#FFF' : '#FFF';

  const spans = {
    hero: { gridColumn: 'span 2', gridRow: 'span 2', height: 280 },
    wide: { gridColumn: 'span 2', height: 140 },
    sq: { height: 180 },
  }[size];

  return (
    <div
      onClick={onClick}
      className="photo sg-tap grain"
      style={{
        ...spans,
        borderRadius: 20,
        position: 'relative',
        cursor: 'pointer',
        boxShadow: '0 1px 3px rgba(0,0,0,0.06), 0 6px 16px rgba(0,0,0,0.05)',
      }}
    >
      <div className={`photo ${day.photo}`} style={{ position: 'absolute', inset: 0, borderRadius: 20 }}/>

      {day.pinned && (
        <div style={{
          position: 'absolute', top: 10, right: 10, zIndex: 2,
          background: 'rgba(255,255,255,0.2)', backdropFilter: 'blur(8px)',
          width: 24, height: 24, borderRadius: '50%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="11" height="11" viewBox="0 0 11 11" fill="#FFF"><path d="M5.5 0L7 3.5L10.5 4L8 6.5L8.7 10L5.5 8.3L2.3 10L3 6.5L0.5 4L4 3.5Z"/></svg>
        </div>
      )}

      <div style={{
        position: 'absolute', left: 14, right: 14, bottom: 12, zIndex: 2,
        color: '#FFF',
      }}>
        {size === 'hero' ? (
          <>
            <div style={{ fontSize: 12, opacity: 0.85, letterSpacing: '0.15em', textTransform: 'uppercase', marginBottom: 4 }}>{day.categoryLabel}</div>
            <div style={{ fontFamily: 'var(--serif)', fontSize: 22, fontWeight: 600, marginBottom: 8, lineHeight: 1.2 }}>{day.title}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
              <div style={{ fontFamily: 'var(--serif)', fontSize: 56, fontWeight: 500, lineHeight: 0.9, letterSpacing: '-0.03em' }} className="sg-tnum">{info.days}</div>
              <div style={{ fontSize: 13, opacity: 0.9 }}>{label} · 天</div>
            </div>
          </>
        ) : size === 'wide' ? (
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
            <div>
              <div style={{ fontSize: 10, opacity: 0.8, letterSpacing: '0.15em', textTransform: 'uppercase', marginBottom: 3 }}>{day.categoryLabel}</div>
              <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>{day.title}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontFamily: 'var(--serif)', fontSize: 36, fontWeight: 500, lineHeight: 0.9, letterSpacing: '-0.03em' }} className="sg-tnum">{info.days}</div>
              <div style={{ fontSize: 10, opacity: 0.85 }}>{label}</div>
            </div>
          </div>
        ) : (
          <>
            <div style={{ fontSize: 11, opacity: 0.8, marginBottom: 2 }}>{day.categoryLabel}</div>
            <div style={{ fontFamily: 'var(--serif)', fontSize: 14, fontWeight: 600, marginBottom: 4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{day.title}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <div style={{ fontFamily: 'var(--serif)', fontSize: 28, fontWeight: 500, lineHeight: 0.9, letterSpacing: '-0.03em' }} className="sg-tnum">{info.days}</div>
              <div style={{ fontSize: 10, opacity: 0.85 }}>{label}</div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { HomeScreen, DayTile });

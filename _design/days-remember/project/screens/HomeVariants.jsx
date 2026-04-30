/* Screen: Home variants — list-style and editorial timeline */

function HomeListVariant({ onOpenDay, onAdd }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div style={{ padding: '62px 20px 8px', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontSize: 12, color: 'var(--muted)', letterSpacing: '0.3em', textTransform: 'uppercase' }}>2026 · 四月</div>
            <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 30, fontWeight: 600, letterSpacing: '-0.02em' }}>我的日子</h1>
          </div>
          <button onClick={onAdd} style={{ width: 40, height: 40, borderRadius: 14, border: 'none', background: 'var(--ink)', color: 'var(--bg)', cursor: 'pointer' }}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M8 3v10M3 8h10"/></svg>
          </button>
        </div>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '14px 20px 20px' }}>
        {/* Upcoming section */}
        <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', margin: '8px 4px 12px', fontWeight: 600 }}>即将到来</div>
        {DAYS.filter(d => !dayInfo(d).isPast).sort((a,b) => dayInfo(a).days - dayInfo(b).days).map(d => (
          <ListRow key={d.id} day={d} onClick={() => onOpenDay(d)}/>
        ))}
        <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', margin: '24px 4px 12px', fontWeight: 600 }}>过去</div>
        {DAYS.filter(d => dayInfo(d).isPast).sort((a,b) => dayInfo(a).days - dayInfo(b).days).map(d => (
          <ListRow key={d.id} day={d} onClick={() => onOpenDay(d)}/>
        ))}
      </div>
    </div>
  );
}

function ListRow({ day, onClick }) {
  const info = dayInfo(day);
  return (
    <div onClick={onClick} className="sg-tap" style={{
      display: 'flex', alignItems: 'center', gap: 14, padding: '14px 14px',
      background: 'var(--card)', borderRadius: 18, marginBottom: 8, cursor: 'pointer',
      boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
    }}>
      <div className={`photo ${day.photo}`} style={{ width: 52, height: 52, borderRadius: 13, flexShrink: 0 }}>
        {day.pinned && <div style={{ position: 'absolute', top: 4, right: 4, width: 6, height: 6, borderRadius: '50%', background: '#FFF', zIndex:2 }}/>}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 15, fontWeight: 600, letterSpacing: '-0.01em' }}>{day.title}</div>
        <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 2, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ display: 'inline-block', width: 5, height: 5, borderRadius: '50%', background: CATEGORY_COLORS[day.category] }}/>
          {day.categoryLabel} · {fmtCNShort(info.displayDate)}
        </div>
      </div>
      <div style={{ textAlign: 'right', minWidth: 64 }}>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 26, fontWeight: 500, color: CATEGORY_COLORS[day.category], lineHeight: 1, letterSpacing: '-0.03em' }} className="sg-tnum">{info.days}</div>
        <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 3 }}>{info.isToday ? '今天' : info.isPast ? '天已过' : '天后'}</div>
      </div>
    </div>
  );
}

function HomeEditorialVariant({ onOpenDay, onAdd }) {
  const featured = DAYS.find(d => d.id === 'wedding');
  const fInfo = dayInfo(featured);
  const others = DAYS.filter(d => d.id !== featured.id).slice(0, 5);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div className="sg-scroll" style={{ flex: 1 }}>
        {/* full bleed featured */}
        <div className={`photo ${featured.photo} grain`} style={{ height: 440, position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0.3) 0%, rgba(0,0,0,0.1) 30%, rgba(0,0,0,0.85) 100%)' }}/>
          <div style={{ position: 'absolute', top: 62, left: 20, right: 20, display: 'flex', alignItems: 'center', justifyContent: 'space-between', color: '#FFF', zIndex: 5 }}>
            <div style={{ fontFamily: 'var(--serif)', fontSize: 16, fontWeight: 500, letterSpacing: '0.15em' }}>時 · 光</div>
            <button onClick={onAdd} style={{ width: 36, height: 36, borderRadius: 999, background: 'rgba(255,255,255,0.18)', backdropFilter: 'blur(10px)', border: 'none', color: '#FFF', cursor: 'pointer' }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#FFF" strokeWidth="2" strokeLinecap="round"><path d="M7 2v10M2 7h10"/></svg>
            </button>
          </div>
          <div onClick={() => onOpenDay(featured)} style={{ position: 'absolute', left: 24, right: 24, bottom: 28, color: '#FFF', cursor: 'pointer' }}>
            <div style={{ fontSize: 11, letterSpacing: '0.3em', textTransform: 'uppercase', opacity: 0.85, marginBottom: 6 }}>今日推荐 · 置顶</div>
            <div style={{ fontFamily: 'var(--serif)', fontSize: 26, fontWeight: 500, marginBottom: 16 }}>{featured.title}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
              <div style={{ fontFamily: 'var(--serif)', fontSize: 88, fontWeight: 500, lineHeight: 0.85, letterSpacing: '-0.05em' }} className="sg-tnum">{fInfo.days}</div>
              <div>
                <div style={{ fontSize: 13, opacity: 0.9 }}>天</div>
                <div style={{ fontSize: 11, opacity: 0.75, marginTop: 2 }}>已相伴</div>
              </div>
            </div>
          </div>
        </div>

        <div style={{ padding: '24px 20px 28px' }}>
          <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.3em', textTransform: 'uppercase', marginBottom: 16, fontWeight: 600, fontFamily: 'var(--serif)' }}>其他日子</div>
          {others.map((d, i) => {
            const info = dayInfo(d);
            return (
              <div key={d.id} onClick={() => onOpenDay(d)} className="sg-tap" style={{
                display: 'flex', gap: 14, padding: '14px 0',
                borderBottom: i===others.length-1 ? 'none' : '0.5px solid var(--hairline)',
                cursor: 'pointer', alignItems: 'center',
              }}>
                <div style={{ width: 56, textAlign: 'center' }}>
                  <div style={{ fontFamily: 'var(--serif)', fontSize: 28, fontWeight: 500, color: 'var(--ink)', letterSpacing: '-0.03em', lineHeight: 1 }} className="sg-tnum">{info.days}</div>
                  <div style={{ fontSize: 9, color: 'var(--muted)', marginTop: 3, letterSpacing: '0.15em' }}>{info.isToday ? '今天' : info.isPast ? '天前' : '天后'}</div>
                </div>
                <div style={{ width: 1, alignSelf: 'stretch', background: CATEGORY_COLORS[d.category], opacity: 0.6 }}/>
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: 'var(--serif)', fontSize: 16, fontWeight: 500 }}>{d.title}</div>
                  <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 3 }}>{d.categoryLabel} · {fmtCN(info.displayDate)}</div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { HomeListVariant, HomeEditorialVariant });

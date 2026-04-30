/* Screen: Day Detail — full bleed photo + counter */

function DetailScreen({ day, onBack }) {
  const info = dayInfo(day);
  const label = info.isToday ? '就是今天' : info.isPast ? '已过去' : '还有';
  return (
    <div style={{ height: '100%', background: 'var(--ink)', position: 'relative', overflow: 'hidden' }}>
      {/* Background photo */}
      <div className={`photo ${day.photo} grain`} style={{ position: 'absolute', inset: 0 }}>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0.25) 0%, rgba(0,0,0,0.1) 40%, rgba(0,0,0,0.85) 100%)' }}/>
      </div>

      {/* Top controls */}
      <div style={{ position: 'absolute', top: 62, left: 16, right: 16, display: 'flex', justifyContent: 'space-between', zIndex: 10 }}>
        <GlassBtn onClick={onBack}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#FFF" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 2L3 7l6 5"/></svg>
        </GlassBtn>
        <div style={{ display: 'flex', gap: 8 }}>
          <GlassBtn>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#FFF" strokeWidth="1.8" strokeLinecap="round"><path d="M7 1.5l1.7 3.5 3.8.5-2.8 2.7.7 3.8L7 10.2 3.6 12l.7-3.8L1.5 5.5l3.8-.5z"/></svg>
          </GlassBtn>
          <GlassBtn>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#FFF" strokeWidth="1.8" strokeLinecap="round"><circle cx="2.5" cy="7" r="1.2"/><circle cx="7" cy="7" r="1.2"/><circle cx="11.5" cy="7" r="1.2"/></svg>
          </GlassBtn>
        </div>
      </div>

      {/* Center counter */}
      <div style={{ position: 'absolute', left: 0, right: 0, top: '34%', zIndex: 5, textAlign: 'center', color: '#FFF', padding: '0 32px' }}>
        <div style={{ fontSize: 11, letterSpacing: '0.3em', textTransform: 'uppercase', opacity: 0.8, marginBottom: 10 }}>{day.categoryLabel}</div>
        <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 28, fontWeight: 500, letterSpacing: '-0.01em' }}>{day.title}</h1>
        <div style={{ margin: '28px 0 6px', fontFamily: 'var(--serif)', fontSize: 120, fontWeight: 500, lineHeight: 0.9, letterSpacing: '-0.05em' }} className="sg-tnum">{info.days}</div>
        <div style={{ fontSize: 14, opacity: 0.8, letterSpacing: '0.25em' }}>{label} · 天</div>
      </div>

      {/* Bottom info card */}
      <div style={{ position: 'absolute', left: 14, right: 14, bottom: 46, zIndex: 6,
        background: 'rgba(255,255,255,0.1)', backdropFilter: 'blur(24px) saturate(180%)',
        WebkitBackdropFilter: 'blur(24px) saturate(180%)',
        borderRadius: 24, padding: '16px 18px', color: '#FFF',
        border: '0.5px solid rgba(255,255,255,0.18)',
      }}>
        <InfoRow label="日期" value={fmtCN(info.displayDate) + ' · ' + weekday(info.displayDate)}/>
        {typeof fmtLunar === 'function' && <InfoRow label="农历" value={fmtLunarFull(info.displayDate)}/>}
        {typeof solarTerm === 'function' && solarTerm(info.displayDate) && <InfoRow label="节气" value={solarTerm(info.displayDate)}/>}
        {typeof lunarHoliday === 'function' && lunarHoliday(info.displayDate) && <InfoRow label="传统节日" value={lunarHoliday(info.displayDate)}/>}
        {day.lunar && <InfoRow label="按农历重复" value="每年农历相同日期"/>}
        {day.location && <InfoRow label="地点" value={day.location}/>}
        {day.recurring && <InfoRow label="重复" value={`每年 · 第 ${info.yearsAgo + (info.isPast?0:1)} 次`}/>}
        {day.note && (
          <div style={{ marginTop: 12, paddingTop: 12, borderTop: '0.5px solid rgba(255,255,255,0.2)', fontFamily: 'var(--serif)', fontSize: 14, lineHeight: 1.7, opacity: 0.92, fontStyle: 'italic' }}>
            "{day.note}"
          </div>
        )}
      </div>
    </div>
  );
}

function InfoRow({ label, value }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '5px 0', fontSize: 13 }}>
      <span style={{ opacity: 0.65 }}>{label}</span>
      <span style={{ fontWeight: 500 }}>{value}</span>
    </div>
  );
}

function GlassBtn({ children, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: 40, height: 40, borderRadius: 999, border: 'none',
      background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(16px) saturate(180%)',
      WebkitBackdropFilter: 'blur(16px) saturate(180%)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer', borderTop: '0.5px solid rgba(255,255,255,0.2)',
    }}>{children}</button>
  );
}

Object.assign(window, { DetailScreen });

/* Screen: Calendar — scrapbook month view */

function CalendarScreen({ onBack, onOpenDay }) {
  const [month, setMonth] = React.useState(new Date(2026, 3, 1)); // April 2026
  const y = month.getFullYear(), m = month.getMonth();
  const first = new Date(y, m, 1).getDay();
  const dim = new Date(y, m+1, 0).getDate();
  const prevDim = new Date(y, m, 0).getDate();

  const cells = [];
  for (let i = 0; i < first; i++) cells.push({ day: prevDim - first + 1 + i, out: true });
  for (let i = 1; i <= dim; i++) cells.push({ day: i, out: false });
  while (cells.length < 42) cells.push({ day: cells.length - first - dim + 1, out: true });

  const marked = {};
  DAYS.forEach(d => {
    let c = d.date;
    if (d.recurring) c = new Date(y, d.date.getMonth(), d.date.getDate());
    if (c.getFullYear() === y && c.getMonth() === m) marked[c.getDate()] = d;
  });
  const monthDays = Object.values(marked).sort((a,b) => a.date.getDate() - b.date.getDate());
  const monthCN = ['一','二','三','四','五','六','七','八','九','十','十一','十二'][m];
  const monthEN = ['January','February','March','April','May','June','July','August','September','October','November','December'][m];

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <NavBar onBack={onBack} title="日历"/>

      <div style={{ padding: '6px 24px 12px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', flexShrink: 0 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, letterSpacing: '-0.03em' }}>{monthCN}月</h1>
          <div className="sg-hand" style={{ fontSize: 24, color: 'var(--cat-travel)', lineHeight: 1, marginTop: 2 }}>{monthEN} {y}</div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="fab" style={{ width: 38, height: 38 }} onClick={() => setMonth(new Date(y, m-1, 1))}>
            <svg width="15" height="15" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M8 2L4 6l4 4"/></svg>
          </button>
          <button className="fab" style={{ width: 38, height: 38 }} onClick={() => setMonth(new Date(y, m+1, 1))}>
            <svg width="15" height="15" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 2l4 4-4 4"/></svg>
          </button>
        </div>
      </div>

      {/* calendar card */}
      <div style={{ margin: '0 22px', background: '#fff', borderRadius: 22, padding: '14px 12px 12px', flexShrink: 0, boxShadow: '0 1px 2px rgba(21,23,28,0.05), 0 8px 20px rgba(21,23,28,0.06)' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
          {['日','一','二','三','四','五','六'].map(d => (
            <div key={d} style={{ textAlign: 'center', fontSize: 11, color: 'var(--muted)', fontWeight: 700, padding: '2px 0 8px' }}>{d}</div>
          ))}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gridAutoRows: '1fr', gap: 1 }}>
          {cells.map((c, i) => {
            const isToday = !c.out && c.day === 23;
            const mark = !c.out && marked[c.day];
            return (
              <div key={i} onClick={() => mark && onOpenDay && onOpenDay(mark)} style={{
                aspectRatio: '1', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                borderRadius: 11, position: 'relative', cursor: mark ? 'pointer' : 'default',
                background: isToday ? 'var(--ink)' : (mark ? 'var(--bg)' : 'transparent'),
                color: isToday ? '#fff' : (c.out ? 'var(--muted)' : 'var(--ink)'), opacity: c.out ? 0.3 : 1,
              }}>
                <div style={{ fontSize: 14, fontWeight: isToday ? 800 : 600 }} className="sg-tnum">{c.day}</div>
                {!c.out && typeof solarTerm === 'function' && (() => {
                  const dt = new Date(y, m, c.day);
                  const t = solarTerm(dt) || lunarHoliday(dt);
                  if (t) return <div style={{ fontSize: 7.5, marginTop: 1, color: isToday ? 'rgba(255,255,255,0.8)' : 'var(--cat-travel)', fontWeight: 700 }}>{t}</div>;
                  return null;
                })()}
                {mark && <div style={{ width: 5, height: 5, borderRadius: '50%', background: isToday ? '#fff' : CATEGORY_COLORS[mark.category], marginTop: 2 }}/>}
              </div>
            );
          })}
        </div>
      </div>

      {/* this month days */}
      <div className="sg-scroll" style={{ flex: 1, padding: '18px 22px 120px' }}>
        <div className="sg-sec">本月日子</div>
        {monthDays.length === 0 && <div style={{ padding: 16, textAlign: 'center', color: 'var(--muted)' }} className="sg-hand-cn">本月没有记录的日子</div>}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {monthDays.map((d) => {
            const info = dayInfo(d);
            return (
              <div key={d.id} onClick={() => onOpenDay && onOpenDay(d)} className="sg-tap" style={{
                display: 'flex', alignItems: 'center', gap: 14, background: '#fff', borderRadius: 18, padding: '10px 12px', cursor: 'pointer',
                boxShadow: '0 1px 2px rgba(21,23,28,0.05)',
              }}>
                <div style={{ width: 44, textAlign: 'center', flexShrink: 0 }}>
                  <div style={{ fontSize: 22, fontWeight: 800, color: CATEGORY_COLORS[d.category], lineHeight: 1 }} className="sg-tnum">{info.displayDate.getDate()}</div>
                  <div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 3, fontWeight: 600 }}>{weekday(info.displayDate).replace('星期','周')}</div>
                </div>
                <div className="polaroid" style={{ width: 46, padding: 4, flexShrink: 0, transform: 'rotate(-3deg)' }}>
                  <div className={`photo ${d.photo}`} style={{ height: 38 }}/>
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 700, letterSpacing: '-0.01em' }}>{d.title}</div>
                  <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1, fontWeight: 500 }}>{d.categoryLabel}{d.recurring?' · 每年':''}{d.lunar?' · 农历':''}</div>
                </div>
                <div className="sg-hand" style={{ fontSize: 20, color: 'var(--ink-2)', flexShrink: 0 }}>
                  {info.isToday ? 'Today' : info.isPast ? `+${info.days}` : `${info.days}d`}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CalendarScreen });

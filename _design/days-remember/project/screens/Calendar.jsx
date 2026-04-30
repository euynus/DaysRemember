/* Screen: Calendar — month grid */

function CalendarScreen({ onBack, onOpenDay }) {
  const [month, setMonth] = React.useState(3); // 0-indexed; April
  const [year] = React.useState(2024);

  const monthName = ['一','二','三','四','五','六','七','八','九','十','十一','十二'][month];
  const daysInMonth = new Date(year, month+1, 0).getDate();
  const firstDow = new Date(year, month, 1).getDay();

  // Map day-of-month → list of DAYS that fall on it
  const eventsByDay = {};
  DAYS.forEach(d => {
    const dt = new Date(d.date);
    if (d.recurring) {
      // anniversary recurs
      if (dt.getMonth() === month) {
        const day = dt.getDate();
        eventsByDay[day] = eventsByDay[day] || [];
        eventsByDay[day].push(d);
      }
    } else if (dt.getMonth() === month && dt.getFullYear() === year) {
      const day = dt.getDate();
      eventsByDay[day] = eventsByDay[day] || [];
      eventsByDay[day].push(d);
    }
  });

  const cells = [];
  for (let i = 0; i < firstDow; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);

  const today = new Date(2024,3,23);
  const isToday = (d) => d === today.getDate() && month === today.getMonth();

  return (
    <div style={{ height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink)', cursor: 'pointer', padding: 4 }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M11 3L5 9l6 6"/></svg>
        </button>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>日历</div>
        <button style={{ border: 'none', background: 'transparent', color: 'var(--terracotta)', font: '500 14px var(--sans)', cursor: 'pointer' }}>今天</button>
      </div>

      {/* Month switcher */}
      <div style={{ padding: '14px 20px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={()=>setMonth(m=>(m+11)%12)} style={{ border: 'none', background: 'var(--card)', width: 36, height: 36, borderRadius: 12, cursor: 'pointer' }}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M9 2L3 7l6 5"/></svg>
        </button>
        <div style={{ textAlign: 'center' }}>
          <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 28, fontWeight: 600, letterSpacing: '-0.02em' }}>{year} 年 {monthName}月</h1>
          <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 2 }}>三月 · 春</div>
        </div>
        <button onClick={()=>setMonth(m=>(m+1)%12)} style={{ border: 'none', background: 'var(--card)', width: 36, height: 36, borderRadius: 12, cursor: 'pointer' }}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M5 2l6 5-6 5"/></svg>
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', padding: '0 16px', flexShrink: 0,
        fontSize: 11, color: 'var(--muted)', textAlign: 'center', marginBottom: 4 }}>
        {['日','一','二','三','四','五','六'].map(d => <div key={d} style={{ padding: '6px 0' }}>{d}</div>)}
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '0 16px 24px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4 }}>
          {cells.map((d, i) => {
            if (!d) return <div key={i} style={{ aspectRatio: '1' }}/>;
            const events = eventsByDay[d] || [];
            const has = events.length > 0;
            const isT = isToday(d);
            return (
              <div key={i} onClick={() => has && onOpenDay && onOpenDay(events[0])} style={{
                aspectRatio: '1', borderRadius: 10, padding: 4,
                background: isT ? 'var(--terracotta)' : has ? 'var(--card)' : 'transparent',
                color: isT ? '#FFF' : has ? 'var(--ink)' : 'var(--ink-2)',
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                cursor: has ? 'pointer' : 'default',
                border: has && !isT ? '1px solid var(--hairline)' : 'none',
                position: 'relative',
              }}>
                <div style={{ fontSize: 13, fontWeight: isT ? 600 : 500 }} className="sg-tnum">{d}</div>
                {has && (
                  <div style={{ display: 'flex', gap: 2, marginTop: 2 }}>
                    {events.slice(0,3).map((e, j) => (
                      <div key={j} style={{ width: 3, height: 3, borderRadius: '50%',
                        background: isT ? '#FFF' : 'var(--terracotta)' }}/>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* This-month list */}
        <div style={{ marginTop: 22, fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 12, fontWeight: 600, padding: '0 4px' }}>本月日子</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {Object.entries(eventsByDay).sort((a,b)=>+a[0]-+b[0]).map(([day, evts]) => (
            evts.map(e => (
              <div key={e.id} onClick={()=>onOpenDay&&onOpenDay(e)} className="sg-tap" style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px',
                background: 'var(--card)', borderRadius: 14, cursor: 'pointer',
                border: '1px solid var(--hairline)',
              }}>
                <div style={{ width: 38, textAlign: 'center', fontFamily: 'var(--serif)', fontSize: 18, fontWeight: 600, color: 'var(--terracotta)' }} className="sg-tnum">{day}</div>
                <div className={`photo ${e.photo} photo-flat`} style={{ width: 36, height: 36, borderRadius: 10 }}/>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13, fontWeight: 500 }}>{e.title}</div>
                  <div style={{ fontSize: 11, color: 'var(--muted)', marginTop: 1 }}>{e.categoryLabel}</div>
                </div>
              </div>
            ))
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CalendarScreen });

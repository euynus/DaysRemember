/* Screen: Day Detail — scrapbook page */

function DetailScreen({ day, onBack }) {
  const info = dayInfo(day);
  const [nc, ni] = noteColorFor(day.id);
  const label = info.isToday ? '今天' : info.isPast ? '天前' : '天后';

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Top bar with FABs */}
      <div style={{ padding: '58px 18px 6px', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', flexShrink: 0 }}>
        <button className="fab" onClick={onBack}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M11 3L5 9l6 6"/></svg>
        </button>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="fab"><svg width="17" height="17" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M9 2l2.1 4.5 4.9.6-3.6 3.4.9 4.9L9 13.5 4.7 15.4l.9-4.9L2 7.1l4.9-.6z"/></svg></button>
          <button className="fab"><svg width="17" height="17" viewBox="0 0 18 18" fill="currentColor"><circle cx="3.5" cy="9" r="1.6"/><circle cx="9" cy="9" r="1.6"/><circle cx="14.5" cy="9" r="1.6"/></svg></button>
        </div>
      </div>

      {/* Title + meta */}
      <div style={{ padding: '10px 24px 4px', flexShrink: 0 }}>
        <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.08 }}>{day.title}</h1>
        <div className="meta" style={{ marginTop: 10 }}>
          <span>{fmtCN(info.displayDate)}</span>
          <span className="dot"/>
          <span>{weekday(info.displayDate)}</span>
          {day.recurring && <><span className="dot"/><span>每年</span></>}
        </div>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '18px 24px 40px' }}>
        {/* Hero polaroid with countdown sticky */}
        <div style={{ position: 'relative', paddingTop: 8 }}>
          <div className="polaroid" style={{ transform: 'rotate(-1.5deg)' }}>
            <div className={`photo ${day.photo}`} style={{ height: 280 }}/>
            <div style={{ padding: '12px 6px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div className="sg-hand" style={{ fontSize: 26, color: 'var(--ink-2)' }}>{enDate(info.displayDate)}</div>
              <Sticker name={stickerFor(day)} size={42} rotate={8}/>
            </div>
          </div>
          {/* big countdown sticky clipped */}
          <div style={{ position: 'absolute', top: -2, right: 10, zIndex: 5 }}>
            <StickyNote color={nc} ink={ni} rotate={6} clip size="l">
              <div style={{ textAlign: 'center', lineHeight: 0.92 }}>
                <div style={{ fontSize: 48, fontWeight: 700 }} className="sg-tnum">{info.days}</div>
                <div style={{ fontSize: 18 }}>{label}</div>
              </div>
            </StickyNote>
          </div>
          {/* washi tape top-left */}
          <div style={{ position: 'absolute', top: -2, left: 24, zIndex: 5 }}>
            <Tape color="rgba(180,221,240,0.75)" w={70} style={{ transform: 'rotate(-6deg)' }}/>
          </div>
        </div>

        {/* Handwritten note on lined paper */}
        {day.note && (
          <div style={{ position: 'relative', marginTop: 26 }}>
            <div style={{
              background: '#FFFDF6', borderRadius: 14, padding: '18px 18px 16px',
              boxShadow: '0 1px 2px rgba(21,23,28,0.06), 0 8px 20px rgba(21,23,28,0.08)',
              backgroundImage: 'repeating-linear-gradient(transparent, transparent 27px, rgba(21,23,28,0.06) 28px)',
              transform: 'rotate(0.4deg)',
            }}>
              <div className="sg-hand-cn" style={{ fontSize: 21, lineHeight: '28px', color: '#3A3A3A' }}>{day.note}</div>
            </div>
            <div style={{ position: 'absolute', top: -10, left: '50%', transform: 'translateX(-50%)' }}><Paperclip/></div>
          </div>
        )}

        {/* Info chips row */}
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 22 }}>
          {day.location && <InfoTag icon="pin" text={day.location}/>}
          {typeof fmtLunar === 'function' && <InfoTag icon="moon" text={fmtLunar(info.displayDate)}/>}
          {typeof solarTerm === 'function' && solarTerm(info.displayDate) && <InfoTag icon="leaf" text={solarTerm(info.displayDate)}/>}
          {day.recurring && <InfoTag icon="repeat" text={`第 ${info.yearsAgo + (info.isPast?0:1)} 次`}/>}
          {day.lunar && <InfoTag icon="moon" text="农历重复"/>}
        </div>

        {/* Memories strip */}
        <div className="sg-sec" style={{ marginTop: 26 }}>这一天的相册</div>
        <div style={{ display: 'flex', gap: 12, overflowX: 'auto', scrollbarWidth: 'none', paddingTop: 6, paddingBottom: 4 }}>
          {['photo-japan','photo-home','photo-wedding','photo-baby'].map((p, i) => (
            <div key={i} className="polaroid sg-tap" style={{ width: 96, flexShrink: 0, padding: 5, transform: `rotate(${i%2?2:-2}deg)`, cursor: 'pointer' }}>
              <div className={`photo ${p}`} style={{ height: 96 }}/>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function InfoTag({ icon, text }) {
  const ic = {
    pin: <path d="M8 1.5c2.5 0 4.5 2 4.5 4.5 0 3-4.5 8-4.5 8s-4.5-5-4.5-8C3.5 3.5 5.5 1.5 8 1.5z"/>,
    moon: <path d="M13 9.5A6 6 0 016.5 3a6 6 0 103 7 6 6 0 003.5-.5z"/>,
    leaf: <path d="M13 3C7 3 3 6 3 11c0 1 0 2 .5 2.5C7 10 9 8 13 7c-3 2-5 4-7.5 7.5C10 14 13 10 13 3z"/>,
    repeat: <path d="M3 7a5 5 0 018-3M13 9a5 5 0 01-8 3M11 2v2.5H8.5M5 14v-2.5H7.5"/>,
  }[icon];
  return (
    <div className="chip" style={{ background: '#fff', cursor: 'default' }}>
      <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="var(--ink-2)" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">{ic}</svg>
      <span style={{ color: 'var(--ink)' }}>{text}</span>
    </div>
  );
}

Object.assign(window, { DetailScreen });

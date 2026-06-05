/* Screen: Widgets gallery — scrapbook widgets */

function WidgetsScreen({ onBack }) {
  const [size, setSize] = React.useState('m');
  const pinned = DAYS.find(d => d.id === 'wedding');
  const up = DAYS.find(d => d.id === 'japan');
  const pInfo = dayInfo(pinned), uInfo = dayInfo(up);

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <NavBar onBack={onBack} title="小组件"/>

      <div style={{ padding: '6px 24px 4px', flexShrink: 0 }}>
        <h1 style={{ margin: 0, fontSize: 30, fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1 }}>放到主屏上</h1>
        <p style={{ margin: '6px 0 0', color: 'var(--ink-2)', fontSize: 14, fontWeight: 500 }}>每次解锁，都和重要的日子打个招呼。</p>
      </div>

      <div style={{ padding: '14px 22px 6px', display: 'flex', gap: 8, flexShrink: 0 }}>
        {[['s','小'],['m','中'],['l','大']].map(([v,l]) => (
          <button key={v} className={`chip ${size===v?'on':''}`} onClick={()=>setSize(v)}>{l}号</button>
        ))}
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '12px 22px 120px' }}>
        {/* widget board on a soft "wallpaper" */}
        <div style={{ background: 'linear-gradient(160deg, oklch(0.86 0.06 240) 0%, oklch(0.7 0.08 255) 100%)', borderRadius: 26, padding: '28px 20px', position: 'relative', overflow: 'hidden' }}>
          {size === 'm' && (
            <div style={{ display: 'flex', justifyContent: 'center' }}>
              <div style={{ position: 'relative' }}>
                <div className="polaroid" style={{ width: 280, transform: 'rotate(-1.5deg)' }}>
                  <div className={`photo ${pinned.photo}`} style={{ height: 130, position: 'relative' }}>
                    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg,rgba(0,0,0,0) 40%,rgba(0,0,0,0.4))' }}/>
                    <div style={{ position: 'absolute', left: 12, bottom: 10, color: '#fff', fontWeight: 800, fontSize: 16 }}>{pinned.title}</div>
                  </div>
                  <div style={{ padding: '10px 6px 2px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                    <div><span style={{ fontSize: 40, fontWeight: 800, color: 'var(--ink)' }} className="sg-tnum">{pInfo.days}</span> <span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>天 · 已相伴</span></div>
                    <Sticker name="ring" size={32} rotate={8}/>
                  </div>
                </div>
                <div style={{ position: 'absolute', top: -6, right: -6 }}><StickyNote color="var(--note-pink)" ink="var(--note-pink-ink)" rotate={8} size="s">7年啦</StickyNote></div>
              </div>
            </div>
          )}
          {size === 's' && (
            <div style={{ display: 'flex', gap: 16, justifyContent: 'center' }}>
              {[[up,uInfo],[pinned,pInfo]].map(([d,inf],i) => (
                <div key={i} style={{ position: 'relative' }}>
                  <div className="polaroid" style={{ width: 124, transform: `rotate(${i?2:-2}deg)` }}>
                    <div className={`photo ${d.photo}`} style={{ height: 110 }}/>
                    <div style={{ padding: '8px 4px 2px', textAlign: 'center' }}>
                      <div style={{ fontSize: 30, fontWeight: 800 }} className="sg-tnum">{inf.days}</div>
                    </div>
                  </div>
                  <div style={{ position: 'absolute', top: -8, right: -10 }}><Sticker name={stickerFor(d)} size={30} rotate={10}/></div>
                </div>
              ))}
            </div>
          )}
          {size === 'l' && (
            <div style={{ display: 'flex', justifyContent: 'center' }}>
              <div className="polaroid" style={{ width: 280, transform: 'rotate(-1deg)' }}>
                <div className={`photo ${up.photo}`} style={{ height: 180 }}/>
                <div style={{ padding: '12px 6px 4px' }}>
                  <div style={{ fontSize: 16, fontWeight: 800 }}>{up.title}</div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
                    <span style={{ fontSize: 52, fontWeight: 800, color: 'var(--cat-travel)' }} className="sg-tnum">{uInfo.days}</span>
                    <span style={{ fontSize: 14, color: 'var(--muted)', fontWeight: 600 }}>天后 · 北海道</span>
                  </div>
                </div>
              </div>
            </div>
          )}
          <div style={{ textAlign: 'center', color: 'rgba(255,255,255,0.8)', fontSize: 12, marginTop: 18, fontWeight: 600 }}>主屏预览</div>
        </div>

        <div className="sg-sec" style={{ marginTop: 22 }}>风格</div>
        <div style={{ display: 'flex', gap: 12 }}>
          {[['拍立得','var(--note-blue)'],['便利贴','var(--note-yellow)'],['极简','#fff']].map(([l,c],i) => (
            <div key={i} style={{ flex: 1, height: 84, borderRadius: 16, background: c, boxShadow: '0 1px 2px rgba(21,23,28,0.06)', display: 'flex', alignItems: 'flex-end', padding: 12, fontWeight: 700, fontSize: 13, outline: i===0?'2.5px solid var(--ink)':'none', outlineOffset: 2 }}>{l}</div>
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { WidgetsScreen });

/* Screen: Categories — scrapbook shelves */

function CategoriesScreen({ onBack, onOpenCategory }) {
  const cats = [
    { id: 'all', label: '全部日子', sticker: 'star', count: DAYS.length, color: 'var(--note-yellow)' },
    { id: 'love', label: '爱情', sticker: 'heart', count: DAYS.filter(d=>d.category==='love').length, color: 'var(--note-pink)' },
    { id: 'family', label: '家人', sticker: 'balloon', count: DAYS.filter(d=>d.category==='family').length, color: 'var(--note-peach)' },
    { id: 'travel', label: '旅行', sticker: 'plane', count: DAYS.filter(d=>d.category==='travel').length, color: 'var(--note-blue)' },
    { id: 'work', label: '工作学业', sticker: 'cap', count: DAYS.filter(d=>d.category==='work').length, color: 'var(--note-green)' },
    { id: 'life', label: '生活', sticker: 'house', count: DAYS.filter(d=>d.category==='life').length, color: 'var(--note-peach)' },
  ];
  const previews = { all: ['photo-wedding','photo-baby','photo-japan'], love: ['photo-wedding','photo-memorial'], family: ['photo-baby','photo-birthday','photo-home'], travel: ['photo-japan'], work: ['photo-study','photo-work'], life: ['photo-home'] };

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <NavBar onBack={onBack} title="分类" trailing={<span style={{ color: 'var(--ink-2)', fontWeight: 600, fontSize: 15 }}>编辑</span>}/>

      <div style={{ padding: '6px 24px 2px', flexShrink: 0 }}>
        <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, letterSpacing: '-0.03em' }}>你的分类</h1>
        <div className="meta" style={{ marginTop: 8 }}><span>{DAYS.length} 个日子</span><span className="dot"/><span>5 个分类</span></div>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '20px 22px 120px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
          {cats.map((c, i) => (
            <div key={c.id} onClick={() => onOpenCategory && onOpenCategory(c.id)} className="sg-tap"
              style={{ position: 'relative', cursor: 'pointer', gridColumn: i===0 ? 'span 2' : 'span 1', paddingTop: 10 }}>
              <div style={{
                background: '#fff', borderRadius: 20, padding: 16, height: i===0 ? 130 : 124,
                boxShadow: '0 1px 2px rgba(21,23,28,0.05), 0 8px 20px rgba(21,23,28,0.07)',
                display: 'flex', flexDirection: i===0 ? 'row' : 'column', justifyContent: 'space-between',
                alignItems: i===0 ? 'center' : 'flex-start', transform: `rotate(${i%2?0.8:-0.8}deg)`,
              }}>
                <div>
                  <Sticker name={c.sticker} size={i===0?46:36} rotate={-8}/>
                  <div style={{ fontSize: i===0?20:16, fontWeight: 800, letterSpacing: '-0.02em', marginTop: 10 }}>{c.label}</div>
                  <div style={{ fontSize: 12, color: 'var(--muted)', fontWeight: 600, marginTop: 2 }}>{c.count} 个日子</div>
                </div>
                {/* peek polaroids */}
                <div style={{ display: 'flex' }}>
                  {(previews[c.id]||[]).slice(0,3).map((p, j) => (
                    <div key={j} className="polaroid" style={{ width: i===0?54:0, padding: 3, marginLeft: j?-14:0, transform: `rotate(${j%2?5:-5}deg)`, display: i===0?'block':'none' }}>
                      <div className={`photo ${p}`} style={{ height: 54 }}/>
                    </div>
                  ))}
                </div>
              </div>
              {/* count sticky */}
              <div style={{ position: 'absolute', top: 0, right: i===0?16:-6, zIndex: 4 }}>
                <StickyNote color={c.color} ink="rgba(21,23,28,0.6)" rotate={7} size="s">
                  <span style={{ fontSize: 18, fontWeight: 700 }}>{c.count}</span>
                </StickyNote>
              </div>
            </div>
          ))}
        </div>

        <div className="sg-tap" style={{ marginTop: 18, padding: '16px 18px', background: '#fff', borderRadius: 20,
          border: '2px dashed var(--hairline-strong)', display: 'flex', alignItems: 'center', gap: 14, cursor: 'pointer' }}>
          <div style={{ width: 40, height: 40, borderRadius: 12, background: 'var(--bg-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)', fontSize: 22 }}>+</div>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700 }}>新建分类</div>
            <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1 }}>挑一个贴纸和颜色</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function NavBar({ onBack, title, trailing }) {
  return (
    <div style={{ padding: '56px 18px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
      <button className="fab" onClick={onBack} style={{ width: 42, height: 42 }}>
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M11 3L5 9l6 6"/></svg>
      </button>
      <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em' }}>{title}</div>
      <div style={{ minWidth: 42, display: 'flex', justifyContent: 'flex-end', cursor: 'pointer' }}>{trailing || <div style={{ width: 42 }}/>}</div>
    </div>
  );
}

Object.assign(window, { CategoriesScreen, NavBar });

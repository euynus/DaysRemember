/* Screen: Categories */

function CategoriesScreen({ onBack, onOpenCategory }) {
  const cats = [
    { id: 'all', label: '全部日子', count: DAYS.length, icon: '✨', color: 'oklch(0.62 0.12 35)', soft: 'oklch(0.95 0.025 35)' },
    { id: 'love', label: '爱情', count: DAYS.filter(d=>d.category==='love').length, icon: '♡', color: 'oklch(0.65 0.11 10)', soft: 'oklch(0.95 0.025 10)' },
    { id: 'family', label: '家人', count: DAYS.filter(d=>d.category==='family').length, icon: '🏡', color: 'oklch(0.65 0.12 70)', soft: 'oklch(0.95 0.03 70)' },
    { id: 'travel', label: '旅行', count: DAYS.filter(d=>d.category==='travel').length, icon: '✈', color: 'oklch(0.6 0.09 245)', soft: 'oklch(0.95 0.02 245)' },
    { id: 'work', label: '工作·学业', count: DAYS.filter(d=>d.category==='work').length, icon: '✦', color: 'oklch(0.6 0.08 155)', soft: 'oklch(0.95 0.025 155)' },
    { id: 'life', label: '生活', count: DAYS.filter(d=>d.category==='life').length, icon: '◐', color: 'oklch(0.62 0.12 35)', soft: 'oklch(0.95 0.025 35)' },
  ];

  return (
    <div style={{ height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink)', cursor: 'pointer', padding: 4 }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M11 3L5 9l6 6"/></svg>
        </button>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>分类</div>
        <button style={{ border: 'none', background: 'transparent', color: 'var(--terracotta)', font: '500 14px var(--sans)', cursor: 'pointer' }}>编辑</button>
      </div>

      <div style={{ padding: '18px 20px 8px', flexShrink: 0 }}>
        <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 30, fontWeight: 600, letterSpacing: '-0.02em' }}>你的分类</h1>
        <p style={{ margin: '4px 0 0', color: 'var(--muted)', fontSize: 13 }}>共 {DAYS.length} 个日子 · 5 个分类</p>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '16px 20px 24px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {cats.map((c, i) => (
            <div key={c.id} onClick={() => onOpenCategory && onOpenCategory(c.id)} className="sg-tap" style={{
              background: c.soft, borderRadius: 20, padding: 16,
              height: i === 0 ? 140 : 110,
              gridColumn: i === 0 ? 'span 2' : 'span 1',
              position: 'relative', cursor: 'pointer', overflow: 'hidden',
              border: '1px solid var(--hairline)',
            }}>
              <div style={{ fontSize: i===0?32:24, color: c.color, marginBottom: 6 }}>{c.icon}</div>
              <div style={{ fontFamily: 'var(--serif)', fontSize: i===0?20:16, fontWeight: 600, color: 'var(--ink)' }}>{c.label}</div>
              <div style={{ fontSize: 12, color: c.color, marginTop: 2, fontWeight: 500 }}>{c.count} 个日子</div>
              {/* sample photos peek */}
              {i===0 && (
                <div style={{ position: 'absolute', right: 14, top: 14, display: 'flex', gap: -4 }}>
                  {['photo-wedding','photo-baby','photo-japan'].map((p, j) => (
                    <div key={p} className={`photo ${p} photo-flat`} style={{
                      width: 36, height: 36, borderRadius: 10, marginLeft: j===0?0:-10,
                      border: '2px solid var(--bg)', position: 'relative', zIndex: 3-j,
                    }}/>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        <div style={{ marginTop: 24, padding: '14px 16px', background: 'var(--card)', borderRadius: 18,
          border: '1px dashed var(--hairline-strong)', display: 'flex', alignItems: 'center', gap: 12,
          cursor: 'pointer' }}>
          <div style={{ width: 36, height: 36, borderRadius: 10, background: 'var(--bg-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)' }}>+</div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>新建分类</div>
            <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 1 }}>自己定义标签和颜色</div>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CategoriesScreen });

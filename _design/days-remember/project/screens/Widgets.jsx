/* Screen: Widgets gallery */

function WidgetsScreen({ onBack }) {
  const [size, setSize] = React.useState('m');
  return (
    <div style={{ height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink)', cursor: 'pointer', padding: 4 }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M11 3L5 9l6 6"/></svg>
        </button>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>桌面小组件</div>
        <div style={{ width: 18 }}/>
      </div>

      <div style={{ padding: '12px 20px 8px', flexShrink: 0 }}>
        <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 26, fontWeight: 600 }}>把日子放在主屏</h1>
        <p style={{ margin: '4px 0 0', color: 'var(--muted)', fontSize: 13 }}>每次解锁手机，都和重要的日子打个招呼</p>
      </div>

      {/* Size picker */}
      <div style={{ padding: '14px 20px', display: 'flex', gap: 8, flexShrink: 0 }}>
        {[{id:'s',l:'小'},{id:'m',l:'中'},{id:'l',l:'大'}].map(s => (
          <button key={s.id} onClick={()=>setSize(s.id)} style={{
            padding: '7px 14px', borderRadius: 999, border: 'none', cursor: 'pointer',
            background: size===s.id ? 'var(--ink)' : 'var(--card)',
            color: size===s.id ? 'var(--bg)' : 'var(--ink-2)',
            fontSize: 13, fontWeight: 500, fontFamily: 'var(--sans)',
          }}>{s.l}号</button>
        ))}
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '8px 20px 24px' }}>
        {/* Sample wallpaper background */}
        <div style={{
          background: 'linear-gradient(160deg, oklch(0.62 0.08 250) 0%, oklch(0.42 0.08 270) 100%)',
          borderRadius: 24, padding: '34px 20px 28px', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, alignItems: 'center' }}>
            {size === 's' && <SmallWidget/>}
            {size === 'm' && <MediumWidget/>}
            {size === 'l' && <LargeWidget/>}
          </div>
          <div style={{ marginTop: 16, textAlign: 'center', color: 'rgba(255,255,255,0.7)', fontSize: 11 }}>主屏预览</div>
        </div>

        {/* Style options */}
        <div style={{ marginTop: 22, fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 12, fontWeight: 600 }}>风格</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {['photo','minimal','typography','collage'].map((style, i) => (
            <div key={style} style={{
              aspectRatio: '1', borderRadius: 16, padding: 12,
              background: i===0 ? 'var(--ink)' : i===1 ? 'var(--bg-2)' : i===2 ? 'var(--card)' : 'var(--card)',
              color: i===0 ? 'var(--bg)' : 'var(--ink)',
              border: i!==0 ? '1px solid var(--hairline)' : 'none',
              display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
              cursor: 'pointer',
            }}>
              <div style={{ fontSize: 11, opacity: 0.7 }}>样式 {i+1}</div>
              {i===0 && <div><div style={{ fontFamily: 'var(--serif)', fontSize: 32, fontWeight: 500, lineHeight: 1 }}>132</div><div style={{ fontSize: 10, opacity: 0.7, marginTop: 2 }}>蜜月旅行 · 天</div></div>}
              {i===1 && <div><div style={{ fontFamily: 'var(--serif)', fontSize: 30, fontWeight: 500, lineHeight: 1, color: 'var(--terracotta)' }}>132</div><div style={{ fontSize: 10, color: 'var(--muted)', marginTop: 2 }}>蜜月旅行</div></div>}
              {i===2 && <div style={{ fontFamily: 'var(--serif)', fontSize: 14, fontWeight: 500 }}>距 蜜月旅行<br/>还有 132 天</div>}
              {i===3 && <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 3, height: '100%' }}>
                <div className="photo photo-japan photo-flat" style={{ borderRadius: 6 }}/>
                <div className="photo photo-wedding photo-flat" style={{ borderRadius: 6 }}/>
                <div className="photo photo-baby photo-flat" style={{ borderRadius: 6 }}/>
                <div className="photo photo-birthday photo-flat" style={{ borderRadius: 6 }}/>
              </div>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function SmallWidget() {
  return (
    <div className="photo photo-japan" style={{ width: 150, height: 150, borderRadius: 22, position: 'relative' }}>
      <div style={{ position: 'absolute', inset: 0, padding: 14, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', color: '#FFF' }}>
        <div style={{ fontSize: 10, opacity: 0.85, marginBottom: 2 }}>蜜月旅行</div>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 44, fontWeight: 500, lineHeight: 0.9, letterSpacing: '-0.04em' }} className="sg-tnum">132</div>
        <div style={{ fontSize: 10, opacity: 0.8, marginTop: 2 }}>天后 · 京都</div>
      </div>
    </div>
  );
}
function MediumWidget() {
  return (
    <div style={{ width: 320, height: 150, borderRadius: 22, background: 'rgba(255,255,255,0.95)', display: 'flex', overflow: 'hidden', boxShadow: '0 8px 28px rgba(0,0,0,0.18)' }}>
      <div className="photo photo-japan" style={{ width: 150, height: '100%' }}/>
      <div style={{ flex: 1, padding: '14px 16px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 10, color: '#8A8074', letterSpacing: '0.2em', textTransform: 'uppercase' }}>即将到来</div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 16, fontWeight: 600, marginTop: 4, color: '#1F1A15' }}>蜜月旅行</div>
        </div>
        <div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 38, fontWeight: 500, color: 'oklch(0.62 0.12 35)', lineHeight: 0.9, letterSpacing: '-0.03em' }} className="sg-tnum">132</div>
          <div style={{ fontSize: 11, color: '#8A8074', marginTop: 2 }}>天 · 8月23日</div>
        </div>
      </div>
    </div>
  );
}
function LargeWidget() {
  return (
    <div style={{ width: 320, height: 320, borderRadius: 22, background: 'rgba(255,255,255,0.95)', overflow: 'hidden', boxShadow: '0 8px 28px rgba(0,0,0,0.18)' }}>
      <div className="photo photo-japan" style={{ height: 160 }}/>
      <div style={{ padding: 16 }}>
        <div style={{ fontSize: 10, color: '#8A8074', letterSpacing: '0.2em', textTransform: 'uppercase' }}>即将到来</div>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 18, fontWeight: 600, marginTop: 4, color: '#1F1A15' }}>蜜月旅行</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 10 }}>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 56, fontWeight: 500, color: 'oklch(0.62 0.12 35)', lineHeight: 0.9, letterSpacing: '-0.04em' }} className="sg-tnum">132</div>
          <div style={{ fontSize: 12, color: '#8A8074' }}>天后 · 京都</div>
        </div>
        <div style={{ marginTop: 12, display: 'flex', gap: 6 }}>
          {[1,2,3,4].map(i => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i===1?'oklch(0.62 0.12 35)':'#EFE9DF' }}/>)}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { WidgetsScreen });

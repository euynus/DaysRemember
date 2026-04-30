/* Screen: Onboarding */

function Onboarding({ dark }) {
  const [page, setPage] = React.useState(0);
  const pages = [
    { kind: 'hero', eyebrow: '时光', title: '记住那些\n重要的日子', sub: '结婚纪念、宝宝出生、一场旅行，\n让时间被温柔地记录。' },
    { kind: 'count', big: '2387', title: '倒数，或者纪念', sub: '过去的可以回望，\n未来的值得期待。' },
    { kind: 'photo', title: '加上一张照片\n让日子有温度', sub: '一张图胜过千言万语。' },
    { kind: 'final', title: '让时间被好好珍藏', sub: '现在开始，记录你的第一个日子。' },
  ];
  const cur = pages[page];
  const isFinal = page === 3;
  const textColor = isFinal ? '#FFF' : 'var(--ink)';
  const subColor = isFinal ? 'rgba(255,255,255,0.8)' : 'var(--ink-2)';

  return (
    <div className="sg" style={{
      height: '100%', display: 'flex', flexDirection: 'column',
      background: isFinal
        ? 'linear-gradient(170deg, oklch(0.55 0.11 30) 0%, oklch(0.35 0.08 20) 100%)'
        : 'var(--bg)',
    }}>
      <div style={{ flex: 1, padding: '80px 32px 0', overflow: 'hidden' }}>
        {cur.kind === 'hero' && <HeroArt/>}
        {cur.kind === 'count' && <CountDemoArt/>}
        {cur.kind === 'photo' && <PhotoDemoArt/>}
        {cur.kind === 'final' && <FinalArt/>}
        <div style={{ marginTop: 36, color: textColor }}>
          {cur.eyebrow && <div style={{ fontFamily: 'var(--serif)', fontSize: 14, letterSpacing: '0.4em', color: 'var(--terracotta)', marginBottom: 24, textTransform: 'uppercase' }}>{cur.eyebrow}</div>}
          <h1 style={{ fontFamily: 'var(--serif)', fontWeight: 600, fontSize: 32, lineHeight: 1.3, margin: 0, whiteSpace: 'pre-line', letterSpacing: '-0.01em' }}>{cur.title}</h1>
          {cur.sub && <p style={{ margin: '16px 0 0', fontSize: 15, lineHeight: 1.7, color: subColor, whiteSpace: 'pre-line' }}>{cur.sub}</p>}
        </div>
      </div>
      <div style={{ padding: '24px 32px 48px' }}>
        <div style={{ display: 'flex', gap: 6, marginBottom: 24, justifyContent: 'center' }}>
          {pages.map((_, i) => (
            <div key={i} style={{
              width: i === page ? 22 : 6, height: 6, borderRadius: 3,
              background: i === page ? (isFinal ? '#FFF' : 'var(--terracotta)') : (isFinal ? 'rgba(255,255,255,0.3)' : 'var(--hairline-strong)'),
            }}/>
          ))}
        </div>
        {!isFinal ? (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <button onClick={() => setPage(3)} style={{ border: 'none', background: 'transparent', color: 'var(--muted)', font: '500 14px var(--sans)', cursor: 'pointer' }}>跳过</button>
            <button onClick={() => setPage(p => p+1)} className="sg-btn accent" style={{ padding: '14px 28px', borderRadius: 999 }}>下一步 →</button>
          </div>
        ) : (
          <button className="sg-btn" style={{ width: '100%', padding: '16px', borderRadius: 999, background: '#FFF', color: 'oklch(0.45 0.09 25)', fontSize: 16, fontWeight: 600 }}>开始记录 ✨</button>
        )}
      </div>
    </div>
  );
}

function HeroArt() {
  return (
    <div style={{ height: 280, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="photo photo-birthday photo-flat" style={{ position: 'absolute', width: 140, height: 180, borderRadius: 20, transform: 'rotate(-8deg) translate(-46px, 10px)', boxShadow: '0 12px 32px rgba(0,0,0,0.15)' }}/>
      <div className="photo photo-japan photo-flat" style={{ position: 'absolute', width: 140, height: 180, borderRadius: 20, transform: 'rotate(6deg) translate(46px, -6px)', boxShadow: '0 12px 32px rgba(0,0,0,0.15)' }}/>
      <div className="photo photo-wedding photo-flat" style={{ position: 'absolute', width: 140, height: 180, borderRadius: 20, zIndex: 2, boxShadow: '0 16px 40px rgba(0,0,0,0.18)' }}>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'flex-end', padding: 14 }}>
          <div style={{ color: '#fff', fontFamily: 'var(--serif)' }}>
            <div style={{ fontSize: 11, opacity: 0.85 }}>结婚 · 第7年</div>
            <div style={{ fontSize: 22, fontWeight: 600 }}>2387<span style={{ fontSize: 12, opacity: 0.8, marginLeft: 3 }}>天</span></div>
          </div>
        </div>
      </div>
    </div>
  );
}

function CountDemoArt() {
  return (
    <div style={{ height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column' }}>
      <div style={{ fontFamily: 'var(--serif)', fontSize: 128, fontWeight: 500, color: 'var(--terracotta)', lineHeight: 1, letterSpacing: '-0.04em' }} className="sg-tnum">2387</div>
      <div style={{ marginTop: 8, fontSize: 13, color: 'var(--muted)', letterSpacing: '0.3em' }}>天 · 自 2019.10.12</div>
    </div>
  );
}

function PhotoDemoArt() {
  return (
    <div style={{ height: 280, display: 'grid', gridTemplateColumns: '1fr 1fr', gridTemplateRows: '1fr 1fr', gap: 10 }}>
      <div className="photo photo-wedding" style={{ borderRadius: 18, gridRow: 'span 2', position: 'relative' }}>
        <div style={{ position: 'absolute', bottom: 12, left: 12, right: 12, color: '#fff' }}>
          <div style={{ fontSize: 11, opacity: 0.8, fontFamily: 'var(--serif)' }}>结婚纪念日</div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 18, fontWeight: 600 }}>2387 天</div>
        </div>
      </div>
      <div className="photo photo-baby" style={{ borderRadius: 18, position: 'relative' }}>
        <div style={{ position: 'absolute', bottom: 8, left: 10, right: 10, color: '#fff', fontFamily: 'var(--serif)' }}>
          <div style={{ fontSize: 10, opacity: 0.85 }}>小年糕</div>
          <div style={{ fontSize: 14, fontWeight: 600 }}>1165 天</div>
        </div>
      </div>
      <div className="photo photo-japan" style={{ borderRadius: 18, position: 'relative' }}>
        <div style={{ position: 'absolute', bottom: 8, left: 10, right: 10, color: '#fff', fontFamily: 'var(--serif)' }}>
          <div style={{ fontSize: 10, opacity: 0.85 }}>北海道</div>
          <div style={{ fontSize: 14, fontWeight: 600 }}>还有 88 天</div>
        </div>
      </div>
    </div>
  );
}

function FinalArt() {
  return (
    <div style={{ height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
      <div style={{ width: 200, height: 200, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        <div style={{ width: 140, height: 140, borderRadius: '50%', border: '1px solid rgba(255,255,255,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontFamily: 'var(--serif)', fontSize: 48 }}>✦</div>
      </div>
    </div>
  );
}

Object.assign(window, { Onboarding, HeroArt, CountDemoArt, PhotoDemoArt, FinalArt });

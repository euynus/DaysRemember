/* Screen: Share & moments */

function ShareCardScreen({ day, onBack }) {
  const d = day || DAYS.find(x => x.id === 'wedding');
  const info = dayInfo(d);
  day = d;
  const [tpl, setTpl] = React.useState('classic');
  const tpls = [
    { id: 'classic', label: '经典' },
    { id: 'frame', label: '相框' },
    { id: 'minimal', label: '极简' },
    { id: 'collage', label: '拼贴' },
  ];

  return (
    <div style={{ height: '100%', background: 'var(--bg-2)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink-2)', cursor: 'pointer', padding: 4, font: '500 15px var(--sans)' }}>取消</button>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>分享</div>
        <button style={{ border: 'none', background: 'transparent', color: 'var(--terracotta)', font: '600 15px var(--sans)', cursor: 'pointer' }}>保存</button>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '20px 32px' }}>
        {/* Card preview */}
        {tpl === 'classic' && <ClassicCard day={day} info={info}/>}
        {tpl === 'frame' && <FrameCard day={day} info={info}/>}
        {tpl === 'minimal' && <MinimalCard day={day} info={info}/>}
        {tpl === 'collage' && <CollageCard day={day} info={info}/>}
      </div>

      {/* Template picker */}
      <div style={{ padding: '12px 20px 14px', display: 'flex', gap: 8, flexShrink: 0, justifyContent: 'center' }}>
        {tpls.map(t => (
          <button key={t.id} onClick={()=>setTpl(t.id)} style={{
            padding: '8px 14px', borderRadius: 999, border: 'none', cursor: 'pointer',
            background: tpl===t.id ? 'var(--ink)' : 'var(--card)',
            color: tpl===t.id ? 'var(--bg)' : 'var(--ink-2)',
            fontSize: 12, fontWeight: 500, fontFamily: 'var(--sans)',
          }}>{t.label}</button>
        ))}
      </div>

      {/* Share buttons */}
      <div style={{ padding: '4px 24px 36px', display: 'flex', gap: 16, justifyContent: 'space-around', flexShrink: 0 }}>
        {[
          { l: '微信', c: 'oklch(0.7 0.15 145)' },
          { l: '朋友圈', c: 'oklch(0.7 0.15 145)' },
          { l: '小红书', c: 'oklch(0.65 0.18 25)' },
          { l: '保存', c: 'var(--ink)' },
          { l: '更多', c: 'var(--ink-2)' },
        ].map(b => (
          <div key={b.l} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
            <div style={{ width: 44, height: 44, borderRadius: 14, background: b.c, opacity: 0.92,
              display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#FFF', fontSize: 11 }}>{b.l[0]}</div>
            <div style={{ fontSize: 11, color: 'var(--ink-2)' }}>{b.l}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ClassicCard({ day, info }) {
  return (
    <div className={`photo ${day.photo} grain`} style={{ width: 280, aspectRatio: '4/5', borderRadius: 18, position: 'relative',
      boxShadow: '0 12px 36px rgba(0,0,0,0.2)' }}>
      <div style={{ position: 'absolute', inset: 0, padding: 22, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', color: '#FFF' }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.3em', opacity: 0.8 }}>{day.categoryLabel}</div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 22, fontWeight: 600, marginTop: 6, lineHeight: 1.2 }}>{day.title}</div>
        </div>
        <div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 78, fontWeight: 500, lineHeight: 0.9, letterSpacing: '-0.04em' }} className="sg-tnum">{info.days}</div>
          <div style={{ fontSize: 12, opacity: 0.8, marginTop: 4, letterSpacing: '0.2em' }}>{info.isPast?'已经':'还有'} · 天</div>
          <div style={{ marginTop: 16, paddingTop: 14, borderTop: '0.5px solid rgba(255,255,255,0.3)', fontSize: 10, opacity: 0.65, letterSpacing: '0.2em' }}>SHIGUANG · 时光</div>
        </div>
      </div>
    </div>
  );
}
function FrameCard({ day, info }) {
  return (
    <div style={{ width: 280, aspectRatio: '4/5', background: '#FFF', borderRadius: 8, padding: 12,
      boxShadow: '0 12px 36px rgba(0,0,0,0.2)', display: 'flex', flexDirection: 'column' }}>
      <div className={`photo ${day.photo}`} style={{ flex: 1, borderRadius: 4 }}/>
      <div style={{ textAlign: 'center', padding: '14px 8px 4px' }}>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 16, fontWeight: 600, color: '#1F1A15' }}>{day.title}</div>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 32, fontWeight: 500, color: 'oklch(0.62 0.12 35)', marginTop: 4, letterSpacing: '-0.03em' }} className="sg-tnum">第 {info.days} 天</div>
        <div style={{ fontSize: 10, color: '#8A8074', marginTop: 4, letterSpacing: '0.2em' }}>{fmtCN(new Date(day.date))}</div>
      </div>
    </div>
  );
}
function MinimalCard({ day, info }) {
  return (
    <div style={{ width: 280, aspectRatio: '4/5', background: 'var(--bg)', borderRadius: 18, padding: 28,
      boxShadow: '0 12px 36px rgba(0,0,0,0.16)', display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      border: '1px solid var(--hairline)' }}>
      <div style={{ fontSize: 10, color: 'var(--muted)', letterSpacing: '0.3em', textTransform: 'uppercase', fontWeight: 600 }}>时光 · {fmtCN(new Date(day.date))}</div>
      <div>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 110, fontWeight: 500, color: 'var(--terracotta)', lineHeight: 0.85, letterSpacing: '-0.05em' }} className="sg-tnum">{info.days}</div>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 13, color: 'var(--muted)', marginTop: 8, letterSpacing: '0.2em' }}>{info.isPast?'已经过去':'还有'} · 天</div>
      </div>
      <div style={{ fontFamily: 'var(--serif)', fontSize: 18, fontWeight: 600, color: 'var(--ink)', lineHeight: 1.4 }}>{day.title}</div>
    </div>
  );
}
function CollageCard({ day, info }) {
  return (
    <div style={{ width: 280, aspectRatio: '4/5', background: 'var(--ink)', borderRadius: 18, padding: 16,
      boxShadow: '0 12px 36px rgba(0,0,0,0.2)', display: 'flex', flexDirection: 'column', gap: 8, color: '#FFF' }}>
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 6, flex: 1 }}>
        <div className={`photo ${day.photo}`} style={{ borderRadius: 12 }}/>
        <div style={{ display: 'grid', gridTemplateRows: '1fr 1fr', gap: 6 }}>
          <div className="photo photo-baby" style={{ borderRadius: 12 }}/>
          <div className="photo photo-japan" style={{ borderRadius: 12 }}/>
        </div>
      </div>
      <div style={{ padding: '8px 4px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 16, fontWeight: 600 }}>{day.title}</div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 28, fontWeight: 500, color: 'oklch(0.78 0.13 35)' }} className="sg-tnum">{info.days}</div>
        </div>
        <div style={{ fontSize: 10, opacity: 0.6, marginTop: 4, letterSpacing: '0.2em' }}>{fmtCN(new Date(day.date))} · 时光</div>
      </div>
    </div>
  );
}

Object.assign(window, { ShareCardScreen });

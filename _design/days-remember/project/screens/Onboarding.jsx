/* Screen: Onboarding — travel scrapbook welcome (paged) */

function OnboardingPaged({ page = 0 }) {
  const pages = [
    { kind: 'welcome', eyebrow: 'Days Remember', title: '把重要的日子\n做成手账', sub: '结婚纪念、宝宝出生、一场说走就走的旅行，\n都贴进你的时光手账。' },
    { kind: 'count', eyebrow: 'Countdown', title: '倒数，\n或者纪念', sub: '过去的可以回望，未来的值得期待。' },
    { kind: 'collage', eyebrow: 'Collage', title: '照片、贴纸、\n便利贴', sub: '每一天都值得被认真装点。' },
    { kind: 'start', eyebrow: 'Let\u2019s go', title: '现在，\n贴上第一张', sub: '我们陪你一起记住。', cta: '开始记录' },
  ];
  const cur = pages[page];
  const isStart = cur.kind === 'start';

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden' }}>
      {/* Art area */}
      <div style={{ flex: 1, position: 'relative', padding: '70px 28px 0', overflow: 'hidden' }}>
        {cur.kind === 'welcome' && <WelcomeArt/>}
        {cur.kind === 'count' && <CountArt/>}
        {cur.kind === 'collage' && <CollageArt/>}
        {cur.kind === 'start' && <StartArt/>}
      </div>

      {/* Copy + controls */}
      <div style={{ padding: '8px 30px 44px', flexShrink: 0 }}>
        <div className="sg-hand" style={{ fontSize: 26, color: 'var(--cat-travel)', lineHeight: 1, marginBottom: 10 }}>{cur.eyebrow}</div>
        <h1 style={{ margin: 0, fontSize: 34, fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1, whiteSpace: 'pre-line' }}>{cur.title}</h1>
        <p style={{ margin: '14px 0 0', fontSize: 15, lineHeight: 1.6, color: 'var(--ink-2)', whiteSpace: 'pre-line', fontWeight: 500 }}>{cur.sub}</p>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 28 }}>
          <div style={{ display: 'flex', gap: 6 }}>
            {pages.map((_, i) => (
              <div key={i} style={{ width: i === page ? 22 : 7, height: 7, borderRadius: 999, background: i === page ? 'var(--ink)' : 'var(--hairline-strong)', transition: 'width .2s' }}/>
            ))}
          </div>
          {isStart
            ? <button className="pill pill-dark">{cur.cta} <span style={{ fontSize: 18 }}>→</span></button>
            : <button className="pill pill-dark" style={{ width: 56, padding: 0 }}><span style={{ fontSize: 20 }}>→</span></button>}
        </div>
      </div>
    </div>
  );
}

function WelcomeArt() {
  return (
    <div style={{ height: '100%', position: 'relative' }}>
      <div style={{ position: 'absolute', top: 26, left: 14, zIndex: 2 }}>
        <div className="polaroid" style={{ width: 150, transform: 'rotate(-7deg)' }}>
          <div className="photo photo-japan" style={{ height: 180 }}/>
          <div style={{ padding: '8px 4px 2px' }} className="sg-hand"><span style={{ fontSize: 20, color: 'var(--ink-2)' }}>Kyoto, Japan</span></div>
        </div>
      </div>
      <div style={{ position: 'absolute', top: 70, right: 8, zIndex: 3 }}>
        <div className="polaroid" style={{ width: 140, transform: 'rotate(6deg)' }}>
          <div className="photo photo-wedding" style={{ height: 168 }}/>
          <div style={{ padding: '8px 4px 2px' }} className="sg-hand"><span style={{ fontSize: 20, color: 'var(--ink-2)' }}>Our day</span></div>
        </div>
      </div>
      <div style={{ position: 'absolute', top: 4, right: 28, zIndex: 5 }}>
        <StickyNote color="var(--note-yellow)" ink="var(--note-yellow-ink)" rotate={8} clip>记得每一天</StickyNote>
      </div>
      <div style={{ position: 'absolute', bottom: 24, left: 40, zIndex: 6 }}><Sticker name="plane" size={54} rotate={-12}/></div>
      <div style={{ position: 'absolute', bottom: 60, right: 30, zIndex: 6 }}><Sticker name="heart" size={40} rotate={10}/></div>
    </div>
  );
}

function CountArt() {
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
      <div className="polaroid" style={{ width: 220, transform: 'rotate(-2deg)' }}>
        <div className="photo photo-japan" style={{ height: 240, position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0) 40%, rgba(0,0,0,0.4))' }}/>
          <div style={{ position: 'absolute', left: 14, bottom: 12, color: '#fff' }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', opacity: 0.9 }}>北海道旅行</div>
          </div>
        </div>
        <div style={{ padding: '10px 4px 2px' }} className="sg-hand"><span style={{ fontSize: 22, color: 'var(--ink-2)' }}>20 Jul 2026</span></div>
      </div>
      <div style={{ position: 'absolute', top: 40, right: 18, zIndex: 5 }}>
        <StickyNote color="var(--note-blue)" ink="var(--note-blue-ink)" rotate={7} clip size="l">
          <div style={{ textAlign: 'center', lineHeight: 0.95 }}>
            <div style={{ fontSize: 40, fontWeight: 700 }} className="sg-tnum">88</div>
            <div style={{ fontSize: 18 }}>天后</div>
          </div>
        </StickyNote>
      </div>
      <div style={{ position: 'absolute', bottom: 30, left: 26, zIndex: 6 }}><Sticker name="sun" size={44} rotate={-8}/></div>
    </div>
  );
}

function CollageArt() {
  return (
    <div style={{ height: '100%', position: 'relative' }}>
      <div style={{ position: 'absolute', top: 30, left: 16, zIndex: 2 }}>
        <div className="polaroid" style={{ width: 130, transform: 'rotate(-8deg)' }}><div className="photo photo-baby" style={{ height: 150 }}/></div>
      </div>
      <div style={{ position: 'absolute', top: 16, right: 14, zIndex: 3 }}>
        <div className="polaroid" style={{ width: 124, transform: 'rotate(7deg)' }}><div className="photo photo-birthday" style={{ height: 140 }}/></div>
      </div>
      <div style={{ position: 'absolute', top: 150, left: 60, zIndex: 4 }}>
        <div className="polaroid" style={{ width: 130, transform: 'rotate(3deg)' }}><div className="photo photo-home" style={{ height: 150 }}/></div>
      </div>
      <div style={{ position: 'absolute', top: 110, left: 8, zIndex: 6 }}><Sticker name="camera" size={50} rotate={-14}/></div>
      <div style={{ position: 'absolute', top: 0, left: 110, zIndex: 6 }}>
        <StickyNote color="var(--note-pink)" ink="var(--note-pink-ink)" rotate={-6} clip>好久不见</StickyNote>
      </div>
      <div style={{ position: 'absolute', bottom: 20, right: 24, zIndex: 6 }}><Sticker name="cake" size={46} rotate={9}/></div>
    </div>
  );
}

function StartArt() {
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
      <div style={{ display: 'flex', gap: 0, position: 'relative' }}>
        {[['photo-wedding',-8,'ring'],['photo-japan',4,'plane'],['photo-baby',-4,'balloon']].map(([p,r,st], i) => (
          <div key={p} className="polaroid" style={{ width: 110, transform: `rotate(${r}deg) translateX(${i*-14}px)`, zIndex: i, marginLeft: i? -10:0 }}>
            <div className={`photo ${p}`} style={{ height: 130 }}/>
          </div>
        ))}
      </div>
      <div style={{ position: 'absolute', top: 40, right: 30, zIndex: 6 }}>
        <StickyNote color="var(--note-green)" ink="var(--note-green-ink)" rotate={8} clip>开始吧!</StickyNote>
      </div>
      <div style={{ position: 'absolute', bottom: 40, left: 36, zIndex: 6 }}><Sticker name="star" size={40} rotate={-10}/></div>
    </div>
  );
}

Object.assign(window, { OnboardingPaged });

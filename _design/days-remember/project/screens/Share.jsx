/* Screen: Share card — scrapbook postcard */

function ShareCardScreen({ onBack, day }) {
  const d = day || DAYS.find(x => x.id === 'wedding');
  const info = dayInfo(d);
  const [nc, ni] = noteColorFor(d.id);
  const [tpl, setTpl] = React.useState('polaroid');

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <NavBar onBack={onBack} title="分享"/>

      <div className="sg-scroll" style={{ flex: 1, padding: '8px 24px 24px' }}>
        {/* Postcard preview */}
        <div style={{ background: '#fff', borderRadius: 24, padding: 18, boxShadow: '0 1px 2px rgba(21,23,28,0.06), 0 14px 40px rgba(21,23,28,0.12)', position: 'relative' }}>
          {/* paper texture header */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <div className="sg-hand" style={{ fontSize: 26, color: 'var(--cat-travel)' }}>My Memory</div>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.12em', color: 'var(--muted)' }}>时光</div>
          </div>

          <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', paddingTop: 6, paddingBottom: 8 }}>
            <div className="polaroid" style={{ width: 230, transform: 'rotate(-2deg)' }}>
              <div className={`photo ${d.photo}`} style={{ height: 260 }}/>
              <div style={{ padding: '12px 6px 4px' }}>
                <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: '-0.02em' }}>{d.title}</div>
                <div className="sg-hand" style={{ fontSize: 22, color: 'var(--ink-2)', marginTop: 1 }}>{enDate(info.displayDate)}</div>
              </div>
            </div>
            <div style={{ position: 'absolute', top: -2, right: 14, zIndex: 5 }}>
              <StickyNote color={nc} ink={ni} rotate={7} clip>
                <div style={{ textAlign: 'center', lineHeight: 0.95 }}>
                  <div style={{ fontSize: 30, fontWeight: 700 }} className="sg-tnum">{info.days}</div>
                  <div style={{ fontSize: 13 }}>{info.isPast?'天了':'天后'}</div>
                </div>
              </StickyNote>
            </div>
            <div style={{ position: 'absolute', bottom: 20, left: 40, zIndex: 5 }}><Sticker name={stickerFor(d)} size={40} rotate={-12}/></div>
            <div style={{ position: 'absolute', top: 30, left: 26, zIndex: 5 }}><Sticker name="star" size={28} rotate={10}/></div>
          </div>

          {d.note && <div className="sg-hand-cn" style={{ fontSize: 19, color: '#3A3A3A', textAlign: 'center', marginTop: 6, lineHeight: 1.4 }}>「{d.note}」</div>}
        </div>

        {/* Template chips */}
        <div style={{ display: 'flex', gap: 8, marginTop: 18, justifyContent: 'center' }}>
          {[['polaroid','拍立得'],['note','便利贴'],['minimal','极简'],['collage','拼贴']].map(([v,l]) => (
            <button key={v} className={`chip ${tpl===v?'on':''}`} onClick={()=>setTpl(v)}>{l}</button>
          ))}
        </div>

        {/* Share actions */}
        <div style={{ marginTop: 24, display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12 }}>
          {[['微信','var(--cat-work)','微'],['朋友圈','var(--cat-travel)','圈'],['小红书','var(--cat-love)','红'],['保存','var(--ink)','↓']].map(([l,c,ic]) => (
            <div key={l} className="sg-tap" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
              <div style={{ width: 56, height: 56, borderRadius: 17, background: c, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 800, boxShadow: '0 4px 12px rgba(21,23,28,0.12)' }}>{ic}</div>
              <div style={{ fontSize: 12, color: 'var(--ink-2)', fontWeight: 600 }}>{l}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ShareCardScreen });

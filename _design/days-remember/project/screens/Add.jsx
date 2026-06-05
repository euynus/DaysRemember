/* Screen: Add / Edit Day — scrapbook composer */

function AddScreen({ onBack }) {
  const [title, setTitle] = React.useState('毕业十周年');
  const [category, setCategory] = React.useState('life');
  const [photo, setPhoto] = React.useState('photo-study');
  const [recurring, setRecurring] = React.useState(true);
  const [calType, setCalType] = React.useState('solar');
  const [remind, setRemind] = React.useState('7');

  const cats = [
    { id: 'love', label: '爱情' }, { id: 'family', label: '家人' },
    { id: 'travel', label: '旅行' }, { id: 'work', label: '工作' }, { id: 'life', label: '生活' },
  ];
  const photos = ['photo-wedding','photo-baby','photo-birthday','photo-japan','photo-study','photo-work','photo-pet','photo-home'];
  const stk = CAT_STICKER[category] || 'star';

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* bar */}
      <div style={{ padding: '56px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink-2)', font: '600 16px var(--sans)', cursor: 'pointer' }}>取消</button>
        <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em' }}>新的日子</div>
        <button className="pill pill-dark" style={{ height: 38, padding: '0 18px', fontSize: 14 }}>保存</button>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '12px 22px 30px' }}>
        {/* Live preview polaroid */}
        <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', paddingTop: 8, marginBottom: 26 }}>
          <div className="polaroid" style={{ width: 210, transform: 'rotate(-1.5deg)' }}>
            <div className={`photo ${photo}`} style={{ height: 200 }}/>
            <div style={{ padding: '10px 4px 2px' }}>
              <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.02em' }}>{title || '新的日子'}</div>
              <div className="sg-hand" style={{ fontSize: 20, color: 'var(--ink-2)', marginTop: 1 }}>2027 · Jun 20</div>
            </div>
          </div>
          <div style={{ position: 'absolute', top: 0, right: 24, zIndex: 5 }}>
            <StickyNote color="var(--note-blue)" ink="var(--note-blue-ink)" rotate={7} clip>
              <div style={{ textAlign: 'center', lineHeight: 0.95 }}>
                <div style={{ fontSize: 26, fontWeight: 700 }}>365</div>
                <div style={{ fontSize: 13 }}>天后</div>
              </div>
            </StickyNote>
          </div>
          <div style={{ position: 'absolute', bottom: 18, left: 60, zIndex: 5 }}><Sticker name={stk} size={36} rotate={-10}/></div>
        </div>

        {/* Title input */}
        <div className="sg-sec">标题</div>
        <input value={title} onChange={e => setTitle(e.target.value)} placeholder="给这一天起个名字"
          style={{ width: '100%', border: 'none', outline: 'none', background: '#fff', borderRadius: 16,
            padding: '14px 16px', font: '700 17px var(--sans)', color: 'var(--ink)', letterSpacing: '-0.01em',
            boxShadow: '0 1px 2px rgba(21,23,28,0.05)', marginBottom: 22 }}/>

        {/* Cover picker */}
        <div className="sg-sec">封面</div>
        <div style={{ display: 'flex', gap: 10, marginBottom: 22, overflowX: 'auto', scrollbarWidth: 'none', paddingBottom: 4, paddingTop: 4 }}>
          {photos.map(p => (
            <div key={p} onClick={() => setPhoto(p)} className="polaroid sg-tap" style={{
              width: 58, flexShrink: 0, padding: 4, cursor: 'pointer',
              outline: photo === p ? '3px solid var(--ink)' : 'none', outlineOffset: 2,
            }}>
              <div className={`photo ${p}`} style={{ height: 50 }}/>
            </div>
          ))}
          <div style={{ width: 58, height: 58, borderRadius: 14, flexShrink: 0, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)', boxShadow: '0 1px 2px rgba(21,23,28,0.05)', fontSize: 22 }}>+</div>
        </div>

        {/* Form list */}
        <div className="sg-list" style={{ marginBottom: 22 }}>
          <FormRow label="日期" value="2027 年 6 月 20 日" sub="农历 五月十六" chevron/>
          <FormRow label="日历" raw value={
            <div className="sg-seg-wrap"><Seg options={[['solar','公历'],['lunar','农历']]} val={calType} set={setCalType}/></div>
          }/>
          <FormRow label="类型" raw value={
            <Seg options={[['once','一次'],['year','每年']]} val={recurring?'year':'once'} set={v => setRecurring(v==='year')}/>
          }/>
          <FormRow label="提醒" raw value={
            <div style={{ display: 'flex', gap: 6 }}>
              {[['0','当天'],['1','1天'],['3','3天'],['7','7天']].map(([v,l]) => (
                <button key={v} onClick={() => setRemind(v)} style={{
                  padding: '6px 11px', borderRadius: 9, border: 'none', cursor: 'pointer',
                  background: remind===v ? 'var(--ink)' : 'var(--bg-2)', color: remind===v ? '#fff' : 'var(--ink-2)',
                  fontSize: 12, fontWeight: 700,
                }}>{l}</button>
              ))}
            </div>
          }/>
        </div>

        {/* Category */}
        <div className="sg-sec">分类</div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 22 }}>
          {cats.map(c => (
            <button key={c.id} onClick={() => setCategory(c.id)} className={`chip ${category===c.id?'on':''}`}>
              <Sticker name={CAT_STICKER[c.id]} size={18}/>
              {c.label}
            </button>
          ))}
        </div>

        {/* Note */}
        <div className="sg-sec">心情笔记</div>
        <div style={{
          background: '#FFFDF6', borderRadius: 14, padding: '16px 16px', minHeight: 92,
          boxShadow: '0 1px 2px rgba(21,23,28,0.06)',
          backgroundImage: 'repeating-linear-gradient(transparent, transparent 27px, rgba(21,23,28,0.06) 28px)',
        }}>
          <div className="sg-hand-cn" style={{ fontSize: 20, lineHeight: '28px', color: 'var(--muted)' }}>写下这一天的心情…</div>
        </div>
      </div>
    </div>
  );
}

function Seg({ options, val, set }) {
  return (
    <div style={{ display: 'inline-flex', background: 'var(--bg-2)', borderRadius: 9, padding: 2 }}>
      {options.map(([v, l]) => (
        <button key={v} onClick={() => set(v)} style={{
          padding: '6px 14px', borderRadius: 7, border: 'none', cursor: 'pointer',
          background: val===v ? '#fff' : 'transparent', color: val===v ? 'var(--ink)' : 'var(--ink-2)',
          fontSize: 13, fontWeight: 700, boxShadow: val===v ? '0 1px 2px rgba(0,0,0,0.08)' : 'none',
        }}>{l}</button>
      ))}
    </div>
  );
}

function FormRow({ label, value, sub, raw, chevron }) {
  return (
    <div className="sg-cell">
      <div style={{ flex: 1, fontSize: 15, fontWeight: 600 }}>{label}</div>
      {raw ? value : (
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ textAlign: 'right' }}>
            <div style={{ color: 'var(--ink-2)', fontSize: 14, fontWeight: 600 }}>{value}</div>
            {sub && <div style={{ color: 'var(--muted)', fontSize: 12, marginTop: 1 }}>{sub}</div>}
          </div>
          {chevron && <svg width="8" height="13" viewBox="0 0 8 13" fill="none" stroke="var(--muted)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1.5 1l5 5.5-5 5.5"/></svg>}
        </div>
      )}
    </div>
  );
}

Object.assign(window, { AddScreen });

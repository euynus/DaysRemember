/* Screen: Add / Edit Day */

function AddScreen({ onBack }) {
  const [title, setTitle] = React.useState('毕业十周年');
  const [category, setCategory] = React.useState('life');
  const [photo, setPhoto] = React.useState('photo-study');
  const [recurring, setRecurring] = React.useState(true);
  const [remind, setRemind] = React.useState('7');

  const cats = [
    { id: 'love', label: '爱情' },
    { id: 'family', label: '家人' },
    { id: 'travel', label: '旅行' },
    { id: 'work', label: '工作' },
    { id: 'life', label: '生活' },
  ];
  const photos = ['photo-wedding','photo-baby','photo-birthday','photo-japan','photo-study','photo-work','photo-pet','photo-home'];

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      <div style={{ padding: '60px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink-2)', font: '500 15px var(--sans)', cursor: 'pointer' }}>取消</button>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>新的日子</div>
        <button style={{ border: 'none', background: 'transparent', color: 'var(--terracotta)', font: '600 15px var(--sans)', cursor: 'pointer' }}>保存</button>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '8px 20px 24px' }}>
        {/* Photo preview with title */}
        <div className={`photo ${photo}`} style={{ height: 180, borderRadius: 22, marginBottom: 18, position: 'relative' }}>
          <div style={{ position: 'absolute', left: 16, right: 16, bottom: 14, color: '#FFF' }}>
            <div style={{ fontSize: 10, opacity: 0.8, letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 4 }}>{cats.find(c => c.id === category)?.label}</div>
            <input value={title} onChange={e => setTitle(e.target.value)}
              style={{ background: 'transparent', border: 'none', outline: 'none', color: '#FFF',
                font: '600 22px var(--serif)', width: '100%', padding: 0,
                borderBottom: '1px dashed rgba(255,255,255,0.4)', paddingBottom: 3,
              }}/>
          </div>
        </div>

        {/* Photo picker */}
        <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 10, fontWeight: 600 }}>封面</div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 22, overflowX: 'auto', scrollbarWidth: 'none' }}>
          {photos.map(p => (
            <div key={p} onClick={() => setPhoto(p)} className={`photo ${p} photo-flat`} style={{
              width: 56, height: 56, borderRadius: 14, flexShrink: 0, cursor: 'pointer',
              boxShadow: photo === p ? '0 0 0 2.5px var(--terracotta), 0 0 0 4.5px var(--bg)' : 'none',
              transition: 'box-shadow 0.15s',
            }}/>
          ))}
          <div style={{ width: 56, height: 56, borderRadius: 14, flexShrink: 0, background: 'var(--card)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--muted)',
            border: '1px dashed var(--hairline-strong)' }}>+</div>
        </div>

        {/* Form */}
        <div style={{ background: 'var(--card)', borderRadius: 18, padding: '2px 0', marginBottom: 16 }}>
          <FormRow label="日期" value="2027 年 6 月 20 日 · 农历 五月十六"/>
          <FormRow label="日历" value={
            <div style={{ display: 'flex', background: 'var(--bg-2)', borderRadius: 8, padding: 2 }}>
              <SegBtn on={true}>公历</SegBtn>
              <SegBtn on={false}>农历</SegBtn>
            </div>
          } raw/>
          <FormRow label="类型" value={
            <div style={{ display: 'flex', background: 'var(--bg-2)', borderRadius: 8, padding: 2 }}>
              <SegBtn on={!recurring} onClick={() => setRecurring(false)}>一次</SegBtn>
              <SegBtn on={recurring} onClick={() => setRecurring(true)}>每年</SegBtn>
            </div>
          } raw/>
          <FormRow label="提醒" value={
            <div style={{ display: 'flex', gap: 6 }}>
              {['当天','1天','3天','7天'].map((d,i) => (
                <button key={i} onClick={() => setRemind(String(i))} style={{
                  padding: '5px 10px', borderRadius: 7, border: 'none', cursor: 'pointer',
                  background: remind === String(i) ? 'var(--ink)' : 'transparent',
                  color: remind === String(i) ? 'var(--bg)' : 'var(--ink-2)',
                  fontSize: 12, fontWeight: 500, fontFamily: 'var(--sans)',
                }}>{d}</button>
              ))}
            </div>
          } raw last/>
        </div>

        {/* Category */}
        <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 10, fontWeight: 600 }}>分类</div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 22 }}>
          {cats.map(c => (
            <button key={c.id} onClick={() => setCategory(c.id)} style={{
              padding: '9px 16px', borderRadius: 999, border: 'none', cursor: 'pointer',
              background: category === c.id ? 'var(--ink)' : 'var(--card)',
              color: category === c.id ? 'var(--bg)' : 'var(--ink-2)',
              fontSize: 13, fontWeight: 500, fontFamily: 'var(--sans)',
            }}>{c.label}</button>
          ))}
        </div>

        {/* Notes */}
        <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 10, fontWeight: 600 }}>心情笔记</div>
        <div style={{ background: 'var(--card)', borderRadius: 18, padding: 16, minHeight: 90,
          fontFamily: 'var(--serif)', fontSize: 14, lineHeight: 1.7, color: 'var(--ink-2)', fontStyle: 'italic' }}>
          写下这一天的心情…
        </div>
      </div>
    </div>
  );
}

function FormRow({ label, value, raw, last }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '14px 18px', minHeight: 52,
      borderBottom: last ? 'none' : '0.5px solid var(--hairline)' }}>
      <div style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{label}</div>
      {raw ? value : <div style={{ color: 'var(--ink-2)', fontSize: 14 }}>{value}</div>}
    </div>
  );
}
function SegBtn({ on, onClick, children }) {
  return (
    <button onClick={onClick} style={{
      padding: '5px 12px', borderRadius: 6, border: 'none', cursor: 'pointer',
      background: on ? 'var(--card)' : 'transparent',
      color: on ? 'var(--ink)' : 'var(--ink-2)',
      fontSize: 12, fontWeight: 500, fontFamily: 'var(--sans)',
      boxShadow: on ? '0 1px 2px rgba(0,0,0,0.08)' : 'none',
    }}>{children}</button>
  );
}

Object.assign(window, { AddScreen });

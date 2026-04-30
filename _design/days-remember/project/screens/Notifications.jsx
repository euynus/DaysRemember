/* Screen: Notifications & reminders */

function NotificationsScreen({ onBack }) {
  const [pre, setPre] = React.useState({ '7': true, '3': true, '1': false, '0': true });
  const [moments, setMoments] = React.useState(true);
  const [memory, setMemory] = React.useState(true);
  const [quietHours, setQuietHours] = React.useState(true);

  return (
    <div style={{ height: '100%', background: 'var(--bg)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '60px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <button onClick={onBack} style={{ border: 'none', background: 'transparent', color: 'var(--ink)', cursor: 'pointer', padding: 4 }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M11 3L5 9l6 6"/></svg>
        </button>
        <div style={{ fontFamily: 'var(--serif)', fontSize: 17, fontWeight: 600 }}>提醒</div>
        <div style={{ width: 18 }}/>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '8px 20px 24px' }}>
        <div style={{ padding: '10px 4px 18px' }}>
          <h1 style={{ margin: 0, fontFamily: 'var(--serif)', fontSize: 26, fontWeight: 600 }}>不会忘记的提醒</h1>
          <p style={{ margin: '6px 0 0', color: 'var(--muted)', fontSize: 13, lineHeight: 1.6 }}>提前几天告诉你，让重要的日子从容到来。</p>
        </div>

        {/* Sample notification */}
        <div style={{ background: '#FFF', borderRadius: 18, padding: 14, marginBottom: 22,
          boxShadow: '0 1px 3px rgba(0,0,0,0.06)', border: '1px solid var(--hairline)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
            <div style={{ width: 28, height: 28, borderRadius: 7, background: 'var(--terracotta)', color: '#FFF',
              display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--serif)', fontWeight: 600, fontSize: 14 }}>时</div>
            <div style={{ fontSize: 12, fontWeight: 600 }}>时光</div>
            <div style={{ flex: 1 }}/>
            <div style={{ fontSize: 11, color: 'var(--muted)' }}>9:00</div>
          </div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 14, fontWeight: 600, marginBottom: 3 }}>蜜月旅行还有 7 天</div>
          <div style={{ fontSize: 12, color: 'var(--ink-2)', lineHeight: 1.5 }}>开始打包行李吧 · 京都 · 8月23日</div>
        </div>

        <Section title="提前提醒">
          <Toggle label="提前 7 天" on={pre['7']} onChange={()=>setPre({...pre,'7':!pre['7']})}/>
          <Toggle label="提前 3 天" on={pre['3']} onChange={()=>setPre({...pre,'3':!pre['3']})}/>
          <Toggle label="提前 1 天" on={pre['1']} onChange={()=>setPre({...pre,'1':!pre['1']})}/>
          <Toggle label="当天" on={pre['0']} onChange={()=>setPre({...pre,'0':!pre['0']})} last/>
        </Section>

        <Section title="提醒时间">
          <Row label="每日提醒时间" value="上午 9:00"/>
          <Row label="重要日子提醒" value="提前 1 天" last/>
        </Section>

        <Section title="智能提醒">
          <Toggle label="时光回忆" sub="一年前的今天发生了什么" on={memory} onChange={()=>setMemory(!memory)}/>
          <Toggle label="纪念日时刻" sub="发现日子背后的连接" on={moments} onChange={()=>setMoments(!moments)} last/>
        </Section>

        <Section title="勿扰">
          <Toggle label="夜间勿扰" sub="22:00 — 8:00 静音" on={quietHours} onChange={()=>setQuietHours(!quietHours)} last/>
        </Section>

        <div style={{ marginTop: 12, padding: '14px 16px', background: 'var(--terracotta-soft)', borderRadius: 14,
          fontSize: 12, color: 'var(--ink-2)', lineHeight: 1.6, fontFamily: 'var(--serif)', fontStyle: 'italic' }}>
          "每一个被记得的日子，都是一份温柔的提醒。"
        </div>
      </div>
    </div>
  );
}

function Section({ title, children }) {
  return (
    <div style={{ marginBottom: 18 }}>
      <div style={{ fontSize: 11, color: 'var(--muted)', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 8, fontWeight: 600, padding: '0 4px' }}>{title}</div>
      <div style={{ background: 'var(--card)', borderRadius: 16, padding: '2px 0' }}>
        {children}
      </div>
    </div>
  );
}
function Row({ label, value, last }) {
  return (
    <div style={{ padding: '14px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      borderBottom: last ? 'none' : '0.5px solid var(--hairline)' }}>
      <div style={{ fontSize: 14 }}>{label}</div>
      <div style={{ fontSize: 13, color: 'var(--muted)' }}>{value}</div>
    </div>
  );
}
function Toggle({ label, sub, on, onChange, last }) {
  return (
    <div onClick={onChange} style={{ padding: '12px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      borderBottom: last ? 'none' : '0.5px solid var(--hairline)', cursor: 'pointer' }}>
      <div>
        <div style={{ fontSize: 14, fontWeight: 500 }}>{label}</div>
        {sub && <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 2 }}>{sub}</div>}
      </div>
      <div style={{
        width: 44, height: 26, borderRadius: 13,
        background: on ? 'var(--terracotta)' : 'var(--bg-2)',
        position: 'relative', transition: 'background 0.2s',
      }}>
        <div style={{
          position: 'absolute', top: 2, left: on ? 20 : 2,
          width: 22, height: 22, borderRadius: '50%', background: '#FFF',
          boxShadow: '0 1px 3px rgba(0,0,0,0.15)', transition: 'left 0.2s',
        }}/>
      </div>
    </div>
  );
}

Object.assign(window, { NotificationsScreen });

/* Screen: Notifications & reminders — scrapbook */

function NotificationsScreen({ onBack }) {
  const [pre, setPre] = React.useState({ '7': true, '3': true, '1': false, '0': true });
  const [morning, setMorning] = React.useState(true);
  const [memory, setMemory] = React.useState(true);
  const [quiet, setQuiet] = React.useState(true);

  return (
    <div className="sg sg-canvas" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <NavBar onBack={onBack} title="提醒"/>

      <div style={{ padding: '6px 24px 2px', flexShrink: 0 }}>
        <h1 style={{ margin: 0, fontSize: 30, fontWeight: 800, letterSpacing: '-0.03em', lineHeight: 1.1 }}>温柔地提醒你</h1>
        <p style={{ margin: '6px 0 0', color: 'var(--ink-2)', fontSize: 14, lineHeight: 1.5, fontWeight: 500 }}>不吵你，只在那些重要的日子，轻轻敲一下。</p>
      </div>

      <div className="sg-scroll" style={{ flex: 1, padding: '18px 22px 120px' }}>
        {/* preview notification card pinned with clip */}
        <div style={{ position: 'relative', marginBottom: 26 }}>
          <div style={{ background: '#fff', borderRadius: 18, padding: 14, boxShadow: '0 1px 2px rgba(21,23,28,0.06), 0 10px 24px rgba(21,23,28,0.08)', transform: 'rotate(-0.6deg)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
              <div style={{ width: 28, height: 28, borderRadius: 8, background: 'var(--ink)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 13 }}>时</div>
              <div style={{ fontSize: 12, fontWeight: 800 }}>时光 · Days Remember</div>
              <div style={{ flex: 1 }}/>
              <div style={{ fontSize: 11, color: 'var(--muted)', fontWeight: 600 }}>9:00</div>
            </div>
            <div style={{ fontSize: 14, fontWeight: 700 }}>再 7 天就是你们的结婚纪念日</div>
            <div className="sg-hand-cn" style={{ fontSize: 18, color: 'var(--ink-2)', marginTop: 4 }}>那天下了一场小雨，你笑着说是天使撒花。</div>
          </div>
          <div style={{ position: 'absolute', top: -10, left: 30 }}><Paperclip/></div>
          <div style={{ position: 'absolute', top: -6, right: 14, zIndex: 3 }}><Sticker name="heart" size={34} rotate={12}/></div>
        </div>

        <div className="sg-sec">提前提醒</div>
        <div className="sg-list" style={{ marginBottom: 22 }}>
          <ToggleRow label="提前 7 天" on={pre['7']} set={()=>setPre({...pre,'7':!pre['7']})}/>
          <ToggleRow label="提前 3 天" on={pre['3']} set={()=>setPre({...pre,'3':!pre['3']})}/>
          <ToggleRow label="提前 1 天" on={pre['1']} set={()=>setPre({...pre,'1':!pre['1']})}/>
          <ToggleRow label="当天提醒" on={pre['0']} set={()=>setPre({...pre,'0':!pre['0']})}/>
        </div>

        <div className="sg-sec">每日 & 智能</div>
        <div className="sg-list" style={{ marginBottom: 22 }}>
          <ToggleRow label="每日晨间问候" sub="每天 08:00" on={morning} set={()=>setMorning(!morning)}/>
          <ToggleRow label="时光回忆" sub="一年前的今天" on={memory} set={()=>setMemory(!memory)}/>
        </div>

        <div className="sg-sec">勿扰</div>
        <div className="sg-list">
          <ToggleRow label="夜间勿扰" sub="22:00 — 08:00 静音" on={quiet} set={()=>setQuiet(!quiet)}/>
        </div>
      </div>
    </div>
  );
}

function ToggleRow({ label, sub, on, set }) {
  return (
    <div className="sg-cell" onClick={set} style={{ cursor: 'pointer' }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 600 }}>{label}</div>
        {sub && <div style={{ fontSize: 12, color: 'var(--muted)', marginTop: 2, fontWeight: 500 }}>{sub}</div>}
      </div>
      <div style={{ width: 50, height: 30, borderRadius: 999, background: on ? 'var(--cat-work)' : 'var(--bg-2)', position: 'relative', transition: 'background 0.2s', flexShrink: 0 }}>
        <div style={{ position: 'absolute', top: 2, left: on ? 22 : 2, width: 26, height: 26, borderRadius: '50%', background: '#fff', transition: 'left 0.2s cubic-bezier(.2,.7,.3,1)', boxShadow: '0 1px 3px rgba(0,0,0,0.2)' }}/>
      </div>
    </div>
  );
}

Object.assign(window, { NotificationsScreen });

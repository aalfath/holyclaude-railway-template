// End-to-end check: log in, create a project and a Claude session, send one chat
// message over the web UI's WebSocket, wait for the run to complete.
// Usage: node e2e.mjs <base url> <username> <password>
const [base, user, pass] = process.argv.slice(2);
const WS = globalThis.WebSocket ?? (await import('/usr/local/lib/node_modules/@cloudcli-ai/cloudcli/node_modules/ws/index.js')).default;
const j = async (path, opts = {}, token) => {
  const r = await fetch(base + path, { ...opts, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) } });
  const t = await r.text(); let b; try { b = JSON.parse(t); } catch { b = t; }
  return { status: r.status, body: b };
};
const login = await j('/api/auth/login', { method: 'POST', body: JSON.stringify({ username: user, password: pass }) });
if (!login.body.token) { console.log('LOGIN FAILED', login.status, JSON.stringify(login.body)); process.exit(1); }
const token = login.body.token;
console.log('login ok');
const proj = await j('/api/projects/create-project', { method: 'POST', body: JSON.stringify({ path: process.env.PROJ || '/workspace/demo' }) }, token);
console.log('project', proj.status, JSON.stringify(proj.body).slice(0, 200));
const sess = await j('/api/providers/sessions', { method: 'POST', body: JSON.stringify({ provider: 'claude', projectPath: process.env.PROJ || '/workspace/demo' }) }, token);
console.log('session', sess.status, JSON.stringify(sess.body).slice(0, 300));
const d = sess.body.data ?? sess.body;
const sessionId = d.sessionId ?? d.session?.id ?? d.id;
const wsUrl = base.replace(/^http/, 'ws') + '/ws?token=' + encodeURIComponent(token);
const ws = new WS(wsUrl);
const t0 = Date.now();
const done = new Promise((resolve) => {
  const timer = setTimeout(() => resolve('TIMEOUT'), 120000);
  ws.onmessage = (ev) => {
    const s = typeof ev.data === 'string' ? ev.data : ev.data.toString();
    let m; try { m = JSON.parse(s); } catch { return; }
    const ty = m.type || m.kind;
    if (!/stream_delta/.test(s)) console.log('ws<', s.slice(0, 260));
    if (m.kind === 'permission_request') { console.log('approving', m.toolName); ws.send(JSON.stringify({ type: 'chat.permission-response', requestId: m.requestId, allow: true })); }
    if (/complete|error/i.test(ty || '') && !/content_block/i.test(s)) { clearTimeout(timer); resolve(ty); }
  };
});
ws.onopen = () => {
  console.log('ws open, sending chat to session', sessionId);
  ws.send(JSON.stringify({ type: 'chat.send', sessionId, content: 'Create hello.txt with a greeting.', options: { permissionMode: 'acceptEdits', cwd: '/workspace/demo', projectPath: '/workspace/demo' } }));
};
ws.onerror = (e) => console.log('ws error', e.message ?? e);
const r = await done;
console.log('RESULT', r, 'after', Date.now() - t0, 'ms');
ws.close();
process.exit(0);

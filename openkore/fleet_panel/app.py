#!/usr/bin/env python3
"""
FreshGrind fleet control panel — list/start/stop bots and edit control files online.

Auth: password from FLEET_PANEL_PASS_FILE (or FLEET_PANEL_PASSWORD env).
Bind: FLEET_PANEL_HOST (default 0.0.0.0) / FLEET_PANEL_PORT (default 8787).
"""
from __future__ import annotations

import hmac
import json
import os
import re
import secrets
import subprocess
import threading
import time
import urllib.parse
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

OK = Path(os.environ.get("OPENKORE_HOME", str(Path.home() / "openkore"))).resolve()
PANEL = Path(__file__).resolve().parent
PROFILES = OK / "profiles"
PACK_CTRL = OK / "fresh_grind" / "control"
CTRL = OK / "control"
SCRIPTS = OK / "scripts"
TF = os.environ.get("TMUX_CONF", "/exec-daemon/tmux.portal.conf")
HOST = os.environ.get("FLEET_PANEL_HOST", "0.0.0.0")
PORT = int(os.environ.get("FLEET_PANEL_PORT", "8787"))
PASS_FILE = Path(os.environ.get("FLEET_PANEL_PASS_FILE", str(PANEL / "panel.pass")))
SESSION_TTL = 60 * 60 * 24 * 7  # 7 days
PROFILE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")

# Logical editor names → relative path under a root
EDITABLE = {
    "config": "config.txt",  # per-profile only
    "macro": "eventMacros.txt",
    "mob": "mon_control.txt",
    "shared_config": "config-shared.txt",  # pack only
    "items": "items_control.txt",
    "pickup": "pickupitems.txt",
}

SESSIONS: dict[str, float] = {}
SESSIONS_LOCK = threading.Lock()
STATUS_CACHE: dict = {"ts": 0.0, "rows": [], "summary": "", "total": 0}
STATUS_LOCK = threading.Lock()


def load_password() -> str:
    env = os.environ.get("FLEET_PANEL_PASSWORD", "").strip()
    if env:
        return env
    if PASS_FILE.is_file():
        return PASS_FILE.read_text(encoding="utf-8").strip().splitlines()[0].strip()
    # bootstrap
    PASS_FILE.parent.mkdir(parents=True, exist_ok=True)
    pw = secrets.token_urlsafe(12)
    PASS_FILE.write_text(pw + "\n", encoding="utf-8")
    PASS_FILE.chmod(0o600)
    print(f"[fleet-panel] generated password → {PASS_FILE}", flush=True)
    print(f"[fleet-panel] PASSWORD: {pw}", flush=True)
    return pw


PASSWORD = load_password()


def session_token() -> str:
    return secrets.token_urlsafe(32)


def session_ok(token: str | None) -> bool:
    if not token:
        return False
    with SESSIONS_LOCK:
        exp = SESSIONS.get(token)
        if not exp:
            return False
        if exp < time.time():
            SESSIONS.pop(token, None)
            return False
        return True


def session_put(token: str) -> None:
    with SESSIONS_LOCK:
        SESSIONS[token] = time.time() + SESSION_TTL


def session_clear(token: str | None) -> None:
    if not token:
        return
    with SESSIONS_LOCK:
        SESSIONS.pop(token, None)


def run(cmd: list[str], timeout: int = 60) -> tuple[int, str]:
    try:
        p = subprocess.run(
            cmd,
            cwd=str(OK),
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "OPENKORE_HOME": str(OK), "TMUX_CONF": TF},
        )
        out = (p.stdout or "") + (p.stderr or "")
        return p.returncode, out.strip()
    except Exception as e:
        return 1, str(e)


def list_profiles() -> list[str]:
    if not PROFILES.is_dir():
        return []
    names = []
    for p in sorted(PROFILES.iterdir()):
        if p.is_dir() and (p / "config.txt").is_file() and p.name.startswith("Grind"):
            names.append(p.name)
    return names


def classify_profile(name: str) -> tuple[str, str]:
    sess = f"ok-{name}"
    code, _ = run(["tmux", "-f", TF, "has-session", "-t", f"={sess}"], timeout=5)
    if code != 0:
        return "DOWN", "no tmux session"
    code, out = run(["tmux", "-f", TF, "capture-pane", "-t", sess, "-p", "-S", "-40"], timeout=8)
    out = re.sub(r"\x1b\[[0-9;]*m", "", out or "")
    m = re.findall(r"Map Change: ([a-z0-9_]+)", out)
    mmap = m[-1] if m else ""
    if not mmap:
        mm = re.findall(
            r"prt_fild08|pay_fild08|pay_fild03|prontera|prt_in|alberta|alberta_in|payon|payon_in01|new_1-[123]",
            out,
        )
        mmap = mm[-1] if mm else ""
    if re.search(r"Password Error|Account name .* doesn.?t exist|permanently banned", out, re.I):
        return "LOGIN_FAIL", "login error"
    if re.search(r"There are no characters on this account|desired properties for your characters", out, re.I):
        return "NO_CHAR", "char create"
    if re.search(r"Cannot locate automacro|unexpected problem", out, re.I):
        return "CRASH", "macro/crash"
    if re.search(r"Buy failed \(insufficient zeny\)|Set to start talking with NPC Tool Dealer", out):
        return "STUCK_BUY", f"shop loop{(' @ ' + mmap) if mmap else ''}"
    if re.search(r"You attack|Monster .*died|Targeting", out):
        return "HUNTING", mmap or "?"
    if re.search(r"prt_fild08|pay_fild08|Prontera Field|Payon Forest", out):
        return "FIELD", mmap or "?"
    if re.search(r"PHASE2|Alberta|payon", out):
        return "PHASE2", mmap or "?"
    if re.search(r"Calculating lockMap route|Calculating auto-buy route|Calculating route|walk Prontera south", out):
        return "ROUTING", mmap or "?"
    if re.search(r"You are now: Sitting", out):
        return "SITTING", mmap or "?"
    if re.search(r"Connecting to Account|Connecting to Map|disconnected", out, re.I):
        return "CONNECTING", mmap
    return "ONLINE", mmap


def refresh_status() -> None:
    rows = []
    counts: dict[str, int] = {}
    for name in list_profiles():
        st, det = classify_profile(name)
        rows.append({"profile": name, "status": st, "detail": det})
        counts[st] = counts.get(st, 0) + 1
    order = [
        "HUNTING",
        "FIELD",
        "PHASE2",
        "ROUTING",
        "SITTING",
        "ONLINE",
        "STUCK_BUY",
        "CONNECTING",
        "LOGIN_FAIL",
        "NO_CHAR",
        "CRASH",
        "DOWN",
    ]
    parts = [f"{k}={counts[k]}" for k in order if k in counts]
    for k, v in counts.items():
        if k not in order:
            parts.append(f"{k}={v}")
    with STATUS_LOCK:
        STATUS_CACHE["rows"] = rows
        STATUS_CACHE["summary"] = " ".join(parts)
        STATUS_CACHE["total"] = len(rows)
        STATUS_CACHE["ts"] = time.time()


def status_loop() -> None:
    while True:
        try:
            refresh_status()
        except Exception as e:
            print(f"[fleet-panel] status refresh error: {e}", flush=True)
        time.sleep(12)


def safe_profile(name: str) -> str | None:
    if not PROFILE_RE.match(name or ""):
        return None
    p = (PROFILES / name).resolve()
    if not str(p).startswith(str(PROFILES) + os.sep):
        return None
    if not (p / "config.txt").is_file():
        return None
    return name


def resolve_edit(scope: str, profile: str | None, kind: str) -> Path | None:
    """Return absolute path for an editable file, or None if invalid."""
    if kind not in EDITABLE:
        return None
    fname = EDITABLE[kind]
    if scope == "profile":
        if kind in ("shared_config",):
            return None
        name = safe_profile(profile or "")
        if not name:
            return None
        # config always in profile; macro/mob may be profile override or created there
        if kind == "config":
            return PROFILES / name / "config.txt"
        return PROFILES / name / fname
    if scope == "shared":
        if kind == "config":
            return None
        # Prefer pack (repo source of truth), fall back to control/
        pack = PACK_CTRL / fname
        if kind == "shared_config":
            return PACK_CTRL / "config-shared.txt"
        if pack.parent.is_dir():
            return pack
        return CTRL / fname
    return None


def read_file(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)


def sync_shared_to_control() -> str:
    script = SCRIPTS / "install-shared-control.sh"
    if script.is_file():
        code, out = run(["bash", str(script)], timeout=30)
        return out or ("ok" if code == 0 else "sync failed")
    # manual copy
    msgs = []
    for f in ("eventMacros.txt", "mon_control.txt", "items_control.txt", "pickupitems.txt", "routeweights.txt"):
        src = PACK_CTRL / f
        if src.is_file():
            dst = CTRL / f
            dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
            msgs.append(f"control/{f}")
    return ", ".join(msgs) or "nothing to sync"


def start_bot(name: str) -> tuple[bool, str]:
    code, out = run(["bash", str(SCRIPTS / "start-bot.sh"), name], timeout=20)
    return code == 0, out or ("started" if code == 0 else "start failed")


def stop_bot(name: str) -> tuple[bool, str]:
    stop = SCRIPTS / "stop-bot.sh"
    if stop.is_file():
        code, out = run(["bash", str(stop), name], timeout=15)
        return code == 0, out or ("stopped" if code == 0 else "stop failed")
    sess = f"ok-{name}"
    code, out = run(["tmux", "-f", TF, "kill-session", "-t", f"={sess}"], timeout=10)
    return code == 0, out or ("stopped" if code == 0 else "not running")


PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>FreshGrind Control</title>
<style>
:root {
  --bg: #0c1118;
  --panel: #141b24;
  --line: #243041;
  --text: #e8eef6;
  --muted: #8b9bb0;
  --accent: #3d9cf0;
  --ok: #2f9e6b;
  --warn: #c7923e;
  --bad: #d45b5b;
  --field: #1a2330;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: "IBM Plex Mono", "JetBrains Mono", ui-monospace, monospace;
  background:
    radial-gradient(1200px 500px at 10% -10%, #1a2740 0%, transparent 55%),
    radial-gradient(900px 400px at 100% 0%, #13231c 0%, transparent 50%),
    var(--bg);
  color: var(--text);
  min-height: 100vh;
}
a { color: var(--accent); text-decoration: none; }
header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 18px 22px; border-bottom: 1px solid var(--line);
  background: rgba(12,17,24,.85); backdrop-filter: blur(8px);
  position: sticky; top: 0; z-index: 5;
}
header h1 { font-size: 15px; margin: 0; letter-spacing: .04em; font-weight: 600; }
header .meta { color: var(--muted); font-size: 12px; }
main { padding: 18px 22px 40px; max-width: 1200px; margin: 0 auto; }
.login {
  max-width: 360px; margin: 12vh auto; padding: 28px;
  background: var(--panel); border: 1px solid var(--line);
}
.login h2 { margin: 0 0 8px; font-size: 18px; }
.login p { color: var(--muted); font-size: 13px; margin: 0 0 18px; }
label { display: block; font-size: 12px; color: var(--muted); margin-bottom: 6px; }
input[type=password], input[type=text], select, textarea {
  width: 100%; background: var(--field); color: var(--text);
  border: 1px solid var(--line); padding: 10px 12px; font: inherit; font-size: 13px;
}
textarea { min-height: 52vh; line-height: 1.45; tab-size: 2; resize: vertical; }
button, .btn {
  appearance: none; border: 1px solid var(--line); background: #1e2a3a; color: var(--text);
  padding: 8px 12px; font: inherit; font-size: 12px; cursor: pointer;
}
button.primary, .btn.primary { background: var(--accent); border-color: #2b7fc7; color: #061018; font-weight: 600; }
button.ok { background: #1b3a2c; border-color: #2f9e6b; color: #b6f0d0; }
button.bad { background: #3a1b1b; border-color: #d45b5b; color: #ffc9c9; }
button:disabled { opacity: .5; cursor: not-allowed; }
.row { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.grid { display: grid; gap: 10px; }
.tabs { display: flex; gap: 6px; flex-wrap: wrap; margin: 0 0 14px; }
.tabs button { background: transparent; }
.tabs button.active { border-color: var(--accent); color: var(--accent); }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: middle; }
th { color: var(--muted); font-weight: 500; font-size: 11px; text-transform: uppercase; letter-spacing: .06em; }
.st { font-weight: 600; }
.st-HUNTING,.st-FIELD { color: #3ecf8e; }
.st-PHASE2,.st-ONLINE { color: #5eb1ff; }
.st-ROUTING,.st-CONNECTING,.st-SITTING { color: #e0b15a; }
.st-STUCK_BUY,.st-LOGIN_FAIL,.st-NO_CHAR,.st-CRASH,.st-DOWN { color: #ff7b7b; }
.toast {
  position: fixed; right: 16px; bottom: 16px; background: #102033; border: 1px solid var(--line);
  padding: 10px 14px; font-size: 12px; max-width: 360px; display: none; z-index: 20;
}
.toast.show { display: block; }
.toast.err { border-color: var(--bad); }
.panel-box { background: var(--panel); border: 1px solid var(--line); padding: 14px; margin-bottom: 14px; }
.hint { color: var(--muted); font-size: 12px; margin: 6px 0 12px; }
.actions button { margin-right: 4px; }
#view-editor .toolbar { margin-bottom: 10px; gap: 10px; }
</style>
</head>
<body>
<div id="app"></div>
<div id="toast" class="toast"></div>
<script>
const $ = (s, el=document) => el.querySelector(s);
const state = { authed: false, tab: 'fleet', profiles: [], summary: '', total: 0, ts: 0,
  edit: { scope: 'shared', profile: '', kind: 'macro', content: '', path: '' } };

async function api(path, opts={}) {
  const r = await fetch(path, {
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', ...(opts.headers||{}) },
    ...opts,
  });
  const text = await r.text();
  let data;
  try { data = JSON.parse(text); } catch { data = { ok:false, error:text || r.statusText }; }
  if (!r.ok) throw new Error(data.error || r.statusText);
  return data;
}

function toast(msg, err=false) {
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'toast show' + (err ? ' err' : '');
  clearTimeout(toast._tm);
  toast._tm = setTimeout(() => t.classList.remove('show'), 3500);
}

function renderLogin() {
  $('#app').innerHTML = `
  <div class="login">
    <h2>FreshGrind Control</h2>
    <p>Password-protects start/stop and config editing.</p>
    <form id="login-form">
      <label>Password</label>
      <input type="password" name="password" autocomplete="current-password" required autofocus/>
      <div style="height:12px"></div>
      <button class="primary" type="submit">Sign in</button>
    </form>
  </div>`;
  $('#login-form').onsubmit = async (e) => {
    e.preventDefault();
    const password = new FormData(e.target).get('password');
    try {
      await api('/api/login', { method:'POST', body: JSON.stringify({ password }) });
      state.authed = true;
      await boot();
    } catch (err) { toast(err.message, true); }
  };
}

function header(meta) {
  return `<header>
    <div>
      <h1>FreshGrind Control</h1>
      <div class="meta">${meta || ''}</div>
    </div>
    <div class="row">
      <button type="button" id="btn-refresh">Refresh</button>
      <button type="button" id="btn-logout">Logout</button>
    </div>
  </header>`;
}

function render() {
  if (!state.authed) return renderLogin();
  const meta = `total=${state.total} · ${state.summary || '…'} · updated ${state.ts || '—'}`;
  let body = '';
  if (state.tab === 'fleet') body = renderFleet();
  else if (state.tab === 'shared') body = renderEditor('shared');
  else body = renderEditor('profile');

  $('#app').innerHTML = `${header(meta)}
  <main>
    <div class="tabs">
      <button type="button" data-tab="fleet" class="${state.tab==='fleet'?'active':''}">Fleet</button>
      <button type="button" data-tab="shared" class="${state.tab==='shared'?'active':''}">Shared files</button>
      <button type="button" data-tab="profile" class="${state.tab==='profile'?'active':''}">Per-profile files</button>
    </div>
    ${body}
  </main>`;

  $('#btn-refresh').onclick = () => loadStatus(true);
  $('#btn-logout').onclick = async () => {
    await api('/api/logout', { method:'POST', body:'{}' });
    state.authed = false; render();
  };
  document.querySelectorAll('.tabs [data-tab]').forEach(b => {
    b.onclick = () => { state.tab = b.dataset.tab; render(); if (state.tab!=='fleet') loadEditor(); };
  });
  wireFleet();
  wireEditor();
}

function renderFleet() {
  const rows = state.profiles.map(p => `
    <tr data-profile="${p.profile}">
      <td><a href="#" data-open="${p.profile}">${p.profile}</a></td>
      <td class="st st-${p.status}">${p.status}</td>
      <td>${escapeHtml(p.detail || '')}</td>
      <td class="actions">
        <button type="button" class="ok" data-start="${p.profile}" ${p.status==='DOWN'?'':'disabled'}>Start</button>
        <button type="button" class="bad" data-stop="${p.profile}" ${p.status==='DOWN'?'disabled':''}>Stop</button>
      </td>
    </tr>`).join('');
  return `<div class="panel-box">
    <div class="row" style="justify-content:space-between;margin-bottom:10px">
      <div class="hint" style="margin:0">Start / stop each bot. Restart a bot after saving macros or shared control so OpenKore reloads files.</div>
      <div class="row">
        <button type="button" id="btn-start-down" class="ok">Start all DOWN</button>
        <button type="button" id="btn-stop-all" class="bad">Stop all</button>
      </div>
    </div>
    <table>
      <thead><tr><th>Profile</th><th>Status</th><th>Detail</th><th>Control</th></tr></thead>
      <tbody>${rows || '<tr><td colspan=4>No Grind profiles found</td></tr>'}</tbody>
    </table>
  </div>`;
}

function renderEditor(scope) {
  const e = state.edit;
  const kinds = scope === 'shared'
    ? [['macro','macro (eventMacros.txt)'],['mob','mob (mon_control.txt)'],['shared_config','shared config'],['items','items_control'],['pickup','pickupitems']]
    : [['config','config.txt'],['macro','macro override'],['mob','mob override']];
  const kindOpts = kinds.map(([k,l]) => `<option value="${k}" ${e.kind===k?'selected':''}>${l}</option>`).join('');
  const profOpts = state.profiles.map(p => `<option value="${p.profile}" ${e.profile===p.profile?'selected':''}>${p.profile}</option>`).join('');
  return `<div class="panel-box" id="view-editor">
    <div class="toolbar row">
      ${scope==='profile' ? `<label style="margin:0">Profile</label><select id="ed-profile" style="width:auto;min-width:140px">${profOpts}</select>` : ''}
      <label style="margin:0">File</label>
      <select id="ed-kind" style="width:auto;min-width:200px">${kindOpts}</select>
      <button type="button" class="primary" id="ed-save">Save</button>
      <button type="button" id="ed-reload">Reload</button>
      ${scope==='shared' ? `<button type="button" id="ed-sync">Sync to control/</button>` : ''}
    </div>
    <div class="hint" id="ed-path">${escapeHtml(e.path || 'Select a file…')}</div>
    ${scope==='profile' && e.kind!=='config' ? `<div class="hint">Profile overrides are optional. If empty/missing, the bot uses shared control/. Saving creates profiles/&lt;name&gt;/${e.kind==='macro'?'eventMacros.txt':'mon_control.txt'}.</div>` : ''}
    <textarea id="ed-body" spellcheck="false">${escapeHtml(e.content || '')}</textarea>
  </div>`;
}

function wireFleet() {
  document.querySelectorAll('[data-start]').forEach(b => b.onclick = async () => {
    b.disabled = true;
    try { const d = await api('/api/bot/start', { method:'POST', body: JSON.stringify({ profile: b.dataset.start })}); toast(d.message || 'started'); await loadStatus(true); }
    catch(e){ toast(e.message,true); b.disabled=false; }
  });
  document.querySelectorAll('[data-stop]').forEach(b => b.onclick = async () => {
    b.disabled = true;
    try { const d = await api('/api/bot/stop', { method:'POST', body: JSON.stringify({ profile: b.dataset.stop })}); toast(d.message || 'stopped'); await loadStatus(true); }
    catch(e){ toast(e.message,true); b.disabled=false; }
  });
  document.querySelectorAll('[data-open]').forEach(a => a.onclick = (ev) => {
    ev.preventDefault();
    state.tab = 'profile';
    state.edit.scope = 'profile';
    state.edit.profile = a.dataset.open;
    state.edit.kind = 'config';
    render(); loadEditor();
  });
  const sd = $('#btn-start-down');
  if (sd) sd.onclick = async () => {
    const down = state.profiles.filter(p => p.status==='DOWN').map(p => p.profile);
    for (const p of down) {
      try { await api('/api/bot/start', { method:'POST', body: JSON.stringify({ profile: p })}); }
      catch(e){ toast(`${p}: ${e.message}`, true); }
    }
    toast(`Started ${down.length} bot(s)`); await loadStatus(true);
  };
  const sa = $('#btn-stop-all');
  if (sa) sa.onclick = async () => {
    if (!confirm('Stop ALL running grind bots?')) return;
    const up = state.profiles.filter(p => p.status!=='DOWN').map(p => p.profile);
    for (const p of up) {
      try { await api('/api/bot/stop', { method:'POST', body: JSON.stringify({ profile: p })}); }
      catch(e){ toast(`${p}: ${e.message}`, true); }
    }
    toast(`Stopped ${up.length} bot(s)`); await loadStatus(true);
  };
}

function wireEditor() {
  const kind = $('#ed-kind');
  const prof = $('#ed-profile');
  const save = $('#ed-save');
  if (!kind) return;
  kind.onchange = () => { state.edit.kind = kind.value; loadEditor(); };
  if (prof) prof.onchange = () => { state.edit.profile = prof.value; loadEditor(); };
  $('#ed-reload').onclick = () => loadEditor();
  save.onclick = async () => {
    const content = $('#ed-body').value;
    try {
      const d = await api('/api/file', {
        method: 'POST',
        body: JSON.stringify({
          scope: state.tab === 'shared' ? 'shared' : 'profile',
          profile: state.edit.profile,
          kind: state.edit.kind,
          content,
        }),
      });
      toast(d.message || 'saved');
      state.edit.path = d.path || state.edit.path;
      const pathEl = $('#ed-path'); if (pathEl) pathEl.textContent = state.edit.path;
    } catch (e) { toast(e.message, true); }
  };
  const sync = $('#ed-sync');
  if (sync) sync.onclick = async () => {
    try { const d = await api('/api/sync-shared', { method:'POST', body:'{}' }); toast(d.message || 'synced'); }
    catch(e){ toast(e.message,true); }
  };
}

async function loadStatus(force=false) {
  const d = await api('/api/status' + (force ? '?refresh=1' : ''));
  state.profiles = d.profiles || [];
  state.summary = d.summary || '';
  state.total = d.total || 0;
  state.ts = d.updated || '';
  if (!state.edit.profile && state.profiles.length) state.edit.profile = state.profiles[0].profile;
  render();
}

async function loadEditor() {
  const scope = state.tab === 'shared' ? 'shared' : 'profile';
  state.edit.scope = scope;
  if (scope === 'shared' && state.edit.kind === 'config') state.edit.kind = 'macro';
  if (scope === 'profile' && ['shared_config','items','pickup'].includes(state.edit.kind)) state.edit.kind = 'config';
  try {
    const q = new URLSearchParams({ scope, kind: state.edit.kind, profile: state.edit.profile || '' });
    const d = await api('/api/file?' + q.toString());
    state.edit.content = d.content || '';
    state.edit.path = d.path || '';
    render();
  } catch (e) {
    state.edit.content = '';
    state.edit.path = e.message;
    render();
    toast(e.message, true);
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

async function boot() {
  try {
    const me = await api('/api/me');
    state.authed = !!me.ok;
  } catch { state.authed = false; }
  if (!state.authed) { render(); return; }
  await loadStatus();
  setInterval(() => { if (state.authed && state.tab==='fleet') loadStatus(); }, 15000);
}

boot();
</script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "FreshGrindPanel/1.0"

    def log_message(self, fmt, *args):
        print(f"[fleet-panel] {self.address_string()} {fmt % args}", flush=True)

    def _cookie_token(self) -> str | None:
        raw = self.headers.get("Cookie", "")
        c = SimpleCookie()
        try:
            c.load(raw)
        except Exception:
            return None
        morsel = c.get("fg_session")
        return morsel.value if morsel else None

    def _set_cookie(self, token: str | None) -> None:
        if token:
            self.send_header(
                "Set-Cookie",
                f"fg_session={token}; HttpOnly; Path=/; SameSite=Lax; Max-Age={SESSION_TTL}",
            )
        else:
            self.send_header("Set-Cookie", "fg_session=; HttpOnly; Path=/; Max-Age=0")

    def _json(self, code: int, obj: dict, set_token: str | None = None, clear_cookie: bool = False):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        if set_token is not None:
            self._set_cookie(set_token)
        if clear_cookie:
            self._set_cookie(None)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _html(self, code: int, text: str):
        body = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self) -> bytes:
        n = int(self.headers.get("Content-Length", "0") or 0)
        return self.rfile.read(n) if n > 0 else b""

    def _json_body(self) -> dict:
        raw = self._body()
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def _require_auth(self) -> bool:
        if session_ok(self._cookie_token()):
            return True
        self._json(401, {"ok": False, "error": "unauthorized"})
        return False

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)

        if path == "/":
            self._html(200, PAGE)
            return

        if path == "/api/me":
            ok = session_ok(self._cookie_token())
            self._json(200 if ok else 401, {"ok": ok})
            return

        if path == "/api/status":
            if not self._require_auth():
                return
            if qs.get("refresh", ["0"])[0] in ("1", "true", "yes"):
                try:
                    refresh_status()
                except Exception as e:
                    self._json(500, {"ok": False, "error": str(e)})
                    return
            with STATUS_LOCK:
                rows = list(STATUS_CACHE["rows"])
                summary = STATUS_CACHE["summary"]
                total = STATUS_CACHE["total"]
                ts = STATUS_CACHE["ts"]
            updated = (
                time.strftime("%Y-%m-%d %H:%M:%SZ", time.gmtime(ts)) if ts else "never"
            )
            self._json(
                200,
                {
                    "ok": True,
                    "profiles": rows,
                    "summary": summary,
                    "total": total,
                    "updated": updated,
                },
            )
            return

        if path == "/api/file":
            if not self._require_auth():
                return
            scope = (qs.get("scope", ["shared"])[0] or "shared").strip()
            kind = (qs.get("kind", ["macro"])[0] or "macro").strip()
            profile = (qs.get("profile", [""])[0] or "").strip()
            dest = resolve_edit(scope, profile, kind)
            if not dest:
                self._json(400, {"ok": False, "error": "invalid file request"})
                return
            content = read_file(dest)
            self._json(
                200,
                {
                    "ok": True,
                    "path": str(dest),
                    "exists": dest.is_file(),
                    "content": content,
                },
            )
            return

        self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/login":
            try:
                data = self._json_body()
            except Exception:
                self._json(400, {"ok": False, "error": "bad json"})
                return
            pw = str(data.get("password") or "")
            if not hmac.compare_digest(pw, PASSWORD):
                time.sleep(0.4)
                self._json(401, {"ok": False, "error": "bad password"})
                return
            tok = session_token()
            session_put(tok)
            self._json(200, {"ok": True}, set_token=tok)
            return

        if path == "/api/logout":
            session_clear(self._cookie_token())
            self._json(200, {"ok": True}, clear_cookie=True)
            return

        if not self._require_auth():
            return

        try:
            data = self._json_body()
        except Exception:
            self._json(400, {"ok": False, "error": "bad json"})
            return

        if path == "/api/bot/start":
            name = safe_profile(str(data.get("profile") or ""))
            if not name:
                self._json(400, {"ok": False, "error": "invalid profile"})
                return
            ok, msg = start_bot(name)
            threading.Thread(target=refresh_status, daemon=True).start()
            self._json(200 if ok else 500, {"ok": ok, "message": msg})
            return

        if path == "/api/bot/stop":
            name = safe_profile(str(data.get("profile") or ""))
            if not name:
                self._json(400, {"ok": False, "error": "invalid profile"})
                return
            ok, msg = stop_bot(name)
            threading.Thread(target=refresh_status, daemon=True).start()
            self._json(200 if ok else 500, {"ok": ok, "message": msg})
            return

        if path == "/api/file":
            scope = str(data.get("scope") or "shared").strip()
            kind = str(data.get("kind") or "").strip()
            profile = str(data.get("profile") or "").strip()
            content = data.get("content")
            if not isinstance(content, str):
                self._json(400, {"ok": False, "error": "content must be string"})
                return
            if len(content.encode("utf-8")) > 2_000_000:
                self._json(400, {"ok": False, "error": "file too large"})
                return
            dest = resolve_edit(scope, profile, kind)
            if not dest:
                self._json(400, {"ok": False, "error": "invalid file request"})
                return
            # refuse writing outside allowed roots
            allowed_roots = [PROFILES.resolve(), PACK_CTRL.resolve(), CTRL.resolve()]
            try:
                dest.resolve().relative_to(OK.resolve())
            except Exception:
                self._json(400, {"ok": False, "error": "path escape"})
                return
            if not any(
                str(dest.resolve()).startswith(str(r) + os.sep) or dest.resolve() == r
                for r in allowed_roots
            ):
                # profile file under profiles/<name>/
                if not str(dest.resolve()).startswith(str(PROFILES.resolve()) + os.sep):
                    self._json(400, {"ok": False, "error": "path not allowed"})
                    return
            write_file(dest, content)
            msg = f"saved {dest}"
            if scope == "shared" and kind in ("macro", "mob", "items", "pickup"):
                sync_msg = sync_shared_to_control()
                # also mirror into workspace pack if different
                ws_pack = Path("/workspace/openkore/fresh_grind/control")
                if ws_pack.is_dir() and dest.parent.resolve() != ws_pack.resolve():
                    try:
                        write_file(ws_pack / dest.name, content)
                    except Exception:
                        pass
                msg = f"saved + synced ({sync_msg}). Restart bots to reload macros."
            self._json(200, {"ok": True, "message": msg, "path": str(dest)})
            return

        if path == "/api/sync-shared":
            msg = sync_shared_to_control()
            self._json(200, {"ok": True, "message": msg})
            return

        self._json(404, {"ok": False, "error": "not found"})


def main():
    PANEL.mkdir(parents=True, exist_ok=True)
    # Install stop/start scripts into live openkore tree if running from workspace copy
    live_panel = OK / "fleet_panel"
    if PANEL.resolve() != live_panel.resolve():
        live_panel.mkdir(parents=True, exist_ok=True)
        for name in ("app.py",):
            src = PANEL / name
            if src.is_file():
                (live_panel / name).write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"[fleet-panel] OpenKore home: {OK}", flush=True)
    print(f"[fleet-panel] listening on http://{HOST}:{PORT}/", flush=True)
    threading.Thread(target=status_loop, daemon=True).start()
    # initial status in background so bind is immediate
    threading.Thread(target=refresh_status, daemon=True).start()
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    httpd.serve_forever()


if __name__ == "__main__":
    main()

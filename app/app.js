(() => {
  const KEY = "ragnaone.tiktok.v1";
  const VIEWS = [
    ["today", "Today"],
    ["studio", "Studio"],
    ["calendar", "Calendar"],
    ["tracker", "Tracker"],
    ["review", "Review"],
    ["playbook", "Playbook"],
    ["settings", "Settings"],
  ];

  const HOOKS = {
    proof: {
      label: "Proof drop",
      lines: [
        "This is the [pillar] result I wish I had on day one.",
        "I did [pillar] the hard way. Here is the proof.",
        "Before you scroll: this is what [promise] actually looks like.",
        "Save this. It is the [pillar] version that finally worked for [audience].",
        "I measured [niche] instead of guessing. Watch the number.",
      ],
    },
    investigator: {
      label: "Investigator",
      lines: [
        "Why do [audience] keep failing at [pillar]?",
        "I found the [niche] mistake nobody names out loud.",
        "What if the usual [pillar] advice is the reason you are stuck?",
        "I tracked this for 7 days. The pattern was not what I expected.",
        "One question: why does this [pillar] work when the popular one does not?",
      ],
    },
    problem: {
      label: "Problem → solution",
      lines: [
        "If [audience] are tired of [pain], do this instead.",
        "Stop doing [pillar] the long way. Here is the 60-second fix.",
        "[Audience] do not need more motivation. They need this [pillar] system.",
        "The problem is not [niche]. The problem is the first step.",
        "You can keep struggling with [pillar], or you can steal this.",
      ],
    },
    loop: {
      label: "Open loop",
      lines: [
        "There is one detail at the end most [audience] miss.",
        "Watch once for the method. Watch again for the part I hide in frame.",
        "I will show the [pillar] trick, then the reason it works.",
        "Do not comment until the last 3 seconds.",
        "This looks like a normal [niche] tip. It is not.",
      ],
    },
  };

  const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  const defaultState = () => ({
    profile: {
      handle: "",
      niche: "",
      audience: "",
      promise: "",
      pain: "",
      pillars: ["", "", ""],
      cadence: 4,
      startedOn: todayISO(),
    },
    setupComplete: false,
    videos: [],
    plan: [],
    checks: {},
    view: "today",
  });

  let state = load();

  function todayISO() {
    return new Date().toISOString().slice(0, 10);
  }

  function load() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return defaultState();
      return { ...defaultState(), ...JSON.parse(raw) };
    } catch {
      return defaultState();
    }
  }

  function save() {
    localStorage.setItem(KEY, JSON.stringify(state));
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function fill(template) {
    const p = state.profile;
    return template
      .replaceAll("[niche]", p.niche || "your niche")
      .replaceAll("[audience]", p.audience || "your viewer")
      .replaceAll("[Audience]", cap(p.audience || "your viewer"))
      .replaceAll("[promise]", p.promise || "the outcome")
      .replaceAll("[pain]", p.pain || "the usual grind")
      .replaceAll("[pillar]", currentPillar() || "this topic");
  }

  function cap(s) {
    return s ? s.charAt(0).toUpperCase() + s.slice(1) : s;
  }

  function currentPillar() {
    return state._studioPillar || state.profile.pillars.find(Boolean) || "";
  }

  function uid() {
    return Math.random().toString(36).slice(2, 10);
  }

  function weekday(iso) {
    return DAYS[new Date(iso + "T12:00:00").getDay()];
  }

  function addDays(iso, n) {
    const d = new Date(iso + "T12:00:00");
    d.setDate(d.getDate() + n);
    return d.toISOString().slice(0, 10);
  }

  function generatePlan() {
    const start = state.profile.startedOn || todayISO();
    const pillars = state.profile.pillars.filter(Boolean);
    const hookKeys = Object.keys(HOOKS);
    const cadence = Number(state.profile.cadence) || 4;
    const slots = [];
    let made = 0;
    for (let day = 0; day < 30 && made < cadence * 4 + 2; day += 1) {
      const date = addDays(start, day);
      const dow = new Date(date + "T12:00:00").getDay();
      const postDays = cadence >= 5 ? [1, 2, 3, 4, 5] : cadence === 4 ? [1, 2, 4, 6] : [1, 3, 5];
      if (!postDays.includes(dow) && day !== 0) continue;
      const week = Math.floor(day / 7);
      const pillar = pillars[made % Math.max(pillars.length, 1)] || "Core";
      const hook = hookKeys[made % hookKeys.length];
      const intent =
        week === 0
          ? "Prove the account. One idea, hard hook, keyword on frame one."
          : week === 1
            ? "Test a second angle of the same pillar. Do not drift niches."
            : week === 2
              ? "Repeat the winning pair. Series if saves were high."
              : "Only ship variations of what the tracker says is working.";
      slots.push({
        id: uid(),
        date,
        title: `${pillar} — ${HOOKS[hook].label}`,
        pillar,
        hook,
        length: week === 0 ? "35-50s" : "45-90s",
        intent,
        done: false,
      });
      made += 1;
    }
    state.plan = slots;
  }

  function profileReady() {
    const p = state.profile;
    return p.niche && p.audience && p.promise && p.pillars.filter(Boolean).length >= 2;
  }

  function checksFor(date) {
    const key = date;
    if (!state.checks[key]) {
      state.checks[key] = {
        script: false,
        shoot: false,
        seo: false,
        post: false,
        replies: false,
        niche: false,
        log: false,
      };
    }
    return state.checks[key];
  }

  function todayPlan() {
    const t = todayISO();
    return state.plan.find((item) => item.date === t) || state.plan.find((item) => item.date >= t && !item.done);
  }

  function metrics() {
    const videos = state.videos;
    const weekAgo = addDays(todayISO(), -7);
    const recent = videos.filter((v) => v.date >= weekAgo);
    const avg = (arr, key) => (arr.length ? Math.round(arr.reduce((s, v) => s + Number(v[key] || 0), 0) / arr.length) : 0);
    return {
      posted: videos.length,
      week: recent.length,
      completion: avg(videos, "completion"),
      saves: videos.reduce((s, v) => s + Number(v.saves || 0), 0),
      shares: videos.reduce((s, v) => s + Number(v.shares || 0), 0),
    };
  }

  function diagnose(video) {
    const c = Number(video.completion || 0);
    const views = Number(video.views || 0);
    const saves = Number(video.saves || 0);
    const shares = Number(video.shares || 0);
    if (views && views < 500 && c >= 70) return { tone: "warn", text: "High completion, small reach. Cold start or weak SEO. Keep the format, strengthen frame-one keyword." };
    if (c && c < 50) return { tone: "bad", text: "Completion is the problem. Rewrite the first 2 seconds or cut to the drop-off." };
    if (c >= 70 && (saves > 0 || shares > 0)) return { tone: "good", text: "This format earned a remake. Shoot 3 variations this week." };
    if (views > 1000 && saves === 0 && shares === 0) return { tone: "warn", text: "People watched. They did not keep it. Add a list, recipe, or send-to-a-friend line." };
    if (!views) return { tone: "", text: "Log Analytics after the first 24 hours." };
    return { tone: "warn", text: "Mixed. Compare hook and length against your other videos in Review." };
  }

  function render() {
    const root = document.getElementById("app");
    if (!state.setupComplete) {
      root.innerHTML = onboardHTML();
      bindOnboard();
      return;
    }
    root.innerHTML = `
      <div class="shell">
        <aside class="nav">
          <div class="brand">
            <div class="brand-kicker">RagnaOne</div>
            <h1>Growth OS</h1>
          </div>
          <div class="nav-links">
            ${VIEWS.map(([id, label]) => `
              <button data-view="${id}" class="${state.view === id ? "active" : ""}">${label}</button>
            `).join("")}
          </div>
          <div class="nav-foot">
            ${escapeHtml(state.profile.handle || "unset handle")}<br />
            ${escapeHtml(state.profile.niche || "set a niche")}
          </div>
        </aside>
        <main class="main">${viewHTML()}</main>
      </div>
    `;
    bindShell();
  }

  function viewHTML() {
    switch (state.view) {
      case "studio": return studioHTML();
      case "calendar": return calendarHTML();
      case "tracker": return trackerHTML();
      case "review": return reviewHTML();
      case "playbook": return playbookHTML();
      case "settings": return settingsHTML();
      default: return todayHTML();
    }
  }

  function todayHTML() {
    const m = metrics();
    const next = todayPlan();
    const checks = checksFor(todayISO());
    const checkItems = [
      ["script", "Write or lock today's script in Studio"],
      ["shoot", "Shoot and cut. Keyword on frame one."],
      ["seo", "Say the keyword, show it, put it in the caption"],
      ["post", "Post near your followers' active hours"],
      ["replies", "Reply to every comment in the first hour"],
      ["niche", "15 minutes of useful comments in-niche"],
      ["log", "Log yesterday's Analytics in Tracker"],
    ];
    return `
      <div class="page-head">
        <div>
          <h2>Today</h2>
          <p class="lede">Do the work that compounds. One video, honest numbers, the right followers.</p>
        </div>
        <button class="btn ghost" data-go="studio">Open studio</button>
      </div>
      <div class="grid cols-4">
        <div class="card stat"><div class="label">Videos logged</div><div class="value mono">${m.posted}</div><div class="hint">Lifetime in this browser</div></div>
        <div class="card stat"><div class="label">This week</div><div class="value mono">${m.week}</div><div class="hint">Target ${escapeHtml(state.profile.cadence)} / week</div></div>
        <div class="card stat"><div class="label">Avg completion</div><div class="value mono">${m.completion || "—"}%</div><div class="hint">Aim 70%+</div></div>
        <div class="card stat"><div class="label">Saves / shares</div><div class="value mono">${m.saves}/${m.shares}</div><div class="hint">These outrank likes</div></div>
      </div>
      <div class="grid cols-2" style="margin-top:16px">
        <div class="card">
          <h3>Next video</h3>
          ${next ? `
            <p class="mono" style="color:var(--gold)">${escapeHtml(next.date)} · ${weekday(next.date)}</p>
            <h4 style="margin:8px 0 6px;font-size:22px">${escapeHtml(next.title)}</h4>
            <p>${escapeHtml(next.intent)}</p>
            <p style="color:var(--muted)">Length ${escapeHtml(next.length)} · ${escapeHtml(HOOKS[next.hook].label)}</p>
            <div class="actions">
              <button class="btn" data-go="studio" data-pillar="${escapeHtml(next.pillar)}" data-hook="${escapeHtml(next.hook)}">Script this</button>
              <button class="btn ghost" data-complete-plan="${next.id}">Mark planned shoot done</button>
            </div>
          ` : `<div class="empty">No upcoming plan. Generate one in Settings after you set pillars.</div>`}
        </div>
        <div class="card">
          <h3>${escapeHtml(todayISO())} checklist</h3>
          ${checkItems.map(([id, label]) => `
            <label class="check">
              <input type="checkbox" data-check="${id}" ${checks[id] ? "checked" : ""} />
              <span>${label}</span>
            </label>
          `).join("")}
        </div>
      </div>
    `;
  }

  function studioHTML() {
    const pillar = state._studioPillar || state.profile.pillars[0] || "";
    const hook = state._studioHook || "proof";
    const chosen = state._chosenHook || fill(HOOKS[hook].lines[0]);
    const script = buildScript(chosen, hook);
    return `
      <div class="page-head">
        <div>
          <h2>Studio</h2>
          <p class="lede">Write the open first. If the first two seconds cannot categorize the video, do not shoot yet.</p>
        </div>
      </div>
      <div class="grid cols-2">
        <div class="card">
          <div class="row r2">
            <div class="field">
              <label>Pillar</label>
              <select id="studio-pillar">
                ${state.profile.pillars.filter(Boolean).map((p) => `<option ${p === pillar ? "selected" : ""}>${escapeHtml(p)}</option>`).join("")}
              </select>
            </div>
            <div class="field">
              <label>Hook type</label>
              <select id="studio-hook">
                ${Object.entries(HOOKS).map(([k, v]) => `<option value="${k}" ${k === hook ? "selected" : ""}>${v.label}</option>`).join("")}
              </select>
            </div>
          </div>
          <div class="list">
            ${HOOKS[hook].lines.map((line) => {
              const text = fill(line);
              return `<div class="hook-card" data-pick-hook="${escapeHtml(text)}">${escapeHtml(text)}</div>`;
            }).join("")}
          </div>
        </div>
        <div class="card">
          <h3>Shoot pack</h3>
          <p class="lede" style="margin-bottom:12px">Selected open: <strong>${escapeHtml(chosen)}</strong></p>
          <div class="script-block">${escapeHtml(script)}</div>
          <div class="actions">
            <button class="btn" id="copy-pack">Copy shoot pack</button>
            <button class="btn ghost" id="save-plan-from-studio">Save to calendar</button>
          </div>
        </div>
      </div>
    `;
  }

  function buildScript(hookLine, hookKey) {
    const p = state.profile;
    const pillar = currentPillar() || "this topic";
    return [
      `HOOK (0-2s)`,
      hookLine,
      `On-screen: ${p.niche || pillar}`,
      ``,
      `CONTEXT (2-10s)`,
      `Name ${p.audience || "the viewer"} and the pain: ${p.pain || "the thing they keep failing"}. No origin story.`,
      ``,
      `PAYLOAD`,
      `One ${pillar} idea that makes ${p.promise || "the outcome"} feel inevitable. Cut every 2-4 seconds.`,
      ``,
      `END`,
      `Save/share reason + rewatch trigger: "Watch it again for the detail on screen."`,
      ``,
      `CAPTION`,
      `${hookLine} Save this if you are ${p.audience || "in this world"}.`,
      ``,
      `HASHTAGS`,
      `#${slug(p.niche)} #${slug(pillar)} #${slug(p.audience)} tips`,
      ``,
      `POST NOTES`,
      `Speak "${p.niche || pillar}" in the first 5 seconds. Label AI if you used it. Reply for 60 minutes.`,
    ].join("\n");
  }

  function slug(value) {
    return String(value || "fyp")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "")
      .slice(0, 18) || "fyp";
  }

  function calendarHTML() {
    if (!state.plan.length) generatePlan();
    return `
      <div class="page-head">
        <div>
          <h2>Calendar</h2>
          <p class="lede">Thirty days of planned shoots. Titles are starting points, not laws. The tracker decides what gets remade.</p>
        </div>
        <button class="btn ghost" id="regen-plan">Regenerate 30 days</button>
      </div>
      <div class="list">
        ${state.plan.map((item) => `
          <div class="item">
            <div>
              <h4>${escapeHtml(item.title)} ${item.done ? '<span class="chip good">shot</span>' : ""}</h4>
              <p>${escapeHtml(item.date)} · ${weekday(item.date)} · ${escapeHtml(item.length)} · ${escapeHtml(HOOKS[item.hook].label)}</p>
              <p>${escapeHtml(item.intent)}</p>
            </div>
            <div class="actions">
              <button class="btn small" data-go="studio" data-pillar="${escapeHtml(item.pillar)}" data-hook="${escapeHtml(item.hook)}">Script</button>
              <button class="btn ghost small" data-complete-plan="${item.id}">${item.done ? "Undo" : "Done"}</button>
            </div>
          </div>
        `).join("")}
      </div>
    `;
  }

  function trackerHTML() {
    const rows = [...state.videos].sort((a, b) => b.date.localeCompare(a.date));
    return `
      <div class="page-head">
        <div>
          <h2>Tracker</h2>
          <p class="lede">Copy numbers from TikTok Analytics. Diagnosis is a compass, not a verdict on you.</p>
        </div>
      </div>
      <div class="card" style="margin-bottom:16px">
        <h3>Log a video</h3>
        <div class="row r3">
          <div class="field"><label>Date</label><input id="v-date" type="date" value="${todayISO()}" /></div>
          <div class="field"><label>Title</label><input id="v-title" placeholder="What you called it" /></div>
          <div class="field"><label>Pillar</label>
            <select id="v-pillar">${state.profile.pillars.filter(Boolean).map((p) => `<option>${escapeHtml(p)}</option>`).join("")}</select>
          </div>
        </div>
        <div class="row r4">
          <div class="field"><label>Hook</label>
            <select id="v-hook">${Object.entries(HOOKS).map(([k, v]) => `<option value="${k}">${v.label}</option>`).join("")}</select>
          </div>
          <div class="field"><label>Length (sec)</label><input id="v-length" type="number" min="1" placeholder="48" /></div>
          <div class="field"><label>Views</label><input id="v-views" type="number" min="0" /></div>
          <div class="field"><label>Completion %</label><input id="v-completion" type="number" min="0" max="100" /></div>
        </div>
        <div class="row r4">
          <div class="field"><label>Saves</label><input id="v-saves" type="number" min="0" /></div>
          <div class="field"><label>Shares</label><input id="v-shares" type="number" min="0" /></div>
          <div class="field"><label>Comments</label><input id="v-comments" type="number" min="0" /></div>
          <div class="field"><label>Follows from video</label><input id="v-follows" type="number" min="0" /></div>
        </div>
        <div class="field"><label>Drop-off note</label><input id="v-notes" placeholder="Cliff at 3s? Slope the whole way?" /></div>
        <button class="btn" id="add-video">Save to scorecard</button>
      </div>
      ${rows.length ? `
        <div class="card table-wrap">
          <table>
            <thead>
              <tr><th>Date</th><th>Video</th><th>Views</th><th>Done</th><th>S/S</th><th>Read</th><th></th></tr>
            </thead>
            <tbody>
              ${rows.map((v) => {
                const d = diagnose(v);
                return `<tr>
                  <td class="mono">${escapeHtml(v.date)}</td>
                  <td><strong>${escapeHtml(v.title)}</strong><br /><span style="color:var(--muted)">${escapeHtml(v.pillar)} · ${escapeHtml(HOOKS[v.hook]?.label || v.hook)}</span></td>
                  <td class="mono">${escapeHtml(v.views || 0)}</td>
                  <td class="mono">${escapeHtml(v.completion || 0)}%</td>
                  <td class="mono">${escapeHtml(v.saves || 0)}/${escapeHtml(v.shares || 0)}</td>
                  <td><span class="chip ${d.tone}">${escapeHtml(d.text)}</span></td>
                  <td><button class="btn ghost small" data-del-video="${v.id}">Remove</button></td>
                </tr>`;
              }).join("")}
            </tbody>
          </table>
        </div>
      ` : `<div class="empty">No videos yet. Post one, wait a day, then log it.</div>`}
    `;
  }

  function reviewHTML() {
    const videos = state.videos;
    if (!videos.length) {
      return `<div class="page-head"><div><h2>Review</h2><p class="lede">Log at least a handful of videos. The weekly decision is: remake, rewrite, or retire.</p></div></div><div class="empty">Nothing to review yet.</div>`;
    }
    const best = (key) => {
      const map = {};
      videos.forEach((v) => {
        const k = v[key] || "unknown";
        if (!map[k]) map[k] = { n: 0, c: 0, saves: 0, views: 0 };
        map[k].n += 1;
        map[k].c += Number(v.completion || 0);
        map[k].saves += Number(v.saves || 0);
        map[k].views += Number(v.views || 0);
      });
      return Object.entries(map)
        .map(([name, s]) => ({ name, avgC: Math.round(s.c / s.n), saves: s.saves, views: s.views, n: s.n }))
        .sort((a, b) => b.avgC - a.avgC || b.saves - a.saves)[0];
    };
    const pillar = best("pillar");
    const hook = best("hook");
    const sorted = [...videos].sort((a, b) => Number(b.completion || 0) - Number(a.completion || 0));
    const winner = sorted[0];
    const loser = sorted[sorted.length - 1];
    return `
      <div class="page-head">
        <div>
          <h2>Review</h2>
          <p class="lede">Every seven days, make one decision. The rest is noise.</p>
        </div>
      </div>
      <div class="grid cols-3">
        <div class="card"><h3>Winning pillar</h3><p class="mono" style="font-size:22px">${escapeHtml(pillar.name)}</p><p>${pillar.avgC}% avg completion · ${pillar.n} videos</p></div>
        <div class="card"><h3>Winning hook</h3><p class="mono" style="font-size:22px">${escapeHtml(HOOKS[hook.name]?.label || hook.name)}</p><p>${hook.avgC}% avg completion</p></div>
        <div class="card"><h3>Next 4 videos</h3><p>Remake <strong>${escapeHtml(pillar.name)}</strong> with a <strong>${escapeHtml(HOOKS[hook.name]?.label || hook.name)}</strong> open. Same visual world. New example each time.</p></div>
      </div>
      <div class="grid cols-2" style="margin-top:16px">
        <div class="card">
          <h3>Keep</h3>
          <p><strong>${escapeHtml(winner.title)}</strong></p>
          <p>${escapeHtml(winner.completion || 0)}% completion · ${escapeHtml(winner.saves || 0)} saves</p>
          <p class="lede">This is your template. Change the example, not the skeleton.</p>
        </div>
        <div class="card">
          <h3>Rewrite or retire</h3>
          <p><strong>${escapeHtml(loser.title)}</strong></p>
          <p>${escapeHtml(loser.completion || 0)}% completion</p>
          <p class="lede">${escapeHtml(diagnose(loser).text)}</p>
        </div>
      </div>
    `;
  }

  function playbookHTML() {
    return `
      <div class="page-head">
        <div>
          <h2>Playbook</h2>
          <p class="lede">The short version. The full manual lives in docs/PLAYBOOK.md.</p>
        </div>
      </div>
      <div class="play-section">
        <h3>Distribution</h3>
        <p>New videos are tested on your followers first. If they skip, you do not get the For You page. Buy-follower tactics fail this gate on purpose. Completion, rewatches, saves, and shares matter more than likes.</p>
      </div>
      <div class="play-section">
        <h3>New account</h3>
        <ul>
          <li>One viewer. One promise. Three pillars.</li>
          <li>3–5 original videos a week. No watermarked reposts.</li>
          <li>Keyword on screen, in speech, and in the caption.</li>
          <li>Some 200-view deaths are cold start. Judge weeks, not posts.</li>
        </ul>
      </div>
      <div class="play-section">
        <h3>First 30 days</h3>
        <ul>
          <li>Days 1–3: setup, 12 hooks, first proof-drop video.</li>
          <li>Days 4–10: one video per pillar. Log drop-off.</li>
          <li>Days 11–20: remake the winning pair. Start a series if saves are high.</li>
          <li>Days 21–30: kill the bottom pillar or hook. Write the next 12 titles from the winner.</li>
        </ul>
      </div>
      <div class="play-section">
        <h3>Do not</h3>
        <p>Bots, pods, follow-unfollow, mass comments, or buying views. They collect the wrong audience and can restrict the account. This tool will not do those things.</p>
      </div>
    `;
  }

  function settingsHTML() {
    const p = state.profile;
    return `
      <div class="page-head">
        <div>
          <h2>Settings</h2>
          <p class="lede">Tighten the niche until a stranger can predict your next video.</p>
        </div>
      </div>
      ${settingsForm(p, false)}
      <div class="actions" style="margin-top:18px">
        <button class="btn" id="save-settings">Save profile</button>
        <button class="btn ghost" id="export-data">Export backup</button>
        <button class="btn ghost" id="import-data">Import backup</button>
        <input id="import-file" type="file" accept="application/json" hidden />
      </div>
    `;
  }

  function settingsForm(p, onboard) {
    return `
      <div class="card">
        <div class="row r2">
          <div class="field"><label>Handle</label><input id="p-handle" value="${escapeHtml(p.handle)}" placeholder="@yourname" /></div>
          <div class="field"><label>Start date</label><input id="p-start" type="date" value="${escapeHtml(p.startedOn || todayISO())}" /></div>
        </div>
        <div class="field"><label>Niche (searchable category)</label><input id="p-niche" value="${escapeHtml(p.niche)}" placeholder="Weeknight cooking for tired parents" /></div>
        <div class="row r2">
          <div class="field"><label>Viewer</label><input id="p-audience" value="${escapeHtml(p.audience)}" placeholder="People who hate meal prep" /></div>
          <div class="field"><label>Promise</label><input id="p-promise" value="${escapeHtml(p.promise)}" placeholder="Dinner in 20 minutes from a normal grocery run" /></div>
        </div>
        <div class="field"><label>Main pain</label><input id="p-pain" value="${escapeHtml(p.pain)}" placeholder="They waste food and order takeout" /></div>
        <div class="row r3">
          <div class="field"><label>Pillar 1</label><input id="p-p1" value="${escapeHtml(p.pillars[0] || "")}" placeholder="15-minute dinners" /></div>
          <div class="field"><label>Pillar 2</label><input id="p-p2" value="${escapeHtml(p.pillars[1] || "")}" placeholder="Grocery-order mistakes" /></div>
          <div class="field"><label>Pillar 3</label><input id="p-p3" value="${escapeHtml(p.pillars[2] || "")}" placeholder="Save-this sauces" /></div>
        </div>
        <div class="field" style="max-width:220px">
          <label>Videos per week</label>
          <select id="p-cadence">
            ${[3, 4, 5].map((n) => `<option value="${n}" ${Number(p.cadence) === n ? "selected" : ""}>${n}</option>`).join("")}
          </select>
        </div>
        ${onboard ? `<div class="actions"><button class="btn" id="finish-setup">Create my 30-day system</button></div>` : ""}
      </div>
    `;
  }

  function onboardHTML() {
    return `
      <div class="onboard">
        <div class="onboard-card">
          <div class="brand-kicker">RagnaOne</div>
          <h2>Grow the account. Do not cosplay a growth hacker.</h2>
          <p class="lede">Five minutes of setup. Then a 30-day plan, a script studio, and a scorecard. No bots. No fake views. You still have to film.</p>
          <div class="banner">A new account wins by becoming easy to categorize. Write a niche a stranger could search.</div>
          ${settingsForm(state.profile, true)}
        </div>
      </div>
    `;
  }

  function readProfileFromForm() {
    return {
      handle: val("p-handle"),
      niche: val("p-niche"),
      audience: val("p-audience"),
      promise: val("p-promise"),
      pain: val("p-pain"),
      pillars: [val("p-p1"), val("p-p2"), val("p-p3")],
      cadence: Number(val("p-cadence") || 4),
      startedOn: val("p-start") || todayISO(),
    };
  }

  function val(id) {
    const el = document.getElementById(id);
    return el ? el.value.trim() : "";
  }

  function bindOnboard() {
    document.getElementById("finish-setup")?.addEventListener("click", () => {
      state.profile = readProfileFromForm();
      if (!profileReady()) {
        alert("Fill niche, viewer, promise, and at least two pillars.");
        return;
      }
      generatePlan();
      state.setupComplete = true;
      state.view = "today";
      save();
      render();
    });
  }

  function bindShell() {
    document.querySelectorAll("[data-view]").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.view = btn.getAttribute("data-view");
        save();
        render();
      });
    });
    document.querySelectorAll("[data-go]").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.view = btn.getAttribute("data-go");
        if (btn.dataset.pillar) state._studioPillar = btn.dataset.pillar;
        if (btn.dataset.hook) state._studioHook = btn.dataset.hook;
        save();
        render();
      });
    });
    document.querySelectorAll("[data-check]").forEach((box) => {
      box.addEventListener("change", () => {
        const checks = checksFor(todayISO());
        checks[box.dataset.check] = box.checked;
        save();
      });
    });
    document.querySelectorAll("[data-complete-plan]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const item = state.plan.find((p) => p.id === btn.dataset.completePlan);
        if (item) item.done = !item.done;
        save();
        render();
      });
    });
    document.getElementById("studio-pillar")?.addEventListener("change", (e) => {
      state._studioPillar = e.target.value;
      render();
    });
    document.getElementById("studio-hook")?.addEventListener("change", (e) => {
      state._studioHook = e.target.value;
      state._chosenHook = "";
      render();
    });
    document.querySelectorAll("[data-pick-hook]").forEach((el) => {
      el.addEventListener("click", () => {
        state._chosenHook = el.dataset.pickHook;
        render();
      });
    });
    document.getElementById("copy-pack")?.addEventListener("click", async () => {
      const hook = state._studioHook || "proof";
      const chosen = state._chosenHook || fill(HOOKS[hook].lines[0]);
      await navigator.clipboard.writeText(buildScript(chosen, hook));
      const btn = document.getElementById("copy-pack");
      if (btn) btn.textContent = "Copied";
    });
    document.getElementById("save-plan-from-studio")?.addEventListener("click", () => {
      const hook = state._studioHook || "proof";
      const chosen = state._chosenHook || fill(HOOKS[hook].lines[0]);
      state.plan.unshift({
        id: uid(),
        date: todayISO(),
        title: chosen.slice(0, 72),
        pillar: currentPillar(),
        hook,
        length: "45-90s",
        intent: "From Studio",
        done: false,
      });
      state.view = "calendar";
      save();
      render();
    });
    document.getElementById("regen-plan")?.addEventListener("click", () => {
      generatePlan();
      save();
      render();
    });
    document.getElementById("add-video")?.addEventListener("click", () => {
      const title = val("v-title");
      if (!title) {
        alert("Give the video a title so Review can compare it.");
        return;
      }
      state.videos.push({
        id: uid(),
        date: val("v-date") || todayISO(),
        title,
        pillar: val("v-pillar"),
        hook: val("v-hook"),
        length: val("v-length"),
        views: val("v-views"),
        completion: val("v-completion"),
        saves: val("v-saves"),
        shares: val("v-shares"),
        comments: val("v-comments"),
        follows: val("v-follows"),
        notes: val("v-notes"),
      });
      save();
      render();
    });
    document.querySelectorAll("[data-del-video]").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.videos = state.videos.filter((v) => v.id !== btn.dataset.delVideo);
        save();
        render();
      });
    });
    document.getElementById("save-settings")?.addEventListener("click", () => {
      state.profile = readProfileFromForm();
      if (!state.plan.length) generatePlan();
      save();
      render();
    });
    document.getElementById("export-data")?.addEventListener("click", () => {
      const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "ragnaone-tiktok-backup.json";
      a.click();
    });
    document.getElementById("import-data")?.addEventListener("click", () => {
      document.getElementById("import-file")?.click();
    });
    document.getElementById("import-file")?.addEventListener("change", async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        const parsed = JSON.parse(await file.text());
        state = { ...defaultState(), ...parsed, setupComplete: true };
        save();
        render();
      } catch {
        alert("Could not read that backup.");
      }
    });
  }

  render();
})();

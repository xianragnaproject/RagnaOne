const giftDefaults = [
  { coins: 1, label: "25 Heal", giftName: "Rose" },
  { coins: 10, label: "Stick", giftName: "GG" },
  { coins: 50, label: "255 Heal", giftName: "Doughnut" },
  { coins: 100, label: "325 Heal", giftName: "Corgi" },
  { coins: 1000, label: "1K Heal", giftName: "Lion" },
];

const els = {
  tiktokUser: document.getElementById("tiktokUser"),
  btnConnect: document.getElementById("btnConnect"),
  btnDisconnect: document.getElementById("btnDisconnect"),
  tiktokStatus: document.getElementById("tiktokStatus"),
  joinName: document.getElementById("joinName"),
  btnJoin: document.getElementById("btnJoin"),
  giftButtons: document.getElementById("giftButtons"),
  btnDemoOn: document.getElementById("btnDemoOn"),
  btnDemoOff: document.getElementById("btnDemoOff"),
  btnReset: document.getElementById("btnReset"),
  controlFeed: document.getElementById("controlFeed"),
  overlayUrl: document.getElementById("overlayUrl"),
};

els.overlayUrl.textContent = `${location.origin}/`;

els.giftButtons.innerHTML = giftDefaults
  .map(
    (g) =>
      `<button class="btn" data-coins="${g.coins}" data-gift="${g.giftName}">${g.coins}¢ · ${g.label}</button>`
  )
  .join("");

function pushFeed(text, cls = "") {
  const div = document.createElement("div");
  div.className = `event-item ${cls}`;
  div.textContent = text;
  els.controlFeed.prepend(div);
  while (els.controlFeed.children.length > 30) {
    els.controlFeed.lastChild.remove();
  }
}

async function post(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {}),
  });
  return res.json();
}

els.btnConnect.addEventListener("click", async () => {
  const username = els.tiktokUser.value.trim().replace(/^@/, "");
  if (!username) {
    els.tiktokStatus.textContent = "Enter a TikTok username first";
    return;
  }
  els.tiktokStatus.textContent = `Connecting to @${username}…`;
  const result = await post("/api/connect", { username });
  if (result.ok) {
    els.tiktokStatus.textContent = `Connected to @${username}`;
  } else {
    els.tiktokStatus.textContent = `Failed: ${result.error || result.reason || "unknown"}`;
  }
});

els.btnDisconnect.addEventListener("click", async () => {
  await post("/api/disconnect");
  els.tiktokStatus.textContent = "Disconnected — demo mode available";
});

els.btnJoin.addEventListener("click", async () => {
  const name = els.joinName.value.trim() || "Challenger";
  await post("/api/demo/join", { name });
  pushFeed(`${name} queued`, "join");
});

els.giftButtons.addEventListener("click", async (e) => {
  const btn = e.target.closest("button[data-coins]");
  if (!btn) return;
  const coins = Number(btn.dataset.coins);
  const giftName = btn.dataset.gift;
  const name = els.joinName.value.trim() || "Viewer";
  await post("/api/demo/gift", { name, coins, giftName });
  pushFeed(`${name} sent ${giftName} (${coins}¢)`, "gift");
});

els.btnDemoOn.addEventListener("click", () => post("/api/demo/start"));
els.btnDemoOff.addEventListener("click", () => post("/api/demo/stop"));
els.btnReset.addEventListener("click", () => post("/api/reset"));

const socket = io();
let seeded = false;

socket.on("state", (state) => {
  if (seeded) return;
  seeded = true;
  for (const evt of [...(state.events || [])].reverse()) {
    pushFeed(
      evt.message || evt.type,
      evt.type === "gift" || evt.type === "effect"
        ? "gift"
        : evt.type === "join"
          ? "join"
          : ""
    );
  }
});

socket.on("tiktok", (s) => {
  if (s.connected) {
    els.tiktokStatus.textContent = `LIVE @${s.username} · room ${s.roomId || "?"}`;
    els.tiktokUser.value = s.username || els.tiktokUser.value;
  } else {
    els.tiktokStatus.textContent = `Not connected (${s.reason || "idle"}) — use demo controls`;
  }
});

socket.on("event", (evt) => {
  pushFeed(evt.message || evt.type, evt.type === "gift" ? "gift" : evt.type === "join" ? "join" : "");
});

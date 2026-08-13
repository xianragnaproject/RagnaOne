import { ArenaRenderer } from "./renderer.js";

const canvas = document.getElementById("arena");
const renderer = new ArenaRenderer(canvas);
renderer.start();

const els = {
  nextMatch: document.getElementById("nextMatch"),
  statusPill: document.getElementById("statusPill"),
  giftList: document.getElementById("giftList"),
  nameLeft: document.getElementById("nameLeft"),
  nameRight: document.getElementById("nameRight"),
  hpLeft: document.getElementById("hpLeft"),
  hpRight: document.getElementById("hpRight"),
  metaLeft: document.getElementById("metaLeft"),
  metaRight: document.getElementById("metaRight"),
  queueRail: document.getElementById("queueRail"),
  eventFeed: document.getElementById("eventFeed"),
  toast: document.getElementById("toast"),
};

let lastMatchId = 0;
let giftMapRendered = false;

function setHp(el, fighter, side) {
  if (!fighter) {
    el.style.transform = "scaleX(0)";
    return;
  }
  const pct = Math.max(0, Math.min(1, fighter.hp / fighter.maxHp));
  el.style.transform = side === "right" ? `scaleX(${pct})` : `scaleX(${pct})`;
}

function renderGiftBoard(map) {
  if (!map?.length) return;
  els.giftList.innerHTML = map
    .map(
      (g) => `
      <div class="gift-row">
        <div class="gift-coins">${g.coins}¢</div>
        <div class="gift-label">${g.icon || ""} ${g.label}</div>
      </div>`
    )
    .join("");
  giftMapRendered = true;
}

function showToast(text) {
  els.toast.hidden = false;
  els.toast.textContent = text;
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => {
    els.toast.hidden = true;
  }, 2200);
}

function renderState(state) {
  renderer.setState(state);
  els.nextMatch.textContent = state.nextMatchLabel || "";

  const tiktok = state.tiktok || {};
  if (tiktok.connected) {
    els.statusPill.textContent = `LIVE @${tiktok.username || ""}`;
  } else {
    els.statusPill.textContent = "DEMO";
  }

  if (!giftMapRendered && state.giftMap) renderGiftBoard(state.giftMap);

  const left = state.challenger;
  const right = state.champion;

  els.nameLeft.textContent = left?.name || "WAITING";
  els.nameRight.textContent = right?.name || "HOUSE";
  setHp(els.hpLeft, left, "left");
  setHp(els.hpRight, right, "right");
  els.metaLeft.textContent = left
    ? `${Math.round(left.hp)} HP${left.weapon ? ` · ${left.weapon}` : ""}`
    : "Type JOIN";
  els.metaRight.textContent = right
    ? `${right.wins} wins · ${Math.round(right.hp)} HP${right.weapon ? ` · ${right.weapon}` : ""}`
    : "";

  els.queueRail.innerHTML = (state.queue || [])
    .map((q, i) => `<div class="queue-chip">#${i + 1} ${escapeHtml(q.name)}</div>`)
    .join("");

  els.eventFeed.innerHTML = (state.events || [])
    .slice(0, 6)
    .map((e) => {
      const cls = e.type === "gift" || e.type === "effect" ? "gift" : e.type === "join" ? "join" : "";
      return `<div class="event-item ${cls}">${escapeHtml(formatEvent(e))}</div>`;
    })
    .join("");

  if (state.matchId && state.matchId !== lastMatchId) {
    lastMatchId = state.matchId;
    if (state.phase === "fighting") {
      showToast("FIGHT!");
      renderer.celebrate("gift");
    }
  }
}

function formatEvent(e) {
  if (e.type === "gift") return e.message;
  if (e.type === "join") return e.message;
  if (e.type === "match_start") return e.message;
  if (e.type === "match_end") return e.message;
  if (e.type === "effect") return e.message;
  if (e.type === "chat") return `${e.user}: ${e.message}`;
  return e.message || e.type;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

const socket = io();

socket.on("state", (state) => renderState(state));

socket.on("event", (evt) => {
  if (evt.type === "match_end") {
    showToast(`${(evt.winner || "WINNER").toUpperCase()} WINS`);
    renderer.celebrate("win");
  }
  if (evt.type === "effect" && /HP/.test(evt.message || "")) {
    renderer.celebrate("heal");
  }
  if (evt.type === "gift") {
    renderer.celebrate("gift");
  }
  if (evt.type === "join") {
    showToast(`${evt.user} JOINED`);
  }
});

socket.on("tiktok", (status) => {
  if (status.connected) {
    els.statusPill.textContent = `LIVE @${status.username || ""}`;
  } else {
    els.statusPill.textContent = "DEMO";
  }
});

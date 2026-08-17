export function createUI() {
  const killList = document.getElementById("kill-list");
  const timerEl = document.getElementById("timer");
  const phaseEl = document.getElementById("phase");
  const toastEl = document.getElementById("toast");
  const statusEl = document.getElementById("connection-status");
  let toastTimer = null;

  return {
    setLeaderboard(entries) {
      killList.innerHTML = entries
        .map(
          (e, i) =>
            `<li><span class="name">${i + 1}. ${escapeHtml(e.name)}</span><span class="score">${e.score}</span></li>`
        )
        .join("");
    },

    setTimer(text) {
      timerEl.textContent = text;
    },

    setPhase(phase) {
      const isGreen = phase === "green";
      phaseEl.textContent = isGreen ? "GREEN LIGHT" : "RED LIGHT";
      phaseEl.classList.toggle("green", isGreen);
      phaseEl.classList.toggle("red", !isGreen);
      timerEl.classList.toggle("green", isGreen);
      timerEl.classList.toggle("red", !isGreen);
    },

    toast(message) {
      toastEl.textContent = message;
      toastEl.classList.remove("hidden");
      clearTimeout(toastTimer);
      toastTimer = setTimeout(() => toastEl.classList.add("hidden"), 2200);
    },

    setStatus(text, isError = false) {
      statusEl.textContent = text;
      statusEl.style.color = isError ? "#ff8a95" : "rgba(244, 239, 230, 0.75)";
    },
  };
}

function escapeHtml(str) {
  return String(str)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function createNet(onEvent) {
  const proto = location.protocol === "https:" ? "wss" : "ws";
  let ws;
  let retries = 0;

  function connect() {
    ws = new WebSocket(`${proto}://${location.host}`);
    ws.addEventListener("open", () => {
      retries = 0;
      onEvent({ type: "socket", status: "open" });
    });
    ws.addEventListener("message", (ev) => {
      try {
        onEvent(JSON.parse(ev.data));
      } catch {
        /* ignore */
      }
    });
    ws.addEventListener("close", () => {
      onEvent({ type: "socket", status: "closed" });
      const wait = Math.min(8000, 500 * 2 ** retries);
      retries += 1;
      setTimeout(connect, wait);
    });
  }

  connect();

  return {
    send(payload) {
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(payload));
      }
    },
  };
}

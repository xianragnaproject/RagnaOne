import { Game } from "./game.js";
import { createUI, createNet } from "./ui.js";

const canvas = document.getElementById("game");
const ui = createUI();
const game = new Game(canvas, ui);

const usernameInput = document.getElementById("username");
const btnConnect = document.getElementById("btn-connect");
const btnDisconnect = document.getElementById("btn-disconnect");
const btnRound = document.getElementById("btn-round");
const btnHide = document.getElementById("btn-hide");
const panel = document.getElementById("control-panel");

const demoNames = [
  "Nova",
  "Kai",
  "Mira",
  "Jett",
  "Yuki",
  "Rex",
  "Luna",
  "Ash",
  "Zo",
  "Vin",
];

function randomDemoName() {
  return demoNames[Math.floor(Math.random() * demoNames.length)] + Math.floor(Math.random() * 90);
}

const net = createNet((msg) => {
  if (msg.type === "gift") {
    game.handleGift(msg);
    return;
  }
  if (msg.type === "giftUnknown") {
    ui.toast(`Unmapped gift: ${msg.giftName || msg.giftId}`);
    return;
  }
  if (msg.type === "status") {
    if (msg.status === "connected") {
      ui.setStatus(`Connected to @${msg.username}`);
      btnConnect.disabled = true;
      btnDisconnect.disabled = false;
    } else if (msg.status === "disconnected" || msg.status === "idle") {
      ui.setStatus(msg.status === "idle" ? "Idle — use Demo gifts to test" : "Disconnected");
      btnConnect.disabled = false;
      btnDisconnect.disabled = true;
    } else if (msg.status === "error") {
      ui.setStatus(msg.message || "Connection error", true);
      btnConnect.disabled = false;
      btnDisconnect.disabled = true;
    }
  }
});

btnConnect.addEventListener("click", () => {
  const username = usernameInput.value.trim().replace(/^@/, "");
  if (!username) {
    ui.setStatus("Enter your TikTok username", true);
    return;
  }
  ui.setStatus(`Connecting to @${username}…`);
  net.send({ type: "connect", username });
});

btnDisconnect.addEventListener("click", () => {
  net.send({ type: "disconnect" });
});

btnRound.addEventListener("click", () => game.resetRound());

btnHide.addEventListener("click", () => {
  panel.classList.toggle("hidden");
});

document.addEventListener("keydown", (e) => {
  if (e.key === "h" || e.key === "H") panel.classList.toggle("hidden");
});

document.querySelectorAll("[data-demo]").forEach((btn) => {
  btn.addEventListener("click", () => {
    const action = btn.getAttribute("data-demo");
    const username = randomDemoName();
    net.send({
      type: "simulate",
      action,
      username,
      nickname: username,
    });
  });
});

document.querySelectorAll("#gift-bar .gift-item").forEach((el) => {
  el.style.pointerEvents = "auto";
  el.style.cursor = "pointer";
  el.addEventListener("click", () => {
    const action = el.getAttribute("data-action");
    const username = randomDemoName();
    net.send({ type: "simulate", action, username, nickname: username });
  });
});

// Seed a few players so the arena looks alive on first load
for (let i = 0; i < 8; i++) {
  game.spawnPlayer(randomDemoName(), 1);
}
ui.toast("Demo ready — connect TikTok or click gifts");

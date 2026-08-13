import express from "express";
import cors from "cors";
import http from "http";
import path from "path";
import { fileURLToPath } from "url";
import { Server } from "socket.io";
import { GameEngine } from "./game/GameEngine.js";
import { TikTokBridge } from "./tiktok/connector.js";
import { DemoSimulator } from "./tiktok/demo.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const PORT = Number(process.env.PORT) || 3000;
const TIKTOK_USERNAME = (process.env.TIKTOK_USERNAME || "").replace(/^@/, "");
const DEMO_MODE = String(process.env.DEMO_MODE ?? "true").toLowerCase() !== "false";

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(ROOT, "public")));

let tiktokStatus = {
  connected: false,
  username: TIKTOK_USERNAME || null,
  reason: TIKTOK_USERNAME ? "starting" : "demo_only",
};

const engine = new GameEngine({
  onState: (state) => {
    io.emit("state", { ...state, tiktok: tiktokStatus });
  },
  onEvent: (evt) => {
    io.emit("event", evt);
  },
});
engine.startLoop();

const demo = new DemoSimulator(engine);
let bridge = null;

async function connectTikTok(username) {
  if (!username) return { ok: false, reason: "no_username" };
  bridge = new TikTokBridge({
    username,
    onChat: (e) => engine.handleChat(e),
    onGift: (e) => engine.handleGift(e),
    onLike: (e) => engine.handleLike(e),
    onStatus: (s) => {
      tiktokStatus = { ...s, username };
      io.emit("tiktok", tiktokStatus);
      engine.broadcastSoon();
      if (s.connected) {
        demo.stop();
      } else if (DEMO_MODE) {
        demo.start();
      }
    },
  });
  return bridge.connect();
}

if (TIKTOK_USERNAME) {
  connectTikTok(TIKTOK_USERNAME).then((res) => {
    if (!res.ok && DEMO_MODE) demo.start();
  });
} else if (DEMO_MODE) {
  demo.start();
}

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, tiktok: tiktokStatus, demo: demo.running });
});

app.get("/api/state", (_req, res) => {
  res.json({ ...engine.getState(), tiktok: tiktokStatus, demo: demo.running });
});

app.post("/api/connect", async (req, res) => {
  const username = String(req.body?.username || "").replace(/^@/, "").trim();
  if (!username) {
    res.status(400).json({ ok: false, error: "username required" });
    return;
  }
  demo.stop();
  const result = await connectTikTok(username);
  res.json(result);
});

app.post("/api/disconnect", async (_req, res) => {
  if (bridge) await bridge.disconnect();
  tiktokStatus = { connected: false, username: null, reason: "manual_disconnect" };
  io.emit("tiktok", tiktokStatus);
  if (DEMO_MODE) demo.start();
  res.json({ ok: true });
});

app.post("/api/demo/start", (_req, res) => {
  demo.start();
  res.json({ ok: true, running: true });
});

app.post("/api/demo/stop", (_req, res) => {
  demo.stop();
  res.json({ ok: true, running: false });
});

app.post("/api/demo/join", (req, res) => {
  const name = String(req.body?.name || `Fighter${Math.floor(Math.random() * 999)}`);
  engine.simulateJoin(name, "manual");
  res.json({ ok: true });
});

app.post("/api/demo/gift", (req, res) => {
  const name = String(req.body?.name || engine.challenger?.name || "Viewer");
  const coins = Number(req.body?.coins) || 1;
  const giftName = String(req.body?.giftName || "Gift");
  engine.simulateGift(name, coins, giftName);
  res.json({ ok: true });
});

app.post("/api/reset", (_req, res) => {
  engine.resetChampion("HOUSE");
  res.json({ ok: true });
});

io.on("connection", (socket) => {
  socket.emit("state", { ...engine.getState(), tiktok: tiktokStatus });
  socket.emit("tiktok", tiktokStatus);

  socket.on("control:join", (payload) => {
    const name = String(payload?.name || "Guest");
    engine.simulateJoin(name, "overlay");
  });

  socket.on("control:gift", (payload) => {
    const name = String(payload?.name || engine.challenger?.name || "Viewer");
    const coins = Number(payload?.coins) || 1;
    engine.simulateGift(name, coins, payload?.giftName || "Gift");
  });

  socket.on("control:reset", () => engine.resetChampion("HOUSE"));
});

server.listen(PORT, () => {
  console.log(`\n🥊 TikTok Wrestle Gift Game`);
  console.log(`   Overlay:  http://localhost:${PORT}`);
  console.log(`   Control:  http://localhost:${PORT}/control.html`);
  console.log(`   TikTok:   ${TIKTOK_USERNAME || "(demo mode — set TIKTOK_USERNAME)"}\n`);
});

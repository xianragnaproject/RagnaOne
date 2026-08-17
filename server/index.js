import express from "express";
import http from "http";
import path from "path";
import { fileURLToPath } from "url";
import { WebSocketServer } from "ws";
import {
  TikTokLiveConnection,
  WebcastEvent,
  ControlEvent,
} from "tiktok-live-connector";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 3000;

const GIFT_ACTIONS = {
  rose: "join",
  roses: "join",
  weight: "kill1",
  weights: "kill1",
  dumbbell: "kill1",
  turbo: "kill1",
  gg: "clones",
  "finger heart": "clones",
  "heart me": "clones",
  "perf heart": "clones",
  "corgi": "clones",
  "clap": "kills5",
  "hand clap": "kills5",
  "applause": "kills5",
  "thumbs up": "kills5",
  snail: "kills15",
  donut: "killAll",
  doughnut: "killAll",
  universe: "killAll",
  lion: "killAll",
};

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

app.use(express.json());
app.use(express.static(path.join(__dirname, "../public")));

/** @type {import('tiktok-live-connector').TikTokLiveConnection | null} */
let tiktok = null;
let connectedUsername = null;

function broadcast(payload) {
  const msg = JSON.stringify(payload);
  for (const client of wss.clients) {
    if (client.readyState === 1) client.send(msg);
  }
}

function normalizeGiftName(name = "") {
  return String(name).trim().toLowerCase();
}

function resolveAction(giftName, giftId) {
  const key = normalizeGiftName(giftName);
  if (GIFT_ACTIONS[key]) return GIFT_ACTIONS[key];

  // Common TikTok gift IDs (best-effort fallbacks)
  const byId = {
    5655: "join", // Rose
    5269: "join",
    6064: "kill1",
    5658: "clones",
    5487: "kills5",
    8913: "kills15",
    5879: "killAll",
  };
  return byId[giftId] || null;
}

function emitGiftAction({ username, nickname, giftName, giftId, repeatCount = 1, action }) {
  broadcast({
    type: "gift",
    action,
    username: username || nickname || "viewer",
    nickname: nickname || username || "viewer",
    giftName: giftName || "Gift",
    giftId,
    repeatCount,
    at: Date.now(),
  });
}

function attachTikTokHandlers(connection) {
  connection.on(WebcastEvent.GIFT, (data) => {
    const giftType = data.giftDetails?.giftType ?? data.giftType;
    const giftName = data.giftDetails?.giftName || data.extendedGiftInfo?.name || data.giftName;
    const giftId = data.giftId;
    const repeatCount = data.repeatCount || 1;
    const uniqueId = data.user?.uniqueId || data.uniqueId;
    const nickname = data.user?.nickname || data.nickname || uniqueId;

    // Streakable gifts fire many times; only act when the streak ends
    if (giftType === 1 && !data.repeatEnd) return;

    const action = resolveAction(giftName, giftId);
    if (!action) {
      broadcast({
        type: "giftUnknown",
        username: uniqueId,
        nickname,
        giftName,
        giftId,
        repeatCount,
      });
      return;
    }

    emitGiftAction({
      username: uniqueId,
      nickname,
      giftName,
      giftId,
      repeatCount,
      action,
    });
  });

  connection.on(WebcastEvent.CHAT, (data) => {
    const comment = (data.comment || "").trim().toLowerCase();
    const username = data.user?.uniqueId || data.uniqueId;
    const nickname = data.user?.nickname || data.nickname || username;
    if (comment === "!join" || comment === "join") {
      emitGiftAction({
        username,
        nickname,
        giftName: "Chat Join",
        action: "join",
        repeatCount: 1,
      });
    }
  });

  connection.on(ControlEvent.DISCONNECTED, () => {
    broadcast({ type: "status", status: "disconnected", username: connectedUsername });
  });

  connection.on(ControlEvent.ERROR, (err) => {
    broadcast({
      type: "status",
      status: "error",
      message: err?.message || String(err),
      username: connectedUsername,
    });
  });
}

async function connectTikTok(username) {
  const clean = String(username || "").replace(/^@/, "").trim();
  if (!clean) throw new Error("Username required");

  if (tiktok) {
    try {
      await tiktok.disconnect();
    } catch {
      /* ignore */
    }
    tiktok = null;
  }

  connectedUsername = clean;
  tiktok = new TikTokLiveConnection(clean, {
    processInitialData: false,
    enableExtendedGiftInfo: true,
  });
  attachTikTokHandlers(tiktok);

  const state = await tiktok.connect();
  broadcast({
    type: "status",
    status: "connected",
    username: clean,
    roomId: state?.roomId,
  });
  return { username: clean, roomId: state?.roomId };
}

async function disconnectTikTok() {
  if (!tiktok) return;
  try {
    await tiktok.disconnect();
  } catch {
    /* ignore */
  }
  tiktok = null;
  const prev = connectedUsername;
  connectedUsername = null;
  broadcast({ type: "status", status: "disconnected", username: prev });
}

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    connected: Boolean(tiktok),
    username: connectedUsername,
  });
});

app.post("/api/connect", async (req, res) => {
  try {
    const result = await connectTikTok(req.body?.username);
    res.json({ ok: true, ...result });
  } catch (err) {
    res.status(400).json({ ok: false, error: err?.message || String(err) });
  }
});

app.post("/api/disconnect", async (_req, res) => {
  await disconnectTikTok();
  res.json({ ok: true });
});

app.post("/api/simulate", (req, res) => {
  const { action, username, nickname, giftName, repeatCount } = req.body || {};
  const allowed = new Set(["join", "kill1", "clones", "kills5", "kills15", "killAll"]);
  if (!allowed.has(action)) {
    return res.status(400).json({ ok: false, error: "Invalid action" });
  }
  emitGiftAction({
    action,
    username: username || "DemoUser",
    nickname: nickname || username || "DemoUser",
    giftName: giftName || "Simulated",
    repeatCount: repeatCount || 1,
  });
  res.json({ ok: true });
});

wss.on("connection", (socket) => {
  socket.send(
    JSON.stringify({
      type: "status",
      status: tiktok ? "connected" : "idle",
      username: connectedUsername,
    })
  );

  socket.on("message", async (raw) => {
    let msg;
    try {
      msg = JSON.parse(String(raw));
    } catch {
      return;
    }

    if (msg.type === "connect") {
      try {
        await connectTikTok(msg.username);
      } catch (err) {
        socket.send(
          JSON.stringify({
            type: "status",
            status: "error",
            message: err?.message || String(err),
          })
        );
      }
    }

    if (msg.type === "disconnect") {
      await disconnectTikTok();
    }

    if (msg.type === "simulate") {
      const allowed = new Set(["join", "kill1", "clones", "kills5", "kills15", "killAll"]);
      if (allowed.has(msg.action)) {
        emitGiftAction({
          action: msg.action,
          username: msg.username || "DemoUser",
          nickname: msg.nickname || msg.username || "DemoUser",
          giftName: msg.giftName || "Simulated",
          repeatCount: msg.repeatCount || 1,
        });
      }
    }
  });
});

server.listen(PORT, () => {
  console.log(`RagnaOne Live running at http://localhost:${PORT}`);
});

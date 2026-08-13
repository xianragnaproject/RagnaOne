# Ring Rage — TikTok Live Gift Game

Browser-based stickman wrestling arena driven by **TikTok Live** chat, likes, and gifts. Built for OBS Browser Source overlays.

## Features

- **Chat Join** — viewers type `join` to enter the queue
- **Tap 30 Join** — 30 likes also queues a fighter
- **Gift mapping** (matches common live gift-game economy):
  - 1 coin → 25 Heal
  - 10 coins → Stick weapon
  - 50 coins → 255 Heal
  - 100 coins → 325 Heal
  - 1000 coins → 1K Heal
- **Match queue** with champion win streak
- **Demo mode** so you can test without going live
- **Control panel** to connect TikTok / fire test gifts

## Quick start

```bash
npm install
npm start
```

Open:

- Overlay (OBS): http://localhost:3000
- Control panel: http://localhost:3000/control.html

### OBS

1. Add a **Browser Source** → `http://localhost:3000` at **1280×720** (or your canvas size).
2. Go live on TikTok.
3. In the control panel, enter your TikTok username and click **Connect**.

### Environment

Copy `.env.example` values into your shell or a `.env` loader:

| Variable | Default | Meaning |
|---|---|---|
| `TIKTOK_USERNAME` | empty | Auto-connect on boot |
| `PORT` | `3000` | HTTP port |
| `DEMO_MODE` | `true` | Fake events when not live |

```bash
TIKTOK_USERNAME=yourname PORT=3000 npm start
```

## How fights work

1. Viewers join via chat (`join`) or likes (30 taps).
2. Next queued viewer challenges the current **champion**.
3. Fighters auto-trade hits; gifts heal or arm **the gifter** if they are in the ring (otherwise the challenger).
4. Winner becomes / remains champion and keeps a win streak.

## Project layout

```
server/           Game engine + TikTok bridge
public/           Overlay + control UI (OBS-ready)
```

## Notes

- Uses [`tiktok-live-connector`](https://github.com/zerodytrash/TikTok-Live-Connector) (unofficial). TikTok may change endpoints; demo mode always works.
- This is an entertainment overlay, not affiliated with TikTok or WWE.

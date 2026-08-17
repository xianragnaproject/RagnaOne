# RagnaOne — Temple Signal

TikTok Live interactive arena game inspired by Red Light / Green Light stream overlays.

Viewers send gifts to join as contestants, spawn clones, or eliminate players. You capture the browser window (or full screen) into OBS / TikTok LIVE Studio.

## Quick start

```bash
npm install
npm start
```

Open [http://localhost:3000](http://localhost:3000).

1. Click the demo gift buttons to test without going live.
2. Enter your TikTok username and hit **Connect** while you are LIVE.
3. Press **H** (or Hide Panel) so only the game HUD shows on stream.
4. In OBS, add a Browser Source → `http://localhost:3000` (1280×720) or Window Capture.

## Gift mapping

| Gift (typical) | Action |
| --- | --- |
| Rose | Join + 1 life |
| Weights / Turbo-style | 1 kill |
| GG / Finger Heart-style | 5 clones |
| Clapping | 5 kills |
| Snail | 15 kills |
| Donut / big gift | Kill all |

Chat command: type `join` or `!join` to enter without a gift.

Unmapped gifts show a toast with the gift name/id so you can extend the map in `server/index.js` (`GIFT_ACTIONS`).

## How to play (on stream)

- **Green light** — players run toward the temple.
- **Red light** — freeze. Anyone still moving past the red line is eliminated.
- Gift kills credit the sender on **TOP KILL**.
- Extra lives let a player respawn once before leaving the field.

## Stack

- Node.js + Express + WebSocket relay
- [`tiktok-live-connector`](https://github.com/zerodytrash/TikTok-Live-Connector) for live gift/chat events
- Canvas pixel-art arena (no engine required)

## Notes

- You must be **live** for Connect to succeed.
- TikTok gift names vary by region; edit `GIFT_ACTIONS` if your gifts do not match.
- This is an original fan-style overlay (temple / signal theme), not affiliated with TikTok or any TV franchise.

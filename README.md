# RagnaOne

A local operating system for growing a new TikTok account the legitimate way: niche, hooks, calendar, scripts, and a scorecard you actually review.

This does not post for you, buy followers, or automate engagement. Those tactics get accounts restricted and teach the algorithm the wrong audience. RagnaOne is the planning loop, plus a local factory that can cut faceless videos you upload yourself.

## How to use it

1. Open `app/index.html` in a browser. No install, no account, no server.
2. Complete the 5-minute setup: niche, viewer, promise, and three content pillars.
3. Work from **Today** each day. The app gives you a launch plan, a script studio, and a tracker.
4. After every post, log the numbers from TikTok Analytics. The review view tells you what to repeat, rewrite, or drop.
5. Read `docs/PLAYBOOK.md` once, then treat the app as the daily tool.

Data stays in this browser (`localStorage`). Export a backup from Settings if you switch machines.

## What “growth” means here

A new account does not need more hacks. It needs a tight category, videos people finish, and a weekly decision about which format earned the right to be made again.

RagnaOne is built around that loop:

1. Pick one viewer and one promise.
2. Post 3–5 original videos a week, not filler.
3. Open with a categorizable hook in the first 2 seconds.
4. Design for completion, rewatches, saves, and shares.
5. Reply and engage in-niche for 30 minutes a day.
6. Every 7 days, double down on the winning pillar + hook + length.

## What this will not do

- Post, comment, follow, or scrape TikTok
- Generate fake views, bots, or engagement pods
- Guarantee virality

If a video dies at a few hundred views on a new account, that is often the cold-start test, not a shadowban. Keep posting, keep logging, keep cutting what the data rejects.

## Ready-to-post videos

Four faceless videos are in `videos/out/`. Posting order and captions are in `videos/POSTING.md` and in the Factory tab.

```bash
python3 -m pip install -r requirements.txt
python3 tools/render_video.py videos/scripts/*.json
```

Label them as AI-generated when you upload. If this "ship from zero" series is not your niche, do not post them — send the real topic and I will recut the week.

## Repo layout

```
app/                Growth OS (open index.html)
docs/PLAYBOOK.md    Full 2026 operating manual
videos/scripts/     Video scripts (JSON)
videos/out/         Rendered 1080x1920 MP4s
tools/render_video.py
```

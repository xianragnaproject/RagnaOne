# How to post these videos

These are faceless, voiceover videos. You still have to post them. I cannot log into TikTok for you.

## Before you post

1. Watch each file in `videos/out/`. If a line feels wrong, tell me and I will recut it.
2. In TikTok, turn on the **AI-generated content** label. This used a synthetic voice and generated frames.
3. Film a 2-second reaction stitch later if you want a face on the account. Do not start with a watermarked repost.

## Caption copy

Copy the caption from the matching JSON in `videos/scripts/`, or from the Factory tab in the Growth OS. Keep the keyword in the first sentence.

Hashtags stay at 3–5. Do not add `#fyp` as the whole strategy.

## First week order

| Day | File | Hook |
| --- | --- | --- |
| 1 | `01-ugly-version.mp4` | Stop building the logo. |
| 2 | `02-three-hour-rule.mp4` | The 3-hour rule that kills projects. |
| 3 | `03-nobody-asked.mp4` | If nobody asked, it is not a business. |
| 4 | `04-weekly-scoreboard.mp4` | The only weekly scoreboard. |

Reply to every comment for the first hour. If someone argues, that is a Part 2.

## Make another one

```bash
python3 -m pip install -r requirements.txt
python3 tools/render_video.py videos/scripts/01-ugly-version.json
```

Or send me the niche, the viewer, and 4 titles. I will write scripts and render the next batch.

This first week is a **maker / ship-from-zero** series because you had not picked a niche yet. If that is not the account, do not post these. Tell me the real topic and I will cut a new set.

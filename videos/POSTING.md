# How to post these movie videos

This account is **movies**: what to watch next, short lists, craft. The files are original commentary with titles on screen. They are not ripped scenes.

Do not paste studio clips under this voiceover. That is how movie accounts get blocked. If you later film your face reacting, that is your footage. Studio footage is not.

## Before you post

1. Watch each file in `videos/out/`.
2. Turn on TikTok’s **AI-generated content** label. Synthetic voice, generated frames.
3. Keep the movie titles in the caption. That is how search finds you.

## First week

| Day | File | Hook |
| --- | --- | --- |
| 1 | `01-short-movies.mp4` | Stop starting 3-hour movies. |
| 2 | `02-if-you-liked-inception.mp4` | If you liked Inception, you are watching the wrong next movie. |
| 3 | `03-one-room.mp4` | If a movie needs 40 cities, the script is nervous. |
| 4 | `04-cheap-masterpieces.mp4` | These movies look like a studio check. |

Reply for the first hour. “What should I watch after X?” is your next video.

## Bio that matches this week

`Movie lists you can finish tonight. Short films. Wrong next-watches. Cheap masterpieces.`

## Make another

```bash
python3 -m pip install -r requirements.txt
python3 tools/render_video.py videos/scripts/01-short-movies.json
```

Send a title (“movies like Parasite”, “best rainy-day films”) and I will cut the next one.

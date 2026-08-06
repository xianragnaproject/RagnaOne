# aiChat — AI-only replies when players talk to the bot

## Critical

**API only.** No local/keyword fallback. Without a working `aiChat_apiKey` + curl, the bot stays silent.

```
aichat status
```

Look for `mode: API only` and `last mode: api` after a successful reply.

## Enable

In `control/sys.txt`:

```
loadPlugins 2
loadPlugins_list ...,aiChat
```

Copy `aiChat.pl` into `plugins/aiChat/`.

In `config.txt`:

```
aiChat 1
aiChat_apiKey sk-YOUR_OPENAI_KEY
aiChat_model gpt-4o-mini
aiChat_public 1
aiChat_publicNeedName 1
aiChat_nearDist 3
aiChat_delay 2
aiChat_cooldown 6
aiChat_maxLen 70
```

Needs `curl` on PATH (Windows: `curl.exe`).

## Behavior

- **PM**: replies via AI only
- **Public + name / nearby**: replies via AI only
- No key / API fail → **no reply** (warning in console)

## Console

```
aichat status
aichat on | off
aichat test PlayerName what level are you
```

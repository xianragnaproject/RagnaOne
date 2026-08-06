# aiChat — AI replies when players talk to the bot

## Critical

**Smart replies need an API key.** Without `aiChat_apiKey`, you only get the local fallback (keyword replies). Check the console:

```
aichat status
```

Look for `api key` and `last mode` (`api` = smart, `local` = fallback).

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

Also needs `curl` on PATH (Windows: `curl.exe` is fine).

## Behavior

- **PM**: always replies (after `aiChat_delay`)
- **Public + name mention**: replies
- **Public + nearby (≤ `aiChat_nearDist` cells)**: replies even without name
- API replies use live char facts (job, level, map)
- No key / API fail → smarter local fallback (still not as good as GPT)

## Console

```
aichat status
aichat on | off
aichat test PlayerName what level are you
```

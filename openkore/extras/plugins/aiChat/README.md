# aiChat — AI replies when players talk to the bot

## Enable

In `control/sys.txt`:

```
loadPlugins 2
loadPlugins_list ...,aiChat
```

In `config.txt`:

```
aiChat 1
aiChat_apiKey YOUR_OPENAI_KEY
aiChat_model gpt-4o-mini
aiChat_public 1
aiChat_publicNeedName 1
aiChat_cooldown 6
aiChat_maxLen 70
```

Or set env `OPENAI_API_KEY` / `AI_CHAT_API_KEY`.

Any OpenAI-compatible endpoint works via `aiChat_apiUrl`.

## Behavior

- **PM**: replies when `aiChat 1`
- **Public**: if `aiChat_public 1` and (by default) your name is mentioned
- No API key → local short fallback replies
- Per-player cooldown, short history, length cap

## Console

```
aichat status
aichat on | off
aichat test PlayerName hello
```

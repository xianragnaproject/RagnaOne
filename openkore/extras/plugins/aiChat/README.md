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
aiChat_nearDist 3
aiChat_delay 2
aiChat_cooldown 6
aiChat_maxLen 70
```

## Behavior

- **PM**: always replies (after `aiChat_delay`)
- **Public + name mention**: replies
- **Public + nearby (≤ `aiChat_nearDist` cells)**: replies even without name
- No API key → local short fallback replies

## Console

```
aichat status
aichat on | off
aichat test PlayerName hello
```

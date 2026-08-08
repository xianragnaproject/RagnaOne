# OKX futures candle-gap bot (educational)

Python bot that watches OKX **USDT perpetual futures** candles and, when it sees a **gap** (next candle open differs from previous close by at least a threshold), logs a long/short signal.

**Defaults are safe for learning:**
- `DRY_RUN=true` — never places orders
- `OKX_DEMO=true` — OKX demo/sandbox endpoints

This is **not financial advice**. Futures are high risk; you can lose more than you expect. You run the bot and own every trade.

## Gap rule

On each poll, the bot loads recent candles and compares the two most recent **closed** candles:

`gap% = (current_open - previous_close) / previous_close * 100`

If `|gap%| >= GAP_THRESHOLD_PCT`:

| `GAP_MODE` | Gap up | Gap down |
|------------|--------|----------|
| `with` (default) | long | short |
| `fade` | short | long |

## Setup (Windows VPS)

```powershell
cd okx_gap_bot
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

Edit `.env`:

1. Create **demo** API keys in the [OKX demo trading](https://www.okx.com/) environment (demo keys differ from live keys).
2. Paste `OKX_API_KEY`, `OKX_API_SECRET`, `OKX_API_PASSPHRASE`.
3. Keep `DRY_RUN=true` until signals look sane in the logs.
4. Prefer keys with **trade** enabled and **withdraw disabled**.

## Run

```powershell
python bot.py
```

Dry-run works for public candle polling even without keys. Live/demo orders need keys.

## Useful env vars

| Variable | Default | Meaning |
|----------|---------|---------|
| `SYMBOL` | `BTC/USDT:USDT` | OKX swap symbol (ccxt form) |
| `TIMEFRAME` | `1m` | Candle size |
| `GAP_THRESHOLD_PCT` | `0.05` | Min gap size in percent |
| `GAP_MODE` | `with` | `with` or `fade` |
| `POLL_SECONDS` | `5` | Loop sleep |
| `LEVERAGE` | `2` | Used only when not dry-run |
| `POSITION_USDT` | `10` | Rough notional used to size contracts |
| `TAKE_PROFIT_PCT` / `STOP_LOSS_PCT` | `0.15` / `0.10` | Attached TP/SL % from entry |
| `DRY_RUN` | `true` | No orders |
| `OKX_DEMO` | `true` | Demo API |

## Tests

```powershell
python test_gap.py
```

## Going live (only if you accept the risk)

1. Confirm strategy on demo + dry-run logs.
2. Set `DRY_RUN=false` with demo keys first.
3. Only then consider live keys with `OKX_DEMO=false`, tiny size, low leverage.

Do not share API keys with anyone (including chatbots).

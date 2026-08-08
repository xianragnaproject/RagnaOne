"""
OKX futures candle-gap trading bot (educational).

Default: DRY_RUN=true and OKX_DEMO=true — no live money orders.
This is not financial advice. Futures can liquidate your account.
"""

from __future__ import annotations

import logging
import math
import sys
import time
from typing import Optional

import ccxt

from config import Config, load_config
from gap import detect_gap, ohlcv_to_candles

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("okx-gap-bot")


def build_exchange(cfg: Config) -> ccxt.okx:
    exchange = ccxt.okx(
        {
            "apiKey": cfg.api_key,
            "secret": cfg.api_secret,
            "password": cfg.passphrase,
            "enableRateLimit": True,
            "options": {
                "defaultType": "swap",
            },
        }
    )
    if cfg.demo:
        # OKX demo trading (paper). Still needs demo API keys from OKX demo site.
        exchange.set_sandbox_mode(True)
        log.info("Using OKX DEMO / sandbox endpoints")
    return exchange


def require_credentials(cfg: Config) -> None:
    if cfg.dry_run and not (cfg.api_key and cfg.api_secret and cfg.passphrase):
        log.warning(
            "No API keys set — dry-run will still fetch public candles; "
            "orders are never sent in dry-run."
        )
        return
    if not cfg.dry_run and not (cfg.api_key and cfg.api_secret and cfg.passphrase):
        log.error("Live mode requires OKX_API_KEY, OKX_API_SECRET, OKX_API_PASSPHRASE")
        sys.exit(1)


def fetch_closed_aware_ohlcv(exchange: ccxt.okx, cfg: Config) -> list:
    return exchange.fetch_ohlcv(cfg.symbol, timeframe=cfg.timeframe, limit=30)


def has_open_position(exchange: ccxt.okx, symbol: str) -> bool:
    try:
        positions = exchange.fetch_positions([symbol])
    except Exception as exc:  # noqa: BLE001 — surface exchange errors in logs
        log.warning("Could not fetch positions: %s", exc)
        return False
    for pos in positions:
        contracts = float(pos.get("contracts") or 0)
        if abs(contracts) > 0:
            return True
    return False


def contracts_for_notional(
    exchange: ccxt.okx, symbol: str, usdt: float, price: float
) -> float:
    market = exchange.market(symbol)
    contract_size = float(market.get("contractSize") or 1)
    raw = usdt / (price * contract_size)
    amount = float(exchange.amount_to_precision(symbol, raw))
    min_amount = (market.get("limits") or {}).get("amount", {}).get("min")
    if min_amount is not None and amount < float(min_amount):
        amount = float(min_amount)
    if amount <= 0 or math.isnan(amount):
        raise ValueError(f"Invalid contract amount computed: {amount}")
    return amount


def set_leverage_safe(exchange: ccxt.okx, cfg: Config) -> None:
    try:
        exchange.set_leverage(cfg.leverage, cfg.symbol)
        log.info("Leverage set to %sx on %s", cfg.leverage, cfg.symbol)
    except Exception as exc:  # noqa: BLE001
        log.warning("Could not set leverage (may already be set): %s", exc)


def place_gap_trade(exchange: ccxt.okx, cfg: Config, side: str, entry: float) -> None:
    amount = contracts_for_notional(exchange, cfg.symbol, cfg.position_usdt, entry)
    order_side = "buy" if side == "long" else "sell"

    if side == "long":
        tp = entry * (1 + cfg.take_profit_pct / 100.0)
        sl = entry * (1 - cfg.stop_loss_pct / 100.0)
    else:
        tp = entry * (1 - cfg.take_profit_pct / 100.0)
        sl = entry * (1 + cfg.stop_loss_pct / 100.0)

    log.info(
        "Signal %s %s amount=%s entry≈%s tp≈%s sl≈%s dry_run=%s",
        order_side,
        cfg.symbol,
        amount,
        entry,
        tp,
        sl,
        cfg.dry_run,
    )

    if cfg.dry_run:
        log.info("DRY_RUN: skipping order")
        return

    # Market entry; attach TP/SL via OKX attachAlgoOrds when supported by ccxt params.
    params = {
        "tdMode": "cross",
        "attachAlgoOrds": [
            {
                "tpTriggerPx": str(tp),
                "tpOrdPx": "-1",  # market TP
                "slTriggerPx": str(sl),
                "slOrdPx": "-1",  # market SL
            }
        ],
    }
    order = exchange.create_order(
        cfg.symbol, "market", order_side, amount, None, params
    )
    log.info("Order submitted: %s", order.get("id") or order)


def run_once(
    exchange: ccxt.okx, cfg: Config, last_signal_ts: Optional[int]
) -> Optional[int]:
    rows = fetch_closed_aware_ohlcv(exchange, cfg)
    candles = ohlcv_to_candles(rows)
    signal = detect_gap(
        candles,
        threshold_pct=cfg.gap_threshold_pct,
        mode=cfg.gap_mode,
        use_closed_only=True,
    )
    if signal is None:
        last = candles[-2] if len(candles) >= 2 else None
        if last:
            log.info(
                "No gap | last closed O=%.4f C=%.4f threshold=%.4f%%",
                last.open,
                last.close,
                cfg.gap_threshold_pct,
            )
        return last_signal_ts

    if last_signal_ts is not None and signal.candle_ts == last_signal_ts:
        log.info("Gap already handled for candle ts=%s", signal.candle_ts)
        return last_signal_ts

    log.info(
        "GAP %.4f%% open=%.4f prev_close=%.4f -> %s (%s)",
        signal.gap_pct,
        signal.open,
        signal.prev_close,
        signal.side,
        cfg.gap_mode,
    )

    if cfg.one_position_only and not cfg.dry_run:
        if has_open_position(exchange, cfg.symbol):
            log.info("Open position exists — skipping new entry")
            return signal.candle_ts

    place_gap_trade(exchange, cfg, signal.side, signal.open)
    return signal.candle_ts


def main() -> None:
    cfg = load_config()
    require_credentials(cfg)

    log.info(
        "Starting gap bot symbol=%s tf=%s mode=%s threshold=%.4f%% demo=%s dry_run=%s",
        cfg.symbol,
        cfg.timeframe,
        cfg.gap_mode,
        cfg.gap_threshold_pct,
        cfg.demo,
        cfg.dry_run,
    )
    if not cfg.dry_run and not cfg.demo:
        log.warning("LIVE REAL-MONEY MODE. Futures can liquidate you. Ctrl+C to stop.")

    exchange = build_exchange(cfg)
    exchange.load_markets()

    if not cfg.dry_run:
        set_leverage_safe(exchange, cfg)

    last_signal_ts: Optional[int] = None
    while True:
        try:
            last_signal_ts = run_once(exchange, cfg, last_signal_ts)
        except ccxt.NetworkError as exc:
            log.warning("Network error: %s", exc)
        except ccxt.ExchangeError as exc:
            log.error("Exchange error: %s", exc)
        except Exception as exc:  # noqa: BLE001
            log.exception("Unexpected error: %s", exc)
        time.sleep(max(1, cfg.poll_seconds))


if __name__ == "__main__":
    main()

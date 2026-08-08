"""Bot configuration. Override via environment variables or .env."""

from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Config:
    # Credentials
    api_key: str
    api_secret: str
    passphrase: str

    # Modes
    demo: bool = True
    dry_run: bool = True

    # Market
    symbol: str = "BTC/USDT:USDT"  # OKX USDT-margined perpetual
    timeframe: str = "1m"  # candle size used for gap detection
    poll_seconds: int = 5

    # Gap rule: open vs previous close must differ by at least this %
    gap_threshold_pct: float = 0.05  # 0.05% — raise on noisier pairs/TFs

    # Direction: "with" = long gap-up / short gap-down; "fade" = opposite
    gap_mode: str = "with"

    # Position / risk (educational defaults — keep small)
    leverage: int = 2
    position_usdt: float = 10.0  # notional-ish sizing helper via contracts
    take_profit_pct: float = 0.15
    stop_loss_pct: float = 0.10

    # Avoid stacking many entries
    one_position_only: bool = True


def load_config() -> Config:
    return Config(
        api_key=os.getenv("OKX_API_KEY", "").strip(),
        api_secret=os.getenv("OKX_API_SECRET", "").strip(),
        passphrase=os.getenv("OKX_API_PASSPHRASE", "").strip(),
        demo=_bool("OKX_DEMO", True),
        dry_run=_bool("DRY_RUN", True),
        symbol=os.getenv("SYMBOL", "BTC/USDT:USDT").strip(),
        timeframe=os.getenv("TIMEFRAME", "1m").strip(),
        poll_seconds=int(os.getenv("POLL_SECONDS", "5")),
        gap_threshold_pct=float(os.getenv("GAP_THRESHOLD_PCT", "0.05")),
        gap_mode=os.getenv("GAP_MODE", "with").strip().lower(),
        leverage=int(os.getenv("LEVERAGE", "2")),
        position_usdt=float(os.getenv("POSITION_USDT", "10")),
        take_profit_pct=float(os.getenv("TAKE_PROFIT_PCT", "0.15")),
        stop_loss_pct=float(os.getenv("STOP_LOSS_PCT", "0.10")),
        one_position_only=_bool("ONE_POSITION_ONLY", True),
    )

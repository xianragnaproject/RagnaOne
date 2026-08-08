"""Candle gap detection helpers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Optional

Side = Literal["long", "short"]


@dataclass(frozen=True)
class Candle:
    ts: int
    open: float
    high: float
    low: float
    close: float
    volume: float


@dataclass(frozen=True)
class GapSignal:
    side: Side
    prev_close: float
    open: float
    gap_pct: float
    candle_ts: int


def ohlcv_to_candles(rows: list) -> list[Candle]:
    return [
        Candle(
            ts=int(r[0]),
            open=float(r[1]),
            high=float(r[2]),
            low=float(r[3]),
            close=float(r[4]),
            volume=float(r[5]),
        )
        for r in rows
    ]


def detect_gap(
    candles: list[Candle],
    threshold_pct: float,
    mode: str = "with",
    *,
    use_closed_only: bool = True,
) -> Optional[GapSignal]:
    """
    Detect a gap between previous close and next open.

    With use_closed_only=True (default), ignore the still-forming candle
    and compare the two most recent *closed* candles:
      gap = closed[-1].open vs closed[-2].close
    """
    if use_closed_only:
        if len(candles) < 3:
            return None
        prev, curr = candles[-3], candles[-2]
    else:
        if len(candles) < 2:
            return None
        prev, curr = candles[-2], candles[-1]

    if prev.close <= 0:
        return None

    gap_pct = ((curr.open - prev.close) / prev.close) * 100.0
    if abs(gap_pct) < threshold_pct:
        return None

    if gap_pct > 0:
        side: Side = "long" if mode == "with" else "short"
    else:
        side = "short" if mode == "with" else "long"

    return GapSignal(
        side=side,
        prev_close=prev.close,
        open=curr.open,
        gap_pct=gap_pct,
        candle_ts=curr.ts,
    )

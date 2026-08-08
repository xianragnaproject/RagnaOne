"""Unit tests for gap detection (no exchange calls)."""

from gap import Candle, detect_gap


def _c(ts: int, o: float, h: float, l: float, c: float) -> Candle:
    return Candle(ts=ts, open=o, high=h, low=l, close=c, volume=1.0)


def test_gap_up_with_mode():
    # forming candle + two closed: prev close 100, next open 100.2 => +0.2%
    candles = [
        _c(1, 99, 100, 98, 100),
        _c(2, 100.2, 101, 100, 100.5),
        _c(3, 100.5, 101, 100, 100.6),  # forming / ignored
    ]
    sig = detect_gap(candles, threshold_pct=0.05, mode="with")
    assert sig is not None
    assert sig.side == "long"
    assert abs(sig.gap_pct - 0.2) < 1e-9


def test_gap_down_fade_mode():
    candles = [
        _c(1, 100, 101, 99, 100),
        _c(2, 99.5, 100, 99, 99.7),  # -0.5% gap
        _c(3, 99.7, 100, 99, 99.8),
    ]
    sig = detect_gap(candles, threshold_pct=0.05, mode="fade")
    assert sig is not None
    assert sig.side == "long"  # fade gap-down => long


def test_no_gap_below_threshold():
    candles = [
        _c(1, 100, 101, 99, 100),
        _c(2, 100.01, 101, 100, 100.02),  # 0.01%
        _c(3, 100.02, 101, 100, 100.03),
    ]
    assert detect_gap(candles, threshold_pct=0.05, mode="with") is None


if __name__ == "__main__":
    test_gap_up_with_mode()
    test_gap_down_fade_mode()
    test_no_gap_below_threshold()
    print("ok")

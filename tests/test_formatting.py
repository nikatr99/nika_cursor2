import numpy as np
import pandas as pd
import pytest

import app


def test_fmt_num():
    assert app.fmt_num(1234.56) == "1,235"
    assert app.fmt_num(1234.56, 1) == "1,234.6"
    assert app.fmt_num(None) == "-"
    assert app.fmt_num(float("nan")) == "-"


def test_fmt_money():
    assert app.fmt_money(1234.6) == "$1,235"
    # Python format rounding is half-to-even, so an exact .5 rounds down here.
    assert app.fmt_money(1234.5) == "$1,234"
    assert app.fmt_money(1234.5, 2) == "$1,234.50"
    assert app.fmt_money(None) == "-"


def test_fmt_money_r():
    assert app.fmt_money_r(1234.5) == "1,234.50 $"
    assert app.fmt_money_r(None) == "-"


def test_fmt_pct():
    assert app.fmt_pct(0.1234) == "12.3%"
    assert app.fmt_pct(0.1234, 2) == "12.34%"
    assert app.fmt_pct(None) == "-"


def test_fmt_rate():
    assert app.fmt_rate(1.2345) == "1.23"
    assert app.fmt_detail_rate(1.2345) == "1.23"
    assert app.fmt_rate(None) == "-"


def test_safe_div():
    assert app.safe_div(10, 4) == 2.5
    assert np.isnan(app.safe_div(10, 0))
    assert np.isnan(app.safe_div(10, None))
    assert np.isnan(app.safe_div(10, float("nan")))


def test_weighted_mean():
    values = pd.Series([1.0, 3.0])
    weights = pd.Series([1.0, 3.0])
    assert app.weighted_mean(values, weights) == 2.5
    assert np.isnan(app.weighted_mean(values, pd.Series([0.0, 0.0])))
    # NaN values count as zero, NaN weights drop out of the denominator.
    assert app.weighted_mean(pd.Series([np.nan, 4.0]), pd.Series([1.0, 1.0])) == 2.0


def test_to_rgba():
    assert app.to_rgba("#ffffff", 0.5) == "rgba(255,255,255,0.5)"
    assert app.to_rgba("#fff", 0.5) == "rgba(255,255,255,0.5)"
    assert app.to_rgba("not-a-color") == "not-a-color"


def test_yoy_pct_html():
    up = app.yoy_pct_html(110.0, 100.0)
    assert "yoy-good" in up and "+10.0%" in up
    down = app.yoy_pct_html(90.0, 100.0)
    assert "yoy-bad" in down and "-10.0%" in down
    # For a cost-like metric a drop is good.
    assert "yoy-good" in app.yoy_pct_html(90.0, 100.0, lower_is_better=True)
    assert "yoy-flat" in app.yoy_pct_html(100.0, 100.0)
    assert app.yoy_pct_html(100.0, 0.0) is None
    assert app.yoy_pct_html(None, 100.0) is None
    with_tip = app.yoy_pct_html(110.0, 100.0, prev_formatter=app.fmt_money)
    assert 'data-yoy-tip="Prior period: $100"' in with_tip


def test_date_window_helpers():
    start, end = app.date_window(("2026-01-01", "2026-03-15"))
    assert start == pd.Timestamp("2026-01-01")
    assert end == pd.Timestamp("2026-03-15")
    prev_start, prev_end = app.prev_year_window(start, end)
    assert prev_start == pd.Timestamp("2025-01-01")
    assert prev_end == pd.Timestamp("2025-03-15")
    assert app.spans_more_than_two_months(("2026-01-01", "2026-03-15"))
    assert not app.spans_more_than_two_months(("2026-01-01", "2026-02-15"))


def test_monthly_date():
    df = pd.DataFrame({"Date": pd.to_datetime(["2026-01-05", "2026-01-20", "2026-02-03"]), "v": [1, 2, 3]})
    out = app.monthly_date(df)
    assert list(out["Date"]) == [
        pd.Timestamp("2026-01-01"),
        pd.Timestamp("2026-01-01"),
        pd.Timestamp("2026-02-01"),
    ]

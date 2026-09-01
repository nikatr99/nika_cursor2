"""Value formatting and small numeric helpers shared across the dashboard."""

from __future__ import annotations

import html
from typing import Optional

import numpy as np
import pandas as pd


def to_rgba(color: str, alpha: float = 0.4) -> str:
    """Convert a hex color to an rgba() string with the given alpha."""
    h = color.lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    if len(h) != 6:
        return color
    try:
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    except ValueError:
        return color
    return f"rgba({r},{g},{b},{alpha})"


def safe_div(num: float, den: float) -> float:
    if den is None or pd.isna(den) or den == 0:
        return np.nan
    return float(num) / float(den)


def weighted_mean(values: pd.Series, weights: pd.Series) -> float:
    values = pd.to_numeric(values, errors="coerce")
    weights = pd.to_numeric(weights, errors="coerce").fillna(0)
    den = weights.sum()
    if den == 0:
        return np.nan
    return float((values.fillna(0) * weights).sum() / den)


def fmt_num(value: float, digits: int = 0) -> str:
    if value is None or pd.isna(value):
        return "-"
    return f"{value:,.{digits}f}"


def fmt_money(value: float, digits: int = 0) -> str:
    if value is None or pd.isna(value):
        return "-"
    return f"${value:,.{digits}f}"


def fmt_money_r(value: float, digits: int = 2) -> str:
    if value is None or pd.isna(value):
        return "-"
    return f"{value:,.{digits}f} $"


def fmt_pct(value: float, digits: int = 1) -> str:
    if value is None or pd.isna(value):
        return "-"
    return f"{value * 100:.{digits}f}%"


def fmt_rate(value: float, digits: int = 2) -> str:
    if value is None or pd.isna(value):
        return "-"
    return f"{value:.{digits}f}"


def fmt_detail_rate(value: float) -> str:
    return fmt_rate(value, 2)


def yoy_pct_html(current: object, prev: object, prev_formatter=None, lower_is_better: bool = False) -> Optional[str]:
    try:
        c = float(current) if current is not None else float("nan")
        p = float(prev) if prev is not None else float("nan")
    except (TypeError, ValueError):
        return None
    if not (np.isfinite(c) and np.isfinite(p)) or p == 0:
        return None
    delta = (c - p) / abs(p) * 100.0
    if abs(delta) < 0.05:
        kind, arrow, sign = "flat", "–", ""
    elif delta > 0:
        kind = "bad" if lower_is_better else "good"
        arrow, sign = "▲", "+"
    else:
        kind = "good" if lower_is_better else "bad"
        arrow, sign = "▼", ""
    tooltip_attr = ""
    if prev_formatter is not None:
        try:
            prev_str = html.escape(str(prev_formatter(p)))
            tooltip_attr = f' data-yoy-tip="Prior period: {prev_str}"'
        except Exception:
            tooltip_attr = ""
    return f'<span class="yoy-delta yoy-{kind}"{tooltip_attr}>{arrow} {sign}{delta:.1f}%</span>'

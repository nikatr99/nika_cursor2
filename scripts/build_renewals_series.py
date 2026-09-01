#!/usr/bin/env python3
"""Consolidate the Metorik exports into daily renewals series, one per store.

The exports arrive as separate "with renewals" / "without renewals" pairs per date
span. March 2026 is split at the 16th because the store timezone changed that day.

Two quirks in the source files are handled here:
  * The 1-15 March pair is mislabelled - the file named "w renewals" holds the
    without-renewals figures and vice versa. Detected and corrected per pair
    rather than hardcoded, so a corrected re-export also works.
  * The timezone switch truncated 2026-03-16, so that day's absolute values run
    ~21% light. Ratios are unaffected because both exports lost the same hours,
    which is why downstream use should prefer the share over the level.

Europe reports in euros while the workbook reports dollars converted at the daily
rate, so the European series carries shares and order counts only. Both are free of
the currency, and the app takes no euro amount from it.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "wo renewals"
OUT_PATH = ROOT / "App_py" / "data" / "renewals_daily_us.csv"
EU_OUT_PATH = ROOT / "App_py" / "data" / "renewals_daily_eu.csv"

# (with-renewals file, without-renewals file) as named on disk
PAIRS = [
    ("until february w renewals.csv", "until february wo renewals.csv"),
    ("march1 w renewals.csv", "march 1 wo renewals.csv"),
    ("march2 w renewals.csv", "march2 wo renewals.csv"),
    ("april to july w renewals.csv", "april to july wo renewals.csv"),
]

EU_PAIR = ("eu w renewals.csv", "eu wo renewals.csv")

VALUE_COLS = ["Orders", "Items", "Customers", "Gross", "Net", "Refunds", "Discounts", "Taxes", "Shipping", "Fees"]


def load(name: str) -> pd.DataFrame:
    path = SRC_DIR / name
    if not path.exists():
        raise SystemExit(f"missing export: {path}")
    df = pd.read_csv(path, parse_dates=["Date"])
    for col in VALUE_COLS:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0)
    return df.sort_values("Date").reset_index(drop=True)


def orient(with_df: pd.DataFrame, without_df: pd.DataFrame, label: str) -> tuple[pd.DataFrame, pd.DataFrame, bool]:
    """Return the pair the right way round.

    Removing renewals can only lower gross revenue and order count, so whichever
    frame is consistently larger is the true with-renewals side.
    """
    merged = with_df.merge(without_df, on="Date", suffixes=("_w", "_wo"))
    active = merged[(merged["Gross_w"] > 0) | (merged["Gross_wo"] > 0)]
    if active.empty:
        return with_df, without_df, False
    as_labelled = ((active["Gross_w"] >= active["Gross_wo"]) & (active["Orders_w"] >= active["Orders_wo"])).mean()
    if as_labelled >= 0.9:
        return with_df, without_df, False
    swapped = ((active["Gross_wo"] >= active["Gross_w"]) & (active["Orders_wo"] >= active["Orders_w"])).mean()
    if swapped >= 0.9:
        print(f"  {label}: files are swapped ({swapped:.0%} consistent reversed) - corrected", file=sys.stderr)
        return without_df, with_df, True
    raise SystemExit(f"{label}: cannot orient pair (as-labelled {as_labelled:.0%}, swapped {swapped:.0%})")


def build_eu() -> pd.DataFrame:
    """Difference Europe's daily pair into shares and order counts.

    Europe reports euros against a workbook kept in dollars at the daily rate, so no
    amount here can be used as it stands. A share is the same number in either
    currency and an order count has no currency at all, so those are what this writes
    and the app applies the share to the workbook's own dollar tax line.
    """
    w, wo, _ = orient(load(EU_PAIR[0]), load(EU_PAIR[1]), "eu")
    merged = w.merge(wo, on="Date", suffixes=("_w", "_wo"), validate="one_to_one")
    merged["Renewal_Orders"] = (merged["Orders_w"] - merged["Orders_wo"]).clip(lower=0)
    for name, col in (("Renewal_Tax_Share", "Taxes"), ("Renewal_Share", "Gross")):
        with_col, without_col = f"{col}_w", f"{col}_wo"
        share = (merged[with_col] - merged[without_col]) / merged[with_col]
        merged[name] = share.where(merged[with_col] > 0, 0.0).clip(lower=0.0, upper=1.0)
    merged["source"] = "eu"
    return merged[["Date", "source", "Renewal_Orders", "Renewal_Tax_Share", "Renewal_Share"]]


def main() -> None:
    frames = []
    for with_name, without_name in PAIRS:
        label = with_name.replace(" w renewals.csv", "")
        w, wo, _ = orient(load(with_name), load(without_name), label)
        merged = w.merge(wo, on="Date", suffixes=("_w", "_wo"), validate="one_to_one")
        merged["source"] = label
        frames.append(merged)

    out = pd.concat(frames, ignore_index=True).sort_values("Date").reset_index(drop=True)

    dupes = out.loc[out["Date"].duplicated(keep=False), "Date"]
    if len(dupes):
        raise SystemExit(f"overlapping dates across exports: {sorted(dupes.dt.date.unique())}")

    span = pd.date_range(out["Date"].min(), out["Date"].max(), freq="D")
    gaps = sorted(set(span) - set(out["Date"]))
    if gaps:
        print(f"  warning: {len(gaps)} missing day(s), first {gaps[0].date()}", file=sys.stderr)

    out["Renewal_Revenue"] = out["Gross_w"] - out["Gross_wo"]
    out["Renewal_Tax"] = out["Taxes_w"] - out["Taxes_wo"]
    out["Renewal_Orders"] = out["Orders_w"] - out["Orders_wo"]
    # Share is the timezone-robust quantity: both exports lost the same hours on
    # 2026-03-16, so the ratio survives even where the absolute level does not.
    out["Renewal_Share"] = (out["Renewal_Revenue"] / out["Gross_w"]).where(out["Gross_w"] > 0)
    out["Renewal_Tax_Share"] = (out["Renewal_Tax"] / out["Taxes_w"]).where(out["Taxes_w"] > 0)

    keep = [
        "Date", "source",
        "Gross_w", "Gross_wo", "Taxes_w", "Taxes_wo", "Orders_w", "Orders_wo",
        "Renewal_Revenue", "Renewal_Tax", "Renewal_Orders", "Renewal_Share", "Renewal_Tax_Share",
    ]
    out[keep].to_csv(OUT_PATH, index=False)

    negatives = out[out["Renewal_Revenue"] < -0.01]
    print(f"wrote {OUT_PATH.relative_to(ROOT)}")
    print(f"  {len(out)} days  {out['Date'].min().date()} -> {out['Date'].max().date()}")
    print(f"  renewal revenue total {out['Renewal_Revenue'].sum():,.0f}")
    print(f"  renewal tax total     {out['Renewal_Tax'].sum():,.0f}")
    if len(negatives):
        print(f"  warning: {len(negatives)} day(s) with negative renewal revenue")

    eu = build_eu()
    eu.to_csv(EU_OUT_PATH, index=False)
    print(f"wrote {EU_OUT_PATH.relative_to(ROOT)}")
    print(f"  {len(eu)} days  {eu['Date'].min().date()} -> {eu['Date'].max().date()}")
    print(f"  renewal orders total  {eu['Renewal_Orders'].sum():,.0f}")
    print(f"  renewal tax share     {eu['Renewal_Tax_Share'].min():.1%} - {eu['Renewal_Tax_Share'].max():.1%}")


if __name__ == "__main__":
    main()

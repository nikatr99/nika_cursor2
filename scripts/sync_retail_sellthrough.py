#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from openpyxl import load_workbook


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORKBOOK = ROOT / "Google Sheets" / "Target, BestBuy, Chewy, Walmart Retail Revenue & Units.xlsx"
DEFAULT_REVENUE = ROOT / "App_py" / "data" / "revenue_data.csv"
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")

# The sell-through workbook reports gross revenue before sales tax, while the Summary
# sheets carry each retail channel as hardware plus a flat modelled tax. Grossing up on
# import keeps the two tax-inclusive and directly comparable.
RETAIL_TAX_RATE = 0.0614

# "authoritative" channels are sourced from this workbook rather than the Summary
# sheets for their whole reporting span, so a gap in the file reads as no sales rather
# than falling back to the Summary. Ace Hardware reports only sporadically, so its gaps
# stay gaps.
CHANNEL_MAP = {
    "Target": {"revenue_col": 1, "units_col": 7, "revenue_field": "Target_Revenue", "orders_field": "Target_Orders", "authoritative": True},
    "BestBuy": {"revenue_col": 2, "units_col": 8, "revenue_field": "BestBuy_Revenue", "orders_field": "BestBuy_Orders", "authoritative": True},
    "Chewy": {"revenue_col": 3, "units_col": 9, "revenue_field": "Chewy_Revenue", "orders_field": "Chewy_Orders", "authoritative": True},
    "Ace Hardware": {"revenue_col": 4, "units_col": 10, "revenue_field": "Ace_Hardware_Revenue", "orders_field": "Ace_Hardware_Orders", "authoritative": False},
    # Walmart Retail (physical stores, from 2026) is a separate channel from the
    # Summary's Walmart marketplace line, so it gets its own fields.
    "Walmart Retail": {"revenue_col": 5, "units_col": 11, "revenue_field": "Walmart_Retail_Revenue", "orders_field": "Walmart_Retail_Orders", "authoritative": True},
}

SKU_CHANNEL_PREFIX = {
    "Target": "target",
    "Best Buy": "bestbuy",
    "BestBuy": "bestbuy",
    "Chewy": "chewy",
    "Walmart Retail": "walmart_retail",
    "Ace Hardware": "ace_hardware",
}

SKU_MAP = {
    "BBG1002BAC": "SKU 1 - Blue",
    "BYG1002BAB": "SKU 2 - Yellow",
    "BBG1003BAB": "SKU 3 - Blue w/ Solar",
    "BBG1003BAC": "SKU 3 - Blue w/ Solar",
    "BYG1003BAC": "SKU 3 - Blue w/ Solar",
    "BYG1003BAB": "SKU 4 - Yellow w/ Solar",
    "BBG1002BAD": "SKU 1 - Blue PRO",
    "BBG1003BAD": "SKU 3 - Blue w/ Solar PRO",
    "BBS4052RAA": "Smart Bird Feeder PRO Solar with PEX (Retail SKU)",
    "BWH1025BAA": "SKU 6 - HBF w/ Solar",
    "BWH1025RAA": "Smart Hummingbird Feeder PRO Solar (Retail SKU)",
    "BCG1013BAA": "3-in-1 Nutrition Set - Blue",
    "BBG1021BAA": "Perch Extender - Blue",
    "BBG1003BAE": "Bird Buddy 2",
    "BBG1002BAE": "Bird Buddy Nook",
}

# Retail SKUs deliberately left out of the dashboard. Listing one here silences the
# warning below for it, so the warning only ever names a SKU nobody has looked at.
# Birdbuddy Nook (BBG1002BAE) is NOT listed: it sells at Target from 16 Oct 2026 and
# still needs a product, so the warning should keep naming it.
SKU_UNMAPPED_KNOWN: set[str] = set()

# The retail SKUs go on sale in August 2025, which is where every channel but one starts
# reporting them. Target's column also carries May to July 2025, a stretch the workbook
# booked as the Blue w/ Solar feeder until the sheet was relabelled; those months predate
# the retail SKU, so they keep the feeder they were sold as.
SKU_MAP_BEFORE = {
    ("target", "BBS4052RAA"): (pd.Timestamp("2025-08-01"), "SKU 3 - Blue w/ Solar"),
}


def as_num(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(",", "").replace("$", "")
    if not text or text in {"-", "/", "NA", "N/A"}:
        return 0.0
    try:
        return float(text)
    except ValueError:
        return 0.0


def reported_num(value: Any) -> float:
    """Blank cells stay blank: the workbook leaves a channel empty until it starts
    selling, and a zero there would overwrite the Summary figure with nothing."""
    if value is None:
        return float("nan")
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(",", "").replace("$", "")
    if not text or text in {"-", "/", "NA", "N/A"}:
        return float("nan")
    try:
        return float(text)
    except ValueError:
        return float("nan")


def load_sellthrough(path: Path, start_date: pd.Timestamp) -> pd.DataFrame:
    wb = load_workbook(path, read_only=True, data_only=True)
    ws = wb["DATA"]
    rows = []
    for row in ws.iter_rows(min_row=3, values_only=True):
        raw_date = row[0]
        if raw_date is None:
            continue
        day = pd.to_datetime(raw_date, errors="coerce")
        if pd.isna(day) or day < start_date:
            continue
        record: dict[str, Any] = {"Date": day.normalize()}
        for spec in CHANNEL_MAP.values():
            record[spec["revenue_field"]] = reported_num(row[spec["revenue_col"]]) * (1.0 + RETAIL_TAX_RATE)
            record[spec["orders_field"]] = reported_num(row[spec["units_col"]])
        if not any(
            pd.notna(value) and value != 0 for key, value in record.items() if key != "Date"
        ):
            continue
        rows.append(record)
    if not rows:
        return pd.DataFrame(columns=["Date"])
    return pd.DataFrame(rows).drop_duplicates(subset=["Date"], keep="last").sort_values("Date")


def clean_text(value: Any) -> str:
    return "" if value is None else str(value).strip()


def clean_sku(value: Any) -> str:
    return clean_text(value).replace("\t", "").replace("\xa0", " ").strip()


def load_sku_mix(path: Path, start_date: pd.Timestamp, end_date: pd.Timestamp) -> pd.DataFrame:
    wb = load_workbook(path, read_only=False, data_only=True)
    ws = wb["SKU MIX (by channel by sku)"]
    cols: list[tuple[int, str, str]] = []
    unmapped: list[str] = []
    current_channel = ""
    for col in range(2, ws.max_column + 1):
        channel = clean_text(ws.cell(1, col).value)
        if channel:
            current_channel = channel
        if current_channel == "Date":
            break
        prefix = SKU_CHANNEL_PREFIX.get(current_channel)
        sku = clean_sku(ws.cell(3, col).value)
        product = SKU_MAP.get(sku)
        if prefix and product:
            cols.append((col, prefix, sku))
        elif prefix and sku and sku not in SKU_UNMAPPED_KNOWN:
            # Without this the column is dropped without a word, which is how the
            # Birdbuddy Nook sold at Target for three days before anyone noticed it
            # was missing from the dashboard.
            name = clean_text(ws.cell(2, col).value) or "unnamed"
            unmapped.append(f"{current_channel} / {sku} ({name})")

    if unmapped:
        print("WARNING: retail SKUs with no dashboard product, their sell-through is not imported:")
        for item in unmapped:
            print(f"  - {item}")
        print("  Add them to SKU_MAP, or to SKU_UNMAPPED_KNOWN once deliberately excluded.")

    # A SKU that changes name partway through reports under both, so every field a column
    # can land in is seeded on each row and the days it does not sell stay at zero.
    fields = set()
    for _, prefix, sku in cols:
        fields.add(f"{prefix}_{SKU_MAP[sku]}")
        if (prefix, sku) in SKU_MAP_BEFORE:
            fields.add(f"{prefix}_{SKU_MAP_BEFORE[(prefix, sku)][1]}")

    rows = []
    for row in range(4, ws.max_row + 1):
        raw_date = ws.cell(row, 1).value
        if raw_date is None:
            continue
        day = pd.to_datetime(raw_date, errors="coerce")
        if pd.isna(day) or day < start_date or day > end_date:
            continue
        record: dict[str, Any] = {"Date": day.normalize()}
        record.update({field: 0.0 for field in fields})
        for col, prefix, sku in cols:
            starts, earlier = SKU_MAP_BEFORE.get((prefix, sku), (None, None))
            product = earlier if starts is not None and day < starts else SKU_MAP[sku]
            field = f"{prefix}_{product}"
            record[field] = record.get(field, 0.0) + as_num(ws.cell(row, col).value)
        rows.append(record)
    if not rows:
        return pd.DataFrame(columns=["Date"])
    return pd.DataFrame(rows).groupby("Date", as_index=False).sum(numeric_only=True).sort_values("Date")


def numeric(df: pd.DataFrame, field: str) -> pd.Series:
    if field not in df.columns:
        return pd.Series(0.0, index=df.index)
    return pd.to_numeric(df[field], errors="coerce").fillna(0.0)


def ensure_dates(revenue: pd.DataFrame, dates: pd.Series) -> pd.DataFrame:
    existing = set(revenue["Date"])
    missing = [day for day in dates if day not in existing]
    if not missing:
        return revenue
    # Left blank rather than zeroed: a day that predates the other channels has no
    # data, and a zero would count as a real reading in rate averages.
    empty = pd.DataFrame({"Date": missing})
    for col in revenue.columns:
        if col != "Date":
            empty[col] = np.nan
    return pd.concat([revenue, empty], ignore_index=True, sort=False)


def apply_sellthrough(revenue_path: Path, workbook_path: Path, start_date: str, output_path: Path | None) -> pd.DataFrame:
    start = pd.Timestamp(start_date)
    sellthrough = load_sellthrough(workbook_path, start)
    if sellthrough.empty:
        raise RuntimeError(f"No sell-through rows found in {workbook_path}")
    sku_mix = load_sku_mix(workbook_path, start, sellthrough["Date"].max())

    revenue = pd.read_csv(revenue_path, parse_dates=["Date"])
    revenue["Date"] = revenue["Date"].dt.normalize()
    all_dates = pd.concat([sellthrough["Date"], sku_mix["Date"]]).drop_duplicates()
    revenue = ensure_dates(revenue, all_dates)
    revenue = revenue.sort_values("Date").reset_index(drop=True)

    touched = revenue["Date"].isin(set(sellthrough["Date"]))
    by_date = sellthrough.set_index("Date")

    for spec in CHANNEL_MAP.values():
        span = sellthrough.loc[sellthrough[spec["revenue_field"]].notna(), "Date"]
        for field in [spec["revenue_field"], spec["orders_field"]]:
            if field not in revenue.columns:
                revenue[field] = 0.0
            incoming = revenue.loc[touched, "Date"].map(by_date[field])
            if spec["authoritative"] and not span.empty:
                within = revenue.loc[incoming.index, "Date"].between(span.min(), span.max())
                incoming = incoming.mask(within, incoming.where(incoming.notna(), 0.0))
            reported = incoming.notna()
            revenue.loc[incoming.index[reported], field] = incoming[reported].to_numpy()

    if not sku_mix.empty:
        sku_touched = revenue["Date"].isin(set(sku_mix["Date"]))
        sku_by_date = sku_mix.set_index("Date")
        sku_fields = [col for col in sku_mix.columns if col != "Date"]
        missing_sku_fields = [field for field in sku_fields if field not in revenue.columns]
        if missing_sku_fields:
            revenue = pd.concat(
                [revenue, pd.DataFrame(0.0, index=revenue.index, columns=missing_sku_fields)],
                axis=1,
            )
        retail_prefixes = tuple(f"{prefix}_" for prefix in sorted(set(SKU_CHANNEL_PREFIX.values())))
        retail_unit_fields = [col for col in revenue.columns if col.startswith(retail_prefixes)]
        if retail_unit_fields:
            revenue.loc[sku_touched, retail_unit_fields] = 0.0
        for field in sku_fields:
            revenue.loc[sku_touched, field] = revenue.loc[sku_touched, "Date"].map(sku_by_date[field]).fillna(0.0).to_numpy()
        single_sku_reconciliations = {
            "Walmart_Retail_Orders": "walmart_retail_Smart Bird Feeder PRO Solar with PEX (Retail SKU)",
        }
        for orders_field, sku_field in single_sku_reconciliations.items():
            if orders_field not in revenue.columns:
                continue
            if sku_field not in revenue.columns:
                revenue[sku_field] = 0.0
            diff = numeric(revenue, orders_field) - numeric(revenue, sku_field)
            needs_reconciliation = sku_touched & (diff.abs() > 0.0001)
            revenue.loc[needs_reconciliation, sku_field] = (
                numeric(revenue, sku_field).loc[needs_reconciliation] + diff.loc[needs_reconciliation]
            )

    retail_revenue_parts = [
        "BestBuy_Revenue", "Target_Revenue", "Walmart_Revenue", "Walmart_Retail_Revenue",
        "Costco_Revenue", "Chewy_Revenue", "Ace_Hardware_Revenue"
    ]
    retail_order_parts = [
        "BestBuy_Orders", "Target_Orders", "Walmart_Orders", "Walmart_Retail_Orders",
        "Costco_Orders", "Chewy_Orders", "Ace_Hardware_Orders"
    ]
    new_retail_revenue = sum(numeric(revenue, field) for field in retail_revenue_parts)
    new_retail_orders = sum(numeric(revenue, field) for field in retail_order_parts)

    revenue.loc[touched, "Retail_Revenue"] = new_retail_revenue.loc[touched]
    revenue.loc[touched, "Total_Retail_Revenue"] = new_retail_revenue.loc[touched]
    revenue.loc[touched, "B2B_Revenue"] = new_retail_revenue.loc[touched]
    revenue.loc[touched, "Total_B2B_Revenue"] = (
        new_retail_revenue.loc[touched] + numeric(revenue, "Digital_Marketplaces_Revenue").loc[touched]
    )
    revenue.loc[touched, "Retail_Orders"] = new_retail_orders.loc[touched]
    revenue.loc[touched, "Total_Retail_Orders"] = new_retail_orders.loc[touched]
    revenue.loc[touched, "B2B_Orders"] = new_retail_orders.loc[touched]
    revenue.loc[touched, "Total_B2B_Orders"] = (
        new_retail_orders.loc[touched] + numeric(revenue, "Digital_Marketplaces_Orders").loc[touched]
    )

    # Total_Revenue and Total_Orders are deliberately left alone. The workbook's
    # Summary totals cover DTC, Amazon, IndieGoGo and Digital Marketplaces only, with
    # retail and app reported separately, so folding sell-through into them would push
    # the headline off the Summary sheet by however much the two retail sources differ.

    revenue = revenue.sort_values("Date").reset_index(drop=True)
    destination = output_path or revenue_path
    if output_path is None:
        backup = revenue_path.with_name(f"{revenue_path.stem}.backup_{STAMP}_before_retail_sellthrough.csv")
        shutil.copy2(revenue_path, backup)
        print(f"Backup: {backup}")
    revenue.to_csv(destination, index=False)
    print(f"Updated {len(sellthrough)} retail sell-through days: {sellthrough['Date'].min().date()}..{sellthrough['Date'].max().date()}")
    if not sku_mix.empty:
        print(f"Updated {len(sku_mix)} retail SKU-mix days: {sku_mix['Date'].min().date()}..{sku_mix['Date'].max().date()}")
    return revenue


def main() -> None:
    parser = argparse.ArgumentParser(description="Apply true retail sell-through revenue and units to dashboard data.")
    parser.add_argument("--workbook", type=Path, default=DEFAULT_WORKBOOK)
    parser.add_argument("--revenue", type=Path, default=DEFAULT_REVENUE)
    # Best Buy sell-through begins in November 2023, before the other channels.
    parser.add_argument("--start-date", default="2023-01-01")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()
    apply_sellthrough(args.revenue, args.workbook, args.start_date, args.output)


if __name__ == "__main__":
    main()

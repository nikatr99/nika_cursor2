#!/usr/bin/env python3

from __future__ import annotations

import argparse
import calendar
import math
import os
import re
import shutil
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable, Sequence

import numpy as np
import pandas as pd
from openpyxl import load_workbook
from openpyxl.utils.cell import range_boundaries


STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


def as_date_cell(value: Any) -> date | None:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, (int, float)) and 20000 < float(value) < 60000:
        return date(1899, 12, 30) + timedelta(days=int(value))
    text = str(value).strip()
    if not text:
        return None
    try:
        numeric = float(text)
        if 20000 < numeric < 60000:
            return date(1899, 12, 30) + timedelta(days=int(numeric))
    except ValueError:
        pass
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            pass
    return None


def as_num(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, datetime):
        return float((value.date() - date(1970, 1, 1)).days)
    if isinstance(value, date):
        return float((value - date(1970, 1, 1)).days)
    if isinstance(value, (int, float)):
        if isinstance(value, float) and math.isnan(value):
            return 0.0
        return float(value)
    text = str(value).strip()
    if not text or text in {"/", "-", "NA", "N/A"}:
        return 0.0
    text = text.replace(",", "").replace("$", "").replace("%", "")
    try:
        return float(text)
    except ValueError:
        return 0.0


def month_dates(year: int, month: int) -> list[date]:
    days = calendar.monthrange(year, month)[1]
    return [date(year, month, day) for day in range(1, days + 1)]


def extract_month(path: Path) -> int:
    match = re.match(r"^(\d+)", path.name)
    if not match:
        raise ValueError(f"Cannot extract month from {path.name}")
    return int(match.group(1))


def extract_year(path: Path) -> int:
    if re.match(r"^20\d{2}$", path.parent.name):
        return int(path.parent.name)
    match = re.search(r"(\d{2})(?=\s*-\s*Sales\.xlsx$)", path.name)
    return 2000 + int(match.group(1)) if match else 2024


def uses_regional_dtc(path: Path) -> bool:
    # The US&CA / EU split of the DTC sheets begins with October 2024. Comparing the
    # month alone would wrongly pull 2023 workbooks into the regional era.
    return (extract_year(path), extract_month(path)) >= (2024, 10)


def normalize_label(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and math.isnan(value):
        return ""
    return str(value).strip()


@dataclass
class WorkbookCache:
    path: Path
    wb: Any | None = None
    sheet_cache: dict[tuple[str, int | None, int | None, int], list[list[Any]]] = field(default_factory=dict)

    def workbook(self):
        if self.wb is None:
            self.wb = load_workbook(self.path, data_only=True, read_only=False)
        return self.wb

    def sheet_names(self) -> list[str]:
        return list(self.workbook().sheetnames)

    def read_sheet(self, sheet: str, rows: tuple[int, int] | None = None, max_col: int = 80) -> list[list[Any]] | None:
        if sheet not in self.sheet_names():
            return None
        start_row = rows[0] if rows else 1
        end_row = rows[1] if rows else None
        key = (sheet, start_row, end_row, max_col)
        if key in self.sheet_cache:
            return self.sheet_cache[key]
        ws = self.workbook()[sheet]
        end = end_row or ws.max_row
        values: list[list[Any]] = []
        for row in ws.iter_rows(min_row=start_row, max_row=end, min_col=1, max_col=max_col, values_only=True):
            values.append(list(row))
        self.sheet_cache[key] = values
        return values

    def merge_ranges(self, sheet: str) -> list[tuple[int, int, int, int]]:
        if sheet not in self.sheet_names():
            return []
        out = []
        for rng in self.workbook()[sheet].merged_cells.ranges:
            min_col, min_row, max_col, max_row = range_boundaries(str(rng))
            out.append((min_row, min_col, max_row, max_col))
        return out


@dataclass
class SyncLog:
    sources: list[dict[str, str]] = field(default_factory=list)
    skips: list[dict[str, str]] = field(default_factory=list)

    def source(self, dates: list[date], file: Path, sheet: str, field: str, source: str) -> None:
        if dates:
            date_label = f"{min(dates).isoformat()}..{max(dates).isoformat()}"
        else:
            date_label = ""
        self.sources.append(
            {"date": date_label, "file": file.name, "sheet": sheet, "field": field, "source": source}
        )

    def skip(self, file: Path, sheet: str, item: str, reason: str) -> None:
        self.skips.append({"file": file.name, "sheet": sheet, "item": item, "reason": reason})


def labels(sheet: list[list[Any]]) -> list[str]:
    return [normalize_label(row[0] if row else None) for row in sheet]


def find_label(
    sheet: list[list[Any]],
    label: str,
    occurrence: int | str = 1,
    contains: bool = False,
    after: int = 1,
    before: float = math.inf,
) -> int | None:
    found: list[int] = []
    pattern = label
    for idx, lab in enumerate(labels(sheet), start=1):
        if idx < after or idx > before:
            continue
        if contains:
            if re.search(pattern, lab, re.IGNORECASE):
                found.append(idx)
        elif lab == label:
            found.append(idx)
    if not found:
        return None
    if occurrence == "last":
        return found[-1]
    occurrence_i = int(occurrence)
    if len(found) < occurrence_i:
        return None
    return found[occurrence_i - 1]


def section_end(sheet: list[list[Any]], start: int, patterns: Iterable[str]) -> int:
    candidates = []
    for idx, lab in enumerate(labels(sheet), start=1):
        if idx <= start:
            continue
        if any(re.search(pattern, lab, re.IGNORECASE) for pattern in patterns):
            candidates.append(idx)
    return (min(candidates) - 1) if candidates else len(sheet)


def row_values(sheet: list[list[Any]], row_1based: int, cols_1based: list[int]) -> list[float]:
    row = sheet[row_1based - 1]
    return [as_num(row[col - 1] if col - 1 < len(row) else None) for col in cols_1based]


def date_cols(sheet: list[list[Any]], dates: list[date]) -> list[int] | None:
    if not sheet:
        return None
    parsed = [as_date_cell(value) for value in sheet[0]]
    cols = []
    for d in dates:
        try:
            hit = next(i + 1 for i, parsed_date in enumerate(parsed) if i != 0 and parsed_date == d)
        except StopIteration:
            return None
        cols.append(hit)
    return cols


def positional_date_cols(
    sheet: list[list[Any]],
    dates: list[date],
    wb: "WorkbookCache",
    sheet_name: str,
    item: str,
    log: "SyncLog",
) -> list[int] | None:
    """Date columns for a tab whose header row was copied from another month.

    A few 2023 tabs carry a stale header: the October marketplace tab is dated January
    2024, December's app tab likewise, and November's marketplace tab has one stray day.
    The figures underneath are the workbook's own month, laid out one column per day from
    B, so falling back to position recovers them where the header cannot be trusted.
    """
    cols = date_cols(sheet, dates)
    if cols is not None:
        return cols
    if sheet and len(sheet[0]) >= len(dates) + 1:
        log.source(dates, wb.path, sheet_name, item, "stale or missing date headers; using columns B onward")
        return list(range(2, len(dates) + 2))
    log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
    return None


def survey_date_cols(sheet: list[list[Any]], dates: list[date]) -> list[int] | None:
    cols = date_cols(sheet, dates)
    if cols is not None:
        return cols
    first_header = as_date_cell(sheet[0][0] if sheet and sheet[0] else None)
    if first_header == dates[0] and len(sheet[0]) >= len(dates) + 1:
        return list(range(2, len(dates) + 2))
    return None


def ensure_dates(df: pd.DataFrame, dates: list[date]) -> pd.DataFrame:
    existing = set(pd.to_datetime(df["Date"]).dt.date)
    missing = [d for d in dates if d not in existing]
    if not missing:
        return df
    rows = [{col: 0 for col in df.columns} | {"Date": d} for d in missing]
    return pd.concat([df, pd.DataFrame(rows)], ignore_index=True)


def put_values(df: pd.DataFrame, dates: list[date], field: str, values: Iterable[float]) -> pd.DataFrame:
    if field not in df.columns:
        df[field] = 0.0
    df[field] = pd.to_numeric(df[field], errors="coerce").astype(float)
    df = ensure_dates(df, dates)
    date_index = pd.to_datetime(df["Date"]).dt.date
    value_map = dict(zip(dates, values))
    df.loc[date_index.isin(value_map), field] = [value_map[d] for d in date_index[date_index.isin(value_map)]]
    return df


def numeric_series(df: pd.DataFrame, dates: list[date], field: str) -> pd.Series:
    idx = pd.to_datetime(df["Date"]).dt.date
    if field not in df.columns:
        return pd.Series([0.0] * len(dates), index=dates)
    values = pd.to_numeric(df.loc[idx.isin(dates), field], errors="coerce").fillna(0.0)
    values.index = list(idx[idx.isin(dates)])
    return values.reindex(dates, fill_value=0.0)


def missing_summary_default(field: str) -> float:
    if re.search(r"ROAS|SPU|CR|AOV|RPU", field) or field in {
        "Returning_Customers",
        "First_Time_Customers",
        "Returning_Customers_US",
        "Returning_Customers_EU",
        "First_Time_Customers_US",
        "First_Time_Customers_EU",
    }:
        return np.nan
    return 0.0


def mask_customer_rates_without_customers(
    revenue: pd.DataFrame, dates: list[date], *, regional: bool
) -> pd.DataFrame:
    """Keep customer-share rates blank when their customer count is zero.

    The workbook calculates first-time share as ``1 - returning share``. On an
    unreported day the returning cell is blank, but the cached first-time formula
    can therefore be 1.0. Treating that as a real 100% share would make an empty
    future day look populated and could bias averages.
    """
    groups = [
        ("Customers", ("Returning_Customers", "First_Time_Customers")),
    ]
    if regional:
        groups.extend(
            [
                ("Customers_US", ("Returning_Customers_US", "First_Time_Customers_US")),
                ("Customers_EU", ("Returning_Customers_EU", "First_Time_Customers_EU")),
            ]
        )

    date_index = pd.to_datetime(revenue["Date"]).dt.date
    selected = date_index.isin(dates)
    for count_field, rate_fields in groups:
        no_customers = numeric_series(revenue, dates, count_field).values <= 0
        for field in rate_fields:
            if field not in revenue.columns:
                continue
            values = pd.to_numeric(revenue.loc[selected, field], errors="coerce").to_numpy(copy=True)
            values[no_customers] = np.nan
            revenue.loc[selected, field] = values
    return revenue


# Last month whose Summary "Total Revenue" row already has Digital Marketplaces in it.
DM_INSIDE_SUMMARY_TOTAL_THROUGH = (2024, 11)

# November 2024 Huckberry was recorded in a separate monthly summary block instead
# of the daily Summary rows consumed by this sync. The order dates and daily order /
# unit counts come from the raw Huckberry export. The source summary is authoritative
# for the $6,664.53 monthly sales total and the 9 V1 / 12 V2 product split.
HUCKBERRY_NOVEMBER_2024 = {
    date(2024, 11, 19): (634.72, 2, 1, 1),
    date(2024, 11, 21): (634.72, 2, 1, 1),
    date(2024, 11, 24): (952.08, 3, 1, 2),
    date(2024, 11, 28): (2856.24, 8, 4, 5),
    date(2024, 11, 29): (952.08, 3, 1, 2),
    date(2024, 11, 30): (634.69, 2, 1, 1),
}

REQUIRED_REVENUE_COLS = [
    "DTC_Revenue", "DTC_Hardware", "DTC_Addons", "DTC_Merch", "DTC_Seeds", "DTC_Subscription",
    "DTC_Subscription_Taxes", "DTC_US_Subscription_Taxes", "DTC_EU_Subscription_Taxes",
    "DTC_Total_Subscription_Taxes",
    "DTC_Taxes", "DTC_Shipping", "DTC_Unallocated", "DTC_US_Unallocated", "DTC_EU_Unallocated",
    "DTC_Total_Unallocated", "DTC_Gift_Cards", "DTC_US_Gift_Cards", "DTC_EU_Gift_Cards",
    "DTC_Total_Gift_Cards", "DTC_Gift_Bag", "DTC_US_Gift_Bag", "DTC_EU_Gift_Bag",
    "DTC_Total_Gift_Bag", "DTC_Gift_Bag_Units", "DTC_US_Gift_Bag_Units", "DTC_EU_Gift_Bag_Units",
    "DTC_Total_Gift_Bag_Units", "Amazon_Revenue", "Amazon_US_Revenue", "Amazon_EU_Revenue",
    "Amazon_UK_Revenue", "Amazon_FR_Revenue", "Amazon_GER_Revenue", "Amazon_Hardware",
    "Amazon_US_Hardware", "Amazon_EU_Hardware", "Amazon_Addons", "Amazon_US_Addons",
    "Amazon_EU_Addons", "Amazon_Tax", "Amazon_US_Tax", "Amazon_EU_Tax", "Amazon_Shipping",
    "Amazon_US_Shipping", "Amazon_EU_Shipping", "Amazon_GiftWrap", "Amazon_US_GiftWrap",
    "Amazon_EU_GiftWrap", "Rachio_Revenue", "Weatherflow_Revenue", "IndieGoGo_Revenue",
    "IndieGoGo_Orders", "IndieGoGo_Hardware", "IndieGoGo_Addons", "IndieGoGo_Tax",
    "IndieGoGo_Shipping", "Digital_Marketplaces_Revenue",
    "Huckberry_Revenue", "Total_Revenue", "B2B_Revenue", "BestBuy_Revenue", "Target_Revenue",
    "Walmart_Revenue", "Costco_Revenue", "Chewy_Revenue", "Costco_Hardware", "Costco_Tax",
    "Costco_Shipping", "Retail_Revenue", "Total_Retail_Revenue", "Total_DM_Revenue",
    "Total_B2B_Revenue", "App_Revenue", "Google_Store", "Apple_Store", "App_Comission",
    "App_Tax", "DTC_Orders", "DTC_Hardware_Units", "DTC_Addons_Units", "DTC_Merch_Units",
    "DTC_Seeds_Units", "DTC_Subscription_Units", "Amazon_Orders", "Amazon_Hardware_Units",
    "Amazon_Addons_Units", "Amazon_US_Orders", "Amazon_EU_Orders", "Amazon_UK_Orders",
    "Amazon_FR_Orders", "Amazon_GER_Orders", "Amazon_US_Hardware_Units", "Amazon_EU_Hardware_Units",
    "Amazon_US_Addons_Units", "Amazon_EU_Addons_Units", "Digital_Marketplaces_Orders",
    "Rachio_Orders", "Weatherflow_Orders", "Huckberry_Orders", "Total_Orders", "B2B_Orders",
    "BestBuy_Orders", "Target_Orders", "Walmart_Orders", "Costco_Orders", "Chewy_Orders",
    "Retail_Orders", "Total_Retail_Orders", "Total_DM_Orders", "Total_B2B_Orders", "App_Orders",
    "Google_Store_Orders", "Apple_Store_Orders", "Meta_Spend", "Google_Spend", "Bing_Spend",
    "TikTok_Spend", "Snapchat_Spend", "Amazon_Spend", "Amazon_Spend_US", "Amazon_Spend_EU", "Amazon_Spend_UK",
    "Amazon_Spend_FR", "Amazon_Spend_GER", "Nextdoor_Spend", "IndieGoGo_Spend", "Affiliate_Fees",
    "Rachio_Fees", "Weatherflow_Fees", "Fees", "Costco_Fees", "BestBuy_Spend", "Target_Spend",
    "Walmart_Spend", "Chewy_Spend", "Retail_Spend", "Total_DTC_Spend", "Total_Spend",
    "App_Spend_Meta", "App_Spend_Apple", "App_Spend_Google", "Total_App_Spend", "Blended_ROAS",
    "Blended_ROAS_WO_Renewals", "Blended_ROAS_WO_Renewals_Retail", "wROAS", "wROAS_US",
    "wROAS_EU", "wROAS_WO_Renewals", "wROAS_US_WO_Renewals", "wROAS_EU_WO_Renewals",
    "aROAS", "aROAS_US", "aROAS_EU", "appROAS", "Blended_SPU", "wSPU", "wSPU_US",
    "wSPU_EU", "aSPU", "aSPU_US", "aSPU_EU", "appSPU", "Web_CR", "Web_AOV",
    "Web_AOV_WO_Renewals", "fAOV", "rAOV", "Web_RPU", "Web_RPU_US", "Web_RPU_EU",
    "Web_RPU_WO_Renewals", "Web_RPU_US_WO_Renewals", "Web_RPU_EU_WO_Renewals", "fRPU",
    "fRPU_US", "fRPU_EU", "rRPU", "rRPU_US", "rRPU_EU", "Amazon_RPU", "Amazon_RPU_US",
    "Amazon_RPU_EU", "fAOV_EUR", "rAOV_EUR", "Customers", "Customers_US", "Customers_EU",
    "Returning_Customers", "First_Time_Customers", "DTC_EU_Revenue", "DTC_EU_Hardware",
    "DTC_EU_Addons", "DTC_EU_Merch", "DTC_EU_Seeds", "DTC_EU_Subscription", "DTC_EU_Taxes",
    "DTC_EU_Shipping", "DTC_EU_Orders", "DTC_EU_Hardware_Units", "DTC_EU_Addons_Units",
    "DTC_EU_Merch_Units", "DTC_EU_Seeds_Units", "DTC_EU_Subscription_Units", "DTC_US_Revenue",
    "DTC_Total_Revenue", "DTC_US_Hardware", "DTC_Total_Hardware", "DTC_US_Addons",
    "DTC_Total_Addons", "DTC_US_Merch", "DTC_Total_Merch", "DTC_US_Seeds", "DTC_Total_Seeds",
    "DTC_US_Subscription", "DTC_Total_Subscription", "DTC_US_Taxes", "DTC_Total_Taxes",
    "DTC_US_Shipping", "DTC_Total_Shipping", "DTC_US_Orders", "DTC_Total_Orders",
    "DTC_US_Hardware_Units", "DTC_Total_Hardware_Units", "DTC_US_Addons_Units",
    "DTC_Total_Addons_Units", "DTC_US_Merch_Units", "DTC_Total_Merch_Units", "DTC_US_Seeds_Units",
    "DTC_Total_Seeds_Units", "DTC_US_Subscription_Units", "DTC_Total_Subscription_Units",
    "DTC_US_Spend", "DTC_EU_Spend", "Meta_Spend_US", "Meta_Spend_EU", "Google_Spend_US",
    "Google_Spend_EU", "DTC_Total_Spend", "Web_CR_US", "Web_CR_EU", "Web_AOV_US",
    "Web_AOV_EU", "fAOV_US", "fAOV_EU", "rAOV_US", "rAOV_EU", "Returning_Customers_US",
    "Returning_Customers_EU", "First_Time_Customers_US", "First_Time_Customers_EU",
    "Returning_US_Orders", "Returning_EU_Orders", "amazon_SKU 5 - HBF", "amazon_SKU 6 - HBF w/ Solar",
]

DTC_BASE_PRODUCTS = [
    "SKU 1 - Blue", "SKU 2 - Yellow", "SKU 3 - Blue w/ Solar", "SKU 4 - Yellow w/ Solar",
    "SKU 1 - Blue PRO", "SKU 2 - Yellow PRO", "SKU 3 - Blue w/ Solar PRO", "SKU 4 - Yellow w/ Solar PRO",
    "SKU 5 - HBF", "SKU 6 - HBF w/ Solar", "SKU 5 - HBF PRO", "SKU 6 - HBF w/ Solar PRO",
    "Smart Bird Feeder PRO Solar with PEX (Retail SKU)", "Smart Hummingbird Feeder PRO Solar (Retail SKU)",
    "Bird Buddy 2", "Birdbuddy 2 PRO", "Birdbuddy 2 Retail SKU", "Birdbuddy 2 Nectar",
    "Birdbuddy 2 Nectar PRO", "Birdbuddy 2 Mini non Solar", "Birdbuddy 2 Mini Solar", "BB2 Mini Retail SKU",
    "Pollinator Pot", "Wall Mount",
    "Suet Ball Holder", "3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow",
    "Solar Roof Single - Blue", "Solar Roof Single - Yellow", "Perch Extender - Blue", "Perch Extender - Yellow",
    "Solar Roof (HBF)", "Housing - only (HBF)", "Nature Station", "Nature Station Bloom", "Nature Cam PRO",
    "Seasonal Curation - 8lb", "Seasonal Curation - 20lb", "Buddy Bites - 8lb", "Buddy Bites - 20lb",
    "Snack n' Soar - 8lb", "Snack n' Soar - 20lb", "Avian Choice - 8lb", "Avian Choice - 20lb",
]
AMAZON_PRODUCTS = [
    "SKU 1 - Blue", "SKU 2 - Yellow", "SKU 3 - Blue w/ Solar", "SKU 4 - Yellow w/ Solar",
    "SKU 1 - Blue PRO", "SKU 2 - Yellow PRO", "SKU 3 - Blue w/ Solar PRO", "SKU 4 - Yellow w/ Solar PRO",
    "SKU 5 - HBF", "SKU 6 - HBF w/ Solar", "SKU 5 - HBF PRO", "SKU 6 - HBF w/ Solar PRO",
    "Smart Bird Feeder PRO Solar with PEX (Retail SKU)", "Smart Hummingbird Feeder PRO Solar (Retail SKU)",
    "Bird Buddy 2", "Birdbuddy 2 PRO", "Birdbuddy 2 Retail SKU", "Birdbuddy 2 Nectar",
    "Birdbuddy 2 Nectar PRO", "Birdbuddy 2 Mini non Solar", "Birdbuddy 2 Mini Solar", "BB2 Mini Retail SKU",
    "Wall Mount",
    "Suet Ball Holder", "3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow", "Solar Roof Single - Blue",
    "Solar Roof Single - Yellow", "Perch Extender - Blue", "Perch Extender - Yellow", "Nature Cam PRO",
]
CORE_SKU_PRODUCTS = [
    "SKU 1 - Blue", "SKU 2 - Yellow", "SKU 3 - Blue w/ Solar", "SKU 4 - Yellow w/ Solar",
    "SKU 1 - Blue PRO", "SKU 2 - Yellow PRO", "SKU 3 - Blue w/ Solar PRO", "SKU 4 - Yellow w/ Solar PRO",
]
BIRD_ADDON_PRODUCTS = [
    "Wall Mount", "Suet Ball Holder", "3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow",
    "Solar Roof Single - Blue", "Solar Roof Single - Yellow", "Perch Extender - Blue", "Perch Extender - Yellow",
]
BB2_PRODUCTS = [
    "Bird Buddy 2", "Birdbuddy 2 PRO", "Birdbuddy 2 Retail SKU", "Birdbuddy 2 Nectar",
    "Birdbuddy 2 Nectar PRO", "Birdbuddy 2 Mini non Solar", "Birdbuddy 2 Mini Solar", "BB2 Mini Retail SKU",
]
RETAIL_2026_PRODUCTS = [
    "SKU 5 - HBF PRO", "SKU 6 - HBF w/ Solar PRO", "Smart Bird Feeder PRO Solar with PEX (Retail SKU)",
    "Smart Hummingbird Feeder PRO Solar (Retail SKU)",
] + BB2_PRODUCTS
RETAIL_MARKETPLACE_PRODUCTS = CORE_SKU_PRODUCTS + RETAIL_2026_PRODUCTS + BIRD_ADDON_PRODUCTS
HUCKBERRY_PRODUCTS = CORE_SKU_PRODUCTS + RETAIL_2026_PRODUCTS + BIRD_ADDON_PRODUCTS

# Before July 2023 the workbooks predate the Summary tab. Daily figures live on a "Sales"
# tab and the unit detail on "Detailed Report", and the feeder had not yet been split by
# colour, so its products carry their own names. Read below "Units Sold (Gross)", which
# ties to the Sales tab's own monthly unit total.
PRE_SUMMARY_HARDWARE_PRODUCTS = ["Bird Buddy", "Bird Buddy with Solar Roof"]
PRE_SUMMARY_ADDON_PRODUCTS = [
    # Water Fountain sells in January and February 2023 only, and the 3-in-1 Nutrition Set
    # takes its place in the line-up from March, so both names have to be recognised.
    "Wall Mount", "Fence Mount", "Suet Ball Holder", "Water Fountain", "3-in-1 Nutrition Set",
    "Solar Roof Single",
]

# Through September 2022 the units block counts orders by pack size rather than the feeders
# they carry, so each row is multiplied out. The block's own "All" total floors at zero,
# which would read a day that nets out to a return as none, so the pack rows are summed here.
EARLY_UNITS_BUNDLES = [(1, "1x BB (net)"), (2, "2x BB (net)"), (3, "3x BB (net)"),
                       (5, "5x BB (net)"), (10, "10x BB (net)")]
# This era lists one Solar Roof rather than separating the feeder sold with a roof from the
# roof sold on its own, so it feeds the accessory. Water Fountain only joins in July 2022.
EARLY_UNITS_ADDONS = {
    "Solar Roof Single": "Solar Roof (net)",
    "Wall Mount": "Wall Mount (net)",
    "Fence Mount": "Fence Mount (net)",
    "Suet Ball Holder": "Suet Ball Holder (net)",
    "Water Fountain": "Water Fountain (net)",
}
# Every row in that block is booked net of the refunds settled the same day, while from
# October 2022 on the workbooks report "Units Sold (Gross)". The refunds are mostly
# Kickstarter orders being settled a year late, so netting them against a 2022 day says
# nothing about that day's selling and drove the unit count below zero on 27 days. The
# Refunds tab carries the same products a unit at a time, so the deduction is added back
# and the era lands on the gross footing the rest of the series is on.
EARLY_REFUND_DATE_HEADERS = ("Date of refund", "Date")
# Refund tab heading -> the product name the units block uses.
EARLY_REFUND_PRODUCTS = {
    "Bird Buddy": "Bird Buddy",
    "Solar Roof": "Solar Roof Single",
    "Wall Mount": "Wall Mount",
    "Fence Mount": "Fence Mount",
    "Suet Ball Holder": "Suet Ball Holder",
    "Water Fountain": "Water Fountain",
}

PRODUCT_LABEL_ALIASES = {
    "SKU 1 - Blue PRO": ["Smart Bird Feeder PRO"],
    "SKU 3 - Blue w/ Solar PRO": ["Smart Bird Feeder PRO Solar"],
    "SKU 5 - HBF PRO": ["Smart Hummingbird Feeder PRO"],
    "SKU 6 - HBF w/ Solar PRO": ["Smart Hummingbird Feeder PRO Solar"],
    "Bird Buddy 2": ["Birdbuddy 2"],
    "Nature Station": ["Nature Station Essential"],
}

for suffix in DTC_BASE_PRODUCTS + PRE_SUMMARY_HARDWARE_PRODUCTS + PRE_SUMMARY_ADDON_PRODUCTS:
    REQUIRED_REVENUE_COLS.extend([f"dtc_{suffix}", f"dtc_us_{suffix}", f"dtc_eu_{suffix}"])
for suffix in AMAZON_PRODUCTS:
    REQUIRED_REVENUE_COLS.extend([f"amazon_{suffix}", f"amazon_us_{suffix}", f"amazon_eu_{suffix}"])
for suffix in RETAIL_MARKETPLACE_PRODUCTS:
    REQUIRED_REVENUE_COLS.extend([f"walmart_{suffix}", f"costco_{suffix}"])
for suffix in HUCKBERRY_PRODUCTS:
    REQUIRED_REVENUE_COLS.append(f"huckberry_{suffix}")
for suffix in CORE_SKU_PRODUCTS:
    REQUIRED_REVENUE_COLS.extend([f"rachio_{suffix}", f"weatherflow_{suffix}"])
REQUIRED_REVENUE_COLS.extend(["apple_yearly_sub", "apple_monthly_sub", "google_yearly_sub", "google_monthly_sub"])


def find_product_label(sheet: list[list[Any]], product: str, after: int = 1, before: float = math.inf) -> tuple[int | None, str]:
    for label in [product] + PRODUCT_LABEL_ALIASES.get(product, []):
        row = find_label(sheet, label, after=after, before=before)
        if row is not None:
            return row, label
    return None, product


def put_sheet_row(
    df: pd.DataFrame,
    sheet: list[list[Any]],
    cols: list[int],
    dates: list[date],
    file: Path,
    sheet_name: str,
    field: str,
    label: str,
    log: SyncLog,
    occurrence: int | str = 1,
    contains: bool = False,
    default: float = 0.0,
    after: int = 1,
) -> pd.DataFrame:
    row = find_label(sheet, label, occurrence=occurrence, contains=contains, after=after)
    if row is None:
        values = [default] * len(dates)
        log.skip(file, sheet_name, field, f"missing label {label}")
    else:
        values = row_values(sheet, row, cols)
        log.source(dates, file, sheet_name, field, f"row {row}: {label}")
    return put_values(df, dates, field, values)


def fill_pre_summary(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    """A month from before the Summary tab existed, read off "Sales" and "Detailed Report".

    The headline comes off "Sales", which agrees with "Detailed Report" to the cent. The
    component lines come off the revenue-by-country block, which does not: it misses the
    day's platform revenue by around a percent most days. That shortfall is carried on its
    own line so the breakdown still adds up to the headline it sits under.
    """
    file = wb.path
    if "Summary" in wb.sheet_names():
        return revenue
    sales = wb.read_sheet("Sales", rows=(1, 60), max_col=45)
    if sales is None:
        log.skip(file, "Sales", "pre_summary", "sheet missing")
        return revenue
    cols = date_cols(sales, dates)
    if cols is None:
        log.skip(file, "Sales", "date columns", f"missing date {dates[0]}")
        return revenue

    # Through October 2021 the tab carries an Indiegogo line beside the Shopify one and adds
    # the two into Total Revenue. The crowdfunder is its own channel here, so the store's own
    # takings come off the Shopify row and Indiegogo is booked separately below. From November
    # 2021, once the campaign had run its course, the two rows say the same thing.
    store_row = "Shopify" if find_label(sales, "Shopify") else "Total Revenue"

    # The monthly goal block repeats several of these labels lower down, with its total
    # sitting in the same column as the first of the month, so take the first match only.
    for field, label in {
        "DTC_Revenue": store_row,
        "DTC_Orders": "Orders",
        "Meta_Spend": "FB - US & CA",
        "Google_Spend": "Google - WW",
        "Bing_Spend": "Bing - WW",
        "TikTok_Spend": "TikTok - US & CA",
        "Affiliate_Fees": r"^Affiliate Fees",
        "Total_Spend": "Total Spend",
        "Total_DTC_Spend": "Total Spend",
        "Blended_ROAS": "ROAS",
        "wROAS": "ROAS",
        "Blended_SPU": "Spend per Unit",
        "wSPU": "Spend per Unit",
        "Web_CR": "CR",
        "Web_AOV": "AOV",
        "fAOV": "fAOV",
        "rAOV": "rAOV",
        "Returning_Customers": "Returning",
        "First_Time_Customers": "First-time",
    }.items():
        revenue = put_sheet_row(revenue, sales, cols, dates, file, "Sales", field, label, log,
                                contains=label.startswith("^"), default=missing_summary_default(field))

    indiegogo_row = find_label(sales, "Indiegogo")
    if indiegogo_row:
        log.source(dates, file, "Sales", "IndieGoGo_Revenue", f"row {indiegogo_row}: Indiegogo")
        revenue = put_values(revenue, dates, "IndieGoGo_Revenue", row_values(sales, indiegogo_row, cols))

    # Two Facebook lines run side by side in mid-2021, split by who placed the media rather
    # than by audience, and the tab's own spend total adds both.
    internal_row = find_label(sales, "FB - Internal Paid")
    if internal_row:
        log.source(dates, file, "Sales", "Meta_Spend", f"row {internal_row}: FB - Internal Paid, added to FB - US & CA")
        revenue = put_values(revenue, dates, "Meta_Spend",
                             numeric_series(revenue, dates, "Meta_Spend").to_numpy(dtype=float)
                             + np.array(row_values(sales, internal_row, cols), dtype=float))

    # August 2021 names its TikTok line without the region the later tabs carry. The survey
    # block further down answers to the same name, so the search stops at the spend subtotal.
    if find_label(sales, "TikTok - US & CA") is None:
        spend_total = find_label(sales, "Total Spend")
        tiktok_row = find_label(sales, "TikTok", before=spend_total) if spend_total else None
        if tiktok_row:
            log.source(dates, file, "Sales", "TikTok_Spend", f"row {tiktok_row}: TikTok")
            revenue = put_values(revenue, dates, "TikTok_Spend", row_values(sales, tiktok_row, cols))

    revenue = put_sheet_row(revenue, sales, cols, dates, file, "Sales", "Total_Revenue", "Total Revenue", log)
    revenue = put_values(revenue, dates, "Total_Orders", numeric_series(revenue, dates, "DTC_Orders").values)

    revenue = fill_pre_summary_units(revenue, wb, dates, log)
    revenue = fill_pre_summary_parts(revenue, wb, dates, log)

    # January 2023 reports CAC, which is spend over orders, where every other month reports
    # spend per unit. They are different measures, so rather than read one as the other the
    # month's SPU is rebuilt the way the later tabs compute it: to the cent in all five
    # months that publish both, it is total spend over hardware units.
    if find_label(sales, "Spend per Unit") is None:
        spend = numeric_series(revenue, dates, "Total_Spend").to_numpy(dtype=float)
        # The hardware total is rolled up later, so the product columns are added here.
        units = sum(numeric_series(revenue, dates, f"dtc_{product}").to_numpy(dtype=float)
                    for product in PRE_SUMMARY_HARDWARE_PRODUCTS)
        spu = np.divide(spend, units, out=np.full(len(dates), np.nan), where=units > 0)
        log.source(dates, file, "Sales", "Blended_SPU", "no Spend per Unit row; spend over hardware units")
        for field in ["Blended_SPU", "wSPU"]:
            revenue = put_values(revenue, dates, field, spu)

    # The region split on this era's tabs runs NA / Europe / ROW, which has no home in the
    # app, so the month is booked as US the same way every other pre-Oct-2024 month is.
    for field in ["DTC_US_Revenue", "DTC_US_Orders", "Web_CR_US", "Web_AOV_US", "fAOV_US", "rAOV_US",
                  "Returning_Customers_US", "First_Time_Customers_US"]:
        base = field.replace("_US", "")
        if base in revenue.columns:
            revenue = put_values(revenue, dates, field, numeric_series(revenue, dates, base).values)
    spend = numeric_series(revenue, dates, "Total_DTC_Spend").values
    for field in ["DTC_US_Spend", "DTC_Total_Spend"]:
        revenue = put_values(revenue, dates, field, spend)
    for field in ["DTC_EU_Revenue", "DTC_EU_Orders", "DTC_EU_Spend", "Meta_Spend_EU", "Google_Spend_EU"]:
        revenue = put_values(revenue, dates, field, [0.0] * len(dates))
    for field in ["Meta_Spend_US", "Google_Spend_US"]:
        revenue = put_values(revenue, dates, field, numeric_series(revenue, dates, field.replace("_US", "")).values)
    for field in ["Web_CR_EU", "Web_AOV_EU", "fAOV_EU", "rAOV_EU", "Returning_Customers_EU", "First_Time_Customers_EU"]:
        revenue = put_values(revenue, dates, field, [np.nan] * len(dates))
    return revenue


def fill_pre_summary_parts(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    """Hardware, add-ons, tax and shipping revenue for a pre-Summary month.

    Hardware and add-ons are summed from the per-region component rows rather than the
    block's own "All" subtotals, which are unreliable: June's add-ons subtotal for North
    America leaves out a day of Wall Mount. Whatever is left over against the headline goes
    to DTC_Unallocated, so no product line is credited with revenue it cannot account for.
    """
    sheet_name = "Detailed Report"
    sheet = wb.read_sheet(sheet_name, rows=(1, 290), max_col=45)
    if sheet is None:
        log.skip(wb.path, sheet_name, "pre_summary_parts", "sheet missing")
        return revenue
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
        return revenue

    for field, label in [("DTC_Taxes", "Tax Shopify"), ("DTC_Shipping", "Shipping Shopify")]:
        revenue = put_sheet_row(revenue, sheet, cols, dates, wb.path, sheet_name, field, label, log)

    # Through September 2022 there is no such block, so hardware and add-on revenue cannot be
    # separated out at all and the whole of it falls to the residual below. The units for
    # those months still come through, from a block of their own.
    start = find_label(sheet, "Revenue by country (Gross)")
    if start is None:
        log.skip(wb.path, sheet_name, "pre_summary_parts",
                 "no Revenue by country (Gross) section; hardware and add-on revenue fall to Unallocated")
    else:
        end = section_end(sheet, start, ("Units Refunded by country",))
        # Only the rows carrying a region qualify, which is what separates a component from the
        # "All ..." subtotal sitting beside it. The spacing around the dash varies by row.
        regions = r"\s*-\s*(NA|Europe|ROW)\b"
        groups = {
            "DTC_Hardware": rf"^({'|'.join(PRE_SUMMARY_HARDWARE_PRODUCTS)}){regions}",
            "DTC_Addons": rf"^({'|'.join(PRE_SUMMARY_ADDON_PRODUCTS)}){regions}",
        }
        for field, pattern in groups.items():
            total = np.zeros(len(dates), dtype=float)
            matched = 0
            for idx, text in enumerate(labels(sheet), start=1):
                if start < idx <= end and re.match(pattern, text, re.IGNORECASE):
                    total += np.array(row_values(sheet, idx, cols), dtype=float)
                    matched += 1
            if not matched:
                log.skip(wb.path, sheet_name, field, "no per-region component rows matched")
                continue
            log.source(dates, wb.path, sheet_name, field, f"{matched} per-region rows after row {start}")
            revenue = put_values(revenue, dates, field, total)

        # Gift cards sell $22-30k a month through to May 2023 and are reported in this block
        # without a region, so they are named here rather than left to swell the residual.
        gift_row = find_label(sheet, r"^Gift Cards?$", contains=True, after=start + 1, before=end)
        gift = row_values(sheet, gift_row, cols) if gift_row else [0.0] * len(dates)
        if gift_row:
            log.source(dates, wb.path, sheet_name, "DTC_Gift_Cards", f"row {gift_row}: Gift Card")
        revenue = put_values(revenue, dates, "DTC_Gift_Cards", gift)

    parts = sum(numeric_series(revenue, dates, field).values
                for field in ["DTC_Hardware", "DTC_Addons", "DTC_Taxes", "DTC_Shipping", "DTC_Gift_Cards"])
    residual = numeric_series(revenue, dates, "DTC_Revenue").values - parts
    log.source(dates, wb.path, sheet_name, "DTC_Unallocated", "headline less the component lines")
    return put_values(revenue, dates, "DTC_Unallocated", residual)


def fill_pre_summary_units(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    # September 2022 changes over to the gross tab mid-month and keeps both: the old one
    # stops being filled in after the 14th, so its last fortnight reads as no sales at all.
    # The newer tab carries the whole month, and is preferred wherever it is present.
    sheet_name = "Detailed Report"
    sheet = None
    if "(New) Detailed Report" in wb.sheet_names():
        candidate = wb.read_sheet("(New) Detailed Report", rows=(1, 210), max_col=45)
        if candidate is not None and find_label(candidate, "Units Sold (Gross)") is not None:
            sheet_name, sheet = "(New) Detailed Report", candidate
            log.source(dates, wb.path, sheet_name, "pre_summary_units", "gross units tab preferred over the retired Detailed Report")
    if sheet is None:
        sheet = wb.read_sheet(sheet_name, rows=(1, 210), max_col=45)
    if sheet is None:
        log.skip(wb.path, sheet_name, "pre_summary_units", "sheet missing")
        return revenue
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
        return revenue
    start = find_label(sheet, "Units Sold (Gross)")
    if start is None:
        return fill_early_units(revenue, wb, sheet, sheet_name, cols, dates, log)
    end = section_end(sheet, start, ("First-time Customers",))
    for product in PRE_SUMMARY_HARDWARE_PRODUCTS + PRE_SUMMARY_ADDON_PRODUCTS:
        row = find_label(sheet, product, after=start + 1, before=end)
        if row is None:
            log.skip(wb.path, sheet_name, f"dtc_{product}", f"missing label {product} in units block")
            continue
        values = row_values(sheet, row, cols)
        log.source(dates, wb.path, sheet_name, f"dtc_{product}", f"row {row}: {product}")
        revenue = put_dtc_units(revenue, dates, product, values)
    return revenue


def put_dtc_units(revenue: pd.DataFrame, dates: list[date], product: str, values: Sequence[float]) -> pd.DataFrame:
    """A product's units, booked as US the way every other pre-Oct-2024 month is."""
    revenue = put_values(revenue, dates, f"dtc_{product}", values)
    revenue = put_values(revenue, dates, f"dtc_us_{product}", values)
    return put_values(revenue, dates, f"dtc_eu_{product}", [0.0] * len(dates))


def early_refund_units(wb: WorkbookCache, dates: list[date], log: SyncLog) -> dict[str, np.ndarray]:
    """Units refunded per day, to put back on top of a net units block.

    Returns an empty mapping when the tab cannot supply them, which leaves the caller on
    the net figures rather than on a half-corrected count.
    """
    sheet_name = "Refunds"
    sheet = wb.read_sheet(sheet_name, max_col=42)
    if not sheet:
        log.skip(wb.path, sheet_name, "early_refund_units", "no Refunds tab to restore the netted units from")
        return {}
    header = [str(value).strip() if value is not None else "" for value in sheet[0]]
    date_col = next((idx for idx, name in enumerate(header) if name in EARLY_REFUND_DATE_HEADERS), None)
    product_cols = {idx: EARLY_REFUND_PRODUCTS[name] for idx, name in enumerate(header) if name in EARLY_REFUND_PRODUCTS}
    if date_col is None and product_cols and any(as_date_cell(row[0]) for row in sheet[1:20] if row):
        # February 2022 has an email address typed over the heading. The refund date is the
        # first column on every one of these tabs, so it is read when the dates are there.
        date_col = 0
        log.source(dates, wb.path, sheet_name, "early_refund_units", "date heading overwritten; read the first column")
    if date_col is None or not product_cols:
        # The 2021 tabs log a refund's value but not the products in it, so those months
        # keep their net units and are reported here rather than passing as gross.
        log.skip(wb.path, sheet_name, "early_refund_units", "refund rows carry no per-product units")
        return {}

    month = {(d.year, d.month) for d in dates}
    wanted = {d: idx for idx, d in enumerate(dates)}
    out = {product: np.zeros(len(dates), dtype=float) for product in product_cols.values()}
    placed = swapped = outside = 0
    for row in sheet[1:]:
        if date_col >= len(row):
            continue
        stamp = as_date_cell(row[date_col])
        if stamp is None:
            continue
        if (stamp.year, stamp.month) not in month:
            # Through June 2022 the tab holds day-first dates that read as month-first, so
            # the 3rd of May arrives as the 5th of March. Only a swap that lands back
            # inside the month the workbook covers is taken, which leaves a genuine
            # neighbouring-month refund alone instead of dragging it into this one.
            try:
                alt = date(stamp.year, stamp.day, stamp.month)
            except ValueError:
                alt = None
            if alt is None or (alt.year, alt.month) not in month:
                outside += 1
                continue
            stamp, swapped = alt, swapped + 1
        slot = wanted.get(stamp)
        if slot is None:
            outside += 1
            continue
        placed += 1
        for idx, product in product_cols.items():
            # Strictly numbers: a stray date cell reads as a five-figure day count through
            # as_num, and the value column on these tabs does carry one here and there.
            cell = row[idx] if idx < len(row) else None
            if isinstance(cell, bool) or not isinstance(cell, (int, float)) or math.isnan(cell):
                continue
            out[product][slot] += float(cell)

    if not placed:
        log.skip(wb.path, sheet_name, "early_refund_units", "no refund rows fall inside the month")
        return {}
    note = f"{placed} refund rows added back to the net units"
    if swapped:
        note += f" ({swapped} on day-first dates)"
    if outside:
        note += f"; {outside} dated outside the month and left out"
    log.source(dates, wb.path, sheet_name, "early_refund_units", note)
    return out


def fill_early_units(revenue: pd.DataFrame, wb: WorkbookCache, sheet: list[list[Any]], sheet_name: str,
                     cols: list[int], dates: list[date], log: SyncLog) -> pd.DataFrame:
    """Units for a month whose block counts packs sold rather than the products in them.

    The block is net of refunds, so the refunded units are added back to leave the same
    gross count the "Units Sold (Gross)" months report.
    """
    start = find_label(sheet, "Units Sold")
    if start is None:
        log.skip(wb.path, sheet_name, "pre_summary_units", "missing Units Sold section")
        return revenue
    # The block runs to the costing section below it; a couple of these names head rows
    # further down the tab, so the search stops at its end.
    end = find_label(sheet, "Cost", after=start + 1) or (start + 20)
    refunds = early_refund_units(wb, dates, log)
    zero = np.zeros(len(dates), dtype=float)

    feeders = np.zeros(len(dates), dtype=float)
    packs = []
    for size, label in EARLY_UNITS_BUNDLES:
        row = find_label(sheet, label, after=start + 1, before=end)
        if row is None:
            continue
        feeders += size * np.array(row_values(sheet, row, cols), dtype=float)
        packs.append(f"{label} x{size}")
    if packs:
        note = f"packs multiplied out to feeders: {', '.join(packs)}"
        gross = feeders + refunds.get("Bird Buddy", zero)
        if "Bird Buddy" in refunds:
            note += f"; {refunds['Bird Buddy'].sum():.0f} refunded units added back"
        log.source(dates, wb.path, sheet_name, "dtc_Bird Buddy", note)
        revenue = put_dtc_units(revenue, dates, "Bird Buddy", gross)
    else:
        log.skip(wb.path, sheet_name, "dtc_Bird Buddy", "no pack rows under the units block")

    for product, label in EARLY_UNITS_ADDONS.items():
        row = find_label(sheet, label, after=start + 1, before=end)
        if row is None:
            log.skip(wb.path, sheet_name, f"dtc_{product}", f"missing label {label} in units block")
            continue
        note = f"row {row}: {label}"
        gross = np.array(row_values(sheet, row, cols), dtype=float) + refunds.get(product, zero)
        if product in refunds:
            note += f"; {refunds[product].sum():.0f} refunded units added back"
        log.source(dates, wb.path, sheet_name, f"dtc_{product}", note)
        revenue = put_dtc_units(revenue, dates, product, gross)
    return revenue


# October-December 2025 reuse a retired channel's row for Snapchat and leave the old name
# in brackets: "Snapchat Spend (TikTok Spend stopped)", "Snapchat Spend (BestBuy Spend
# stopped)". Both patterns are anchored so the bracketed name never reads as that channel.
SNAPCHAT_SPEND_LABEL = r"^Snapchat Spend"
BESTBUY_SPEND_LABEL = r"^Best ?Buy Spend$"


def fill_summary(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    file = wb.path
    sheet_name = "Summary"
    sheet = wb.read_sheet(sheet_name, rows=(1, 280), max_col=45)
    if sheet is None:
        return revenue
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(file, sheet_name, "date columns", f"missing date {dates[0]}")
        return revenue
    old = not uses_regional_dtc(file)
    summary_map = {
        "DTC_Revenue": "DTC Revenue",
        "Amazon_Revenue": "Amazon Revenue",
        "Amazon_US_Revenue": "Amazon Revenue US",
        "Amazon_EU_Revenue": "Amazon Revenue EU",
        "Amazon_UK_Revenue": "Amazon Revenue UK",
        "Amazon_FR_Revenue": "Amazon Revenue FR",
        "Amazon_GER_Revenue": "Amazon Revenue GER",
        "Walmart_Revenue": "Walmart" if old else r"^Walmart( Revenue)?$",
        "Digital_Marketplaces_Revenue": "Digital Marketplaces Revenue",
        "Rachio_Revenue": "Rachio",
        "Weatherflow_Revenue": "Weatherflow",
        # Listed inside the Summary's marketplace block but left out of its subtotal,
        # so it is carried as its own channel rather than folded into Digital Marketplaces.
        "IndieGoGo_Revenue": "IndieGoGo",
        "Huckberry_Revenue": "Huckberry",
        "Costco_Revenue": "Costco",
        "Chewy_Revenue": "Chewy",
        "Total_Revenue": "Total Revenue",
        "B2B_Revenue": "B2B Revenue",
        "Retail_Revenue": "Total Retail Revenue",
        "Total_Retail_Revenue": "Total Retail Revenue",
        "Total_DM_Revenue": "Total DM Revenue",
        "Total_B2B_Revenue": "Total B2B Revenue",
        "BestBuy_Revenue": "Best Buy",
        "Target_Revenue": "Target",
        "App_Revenue": "App Revenue",
        "Google_Store": "- Google Store",
        "Apple_Store": "- Apple Store",
        "App_Comission": "- Comission",
        "App_Tax": "- Tax",
        "DTC_Orders": "DTC Orders",
        "Amazon_Orders": "Amazon Orders",
        "Amazon_US_Orders": "- Amazon Orders US",
        "Amazon_EU_Orders": "- Amazon Orders EU",
        "Amazon_UK_Orders": "Amazon Orders UK",
        "Amazon_FR_Orders": "Amazon Orders FR",
        "Amazon_GER_Orders": "Amazon Orders GER",
        "Walmart_Orders": r"^Walmart( Orders)?$",
        "Digital_Marketplaces_Orders": "Digital Marketplaces Orders",
        "IndieGoGo_Orders": "IndieGoGo Orders",
        "Rachio_Orders": r"^Rachio( Orders)?$",
        "Weatherflow_Orders": r"^Weatherflow( Orders)?$",
        "Huckberry_Orders": r"^Huckberry( Orders)?$",
        "Costco_Orders": r"^Costco( Orders)?$",
        "Chewy_Orders": r"^Chewy( Orders)?$",
        "Total_Orders": "Total Orders",
        "B2B_Orders": "B2B Orders",
        "Retail_Orders": "Total Retail Orders",
        "Total_Retail_Orders": "Total Retail Orders",
        "Total_DM_Orders": "Total DM Orders",
        "Total_B2B_Orders": "Total B2B Orders",
        "BestBuy_Orders": "Best Buy",
        "Target_Orders": "Target",
        "App_Orders": "App Orders",
        "Google_Store_Orders": "- Google Store",
        "Apple_Store_Orders": "- Apple Store",
        "Meta_Spend": "Meta Spend",
        "Google_Spend": "Google Spend",
        "Bing_Spend": "Bing Spend",
        "TikTok_Spend": "TikTok Spend",
        "Snapchat_Spend": SNAPCHAT_SPEND_LABEL,
        "Amazon_Spend": "Amazon Spend",
        "Amazon_Spend_US": "- Amazon Spend US",
        "Amazon_Spend_UK": "- Amazon Spend UK",
        "Amazon_Spend_FR": "- Amazon Spend FR",
        "Amazon_Spend_GER": "- Amazon Spend GER",
        "BestBuy_Spend": BESTBUY_SPEND_LABEL,
        "Target_Spend": "Target Spend",
        "Walmart_Spend": "Walmart Spend",
        "Chewy_Spend": "Chewy Spend",
        "Nextdoor_Spend": "Nextdoor Spend",
        "IndieGoGo_Spend": "IndieGoGo Spend",
        "Affiliate_Fees": "Affiliate Fees",
        "Rachio_Fees": "Rachio Fees",
        "Weatherflow_Fees": "Weatherflow Fees",
        "Costco_Fees": "Costco Fees",
        "Total_DTC_Spend": "Total DTC Spend",
        "Total_Spend": "Total Spend",
        "App_Spend_Meta": "Meta Spend",
        "App_Spend_Apple": "Apple Spend",
        "App_Spend_Google": "Google Spend",
        "Total_App_Spend": "Total APP Spend",
        "Blended_ROAS": "Blended ROAS",
        "Blended_ROAS_WO_Renewals": "Blended ROAS (w/o renewals)",
        "Blended_ROAS_WO_Renewals_Retail": "Blended ROAS (w/o renewals) & Retail",
        "wROAS": "wROAS",
        "wROAS_WO_Renewals": "wROAS (w/o renewals)",
        "aROAS": "aROAS",
        "appROAS": "appROAS",
        "Blended_SPU": r"^(Blended )?Spend per Unit$",
        # July 2023 spells wSPU out in full; every later workbook uses the abbreviation.
        "wSPU": r"^(wSPU|Web Spend per Unit)$",
        "aSPU": "aSPU",
        "appSPU": "appCAC",
        "Web_CR": "Web CR",
        "Web_AOV": "Web AOV",
        "Web_AOV_WO_Renewals": "Web AOV (w/o renewals)",
        "fAOV": r"^(Web )?fAOV$",
        "rAOV": r"^(Web )?rAOV$",
        "Web_RPU": "Web Revenue per Unit",
        "Web_RPU_WO_Renewals": "Web Revenue per Unit (w/o renewals)",
        "fRPU": "Web fRPU",
        "rRPU": "Web rRPU",
        "Amazon_RPU": "Amazon Revenue per Unit",
        "fAOV_EUR": "fAOV EUR",
        "rAOV_EUR": "rAOV EUR",
        "Customers": "Customers",
        "Returning_Customers": "Returning",
        "First_Time_Customers": "First-time",
        "Returning_US_Orders": "Returning US Orders",
        "Returning_EU_Orders": "Returning EU Orders",
    }
    contains_fields = {
        "Walmart_Revenue", "Walmart_Orders", "Costco_Orders", "Chewy_Orders", "Rachio_Orders",
        "Weatherflow_Orders", "Huckberry_Orders", "Digital_Marketplaces_Revenue",
        "Digital_Marketplaces_Orders", "Blended_SPU", "fAOV", "rAOV",
    }
    # The app block reuses labels that other blocks also carry, so its fields are read
    # from inside the block rather than by counting occurrences. Before Sep 2023 there is
    # no app block at all, and an unanchored "- Tax" would otherwise pick up Amazon's.
    app_anchors = {
        "Google_Store": "App Revenue",
        "Apple_Store": "App Revenue",
        "App_Comission": "App Revenue",
        "App_Tax": "App Revenue",
        "Google_Store_Orders": "App Orders",
        "Apple_Store_Orders": "App Orders",
    }
    for field, label in summary_map.items():
        occurrence: int | str = 1
        anchor = app_anchors.get(field)
        after = 1
        if anchor is not None:
            anchor_row = find_label(sheet, anchor)
            if anchor_row is None:
                revenue = put_values(revenue, dates, field, [missing_summary_default(field)] * len(dates))
                log.skip(file, sheet_name, field, f"missing block {anchor}")
                continue
            after = anchor_row + 1
        if field in {"App_Spend_Meta", "App_Spend_Google"}:
            occurrence = "last"
        if field in {"BestBuy_Orders", "Target_Orders",
                     "Walmart_Orders", "Costco_Orders", "Chewy_Orders", "Rachio_Orders",
                     "Weatherflow_Orders", "Huckberry_Orders"}:
            occurrence = 2
        if field == "Digital_Marketplaces_Revenue":
            label = r"Digital Marketplaces.*Revenue"
        if field == "Digital_Marketplaces_Orders":
            label = r"Digital Marketplaces.*Orders"
        contains = field in contains_fields or label.startswith("^")
        revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, field, label, log,
                                occurrence=occurrence, contains=contains, default=missing_summary_default(field),
                                after=after)

    # Blocks spell the tax line either way, and not every block carries every component.
    SUBSECTION_LABELS = {
        "Hardware": ("- Hardware",),
        "Addons": ("- Add-ons",),
        "Tax": ("- Tax", "- Taxes"),
        "Shipping": ("- Shipping",),
        "GiftWrap": ("- Gift Wrap",),
    }

    def fill_subsection(anchor_label: str, prefix: str, before_label: str | None,
                        names: Iterable[str] | None = None) -> None:
        nonlocal revenue
        start = find_label(sheet, anchor_label)
        if start is None:
            return
        end = len(sheet)
        if before_label:
            before = find_label(sheet, before_label, after=start + 1)
            if before is not None:
                end = before - 1
        wanted = SUBSECTION_LABELS if names is None else {name: SUBSECTION_LABELS[name] for name in names}
        for name, sublabels in wanted.items():
            field = f"{prefix}_{name}"
            row = matched = None
            for candidate in sublabels:
                row = find_label(sheet, candidate, after=start + 1, before=end)
                if row is not None:
                    matched = candidate
                    break
            if row is None:
                revenue = put_values(revenue, dates, field, [0.0] * len(dates))
                log.skip(file, sheet_name, field, f"missing label {sublabels[0]} after {anchor_label}")
            else:
                revenue = put_values(revenue, dates, field, row_values(sheet, row, cols))
                log.source(dates, file, sheet_name, field, f"row {row}: {matched} after {anchor_label}")

    fill_subsection("Amazon Revenue US", "Amazon_US", "Amazon Revenue EU")
    fill_subsection("Amazon Revenue EU", "Amazon_EU", "Total Revenue")
    fill_subsection("IndieGoGo", "IndieGoGo", "Total Revenue", names=("Hardware", "Addons", "Tax", "Shipping"))

    if not old:
        regional_map = {
            "DTC_US_Revenue": r"^- DTC Revenue US&CA", "DTC_EU_Revenue": r"^- DTC Revenue EU",
            "DTC_US_Orders": "- DTC Orders US&CA", "DTC_EU_Orders": "- DTC Orders EUROPE",
            "DTC_US_Spend": "- DTC Spend US", "DTC_EU_Spend": "- DTC Spend EU",
            "Meta_Spend_US": "- Meta US", "Meta_Spend_EU": "- Meta EU",
            "Google_Spend_US": "- Google Spend US", "Google_Spend_EU": "- Google Spend EU",
            "Web_CR_US": "- Web CR US", "Web_CR_EU": "- Web CR EU",
            "Web_AOV_US": "- Web AOV US", "Web_AOV_EU": "- Web AOV EU",
            "Web_AOV_US_WO_Renewals": "- Web AOV US (w/o renewals)",
            "Web_AOV_EU_WO_Renewals": "- Web AOV EU (w/o renewals)",
            "fAOV_US": r"^- (fAOV|First-time) US$", "fAOV_EU": r"^- (fAOV|First-time) EU$",
            "rAOV_US": "^- rAOV US$", "rAOV_EU": "^- rAOV EU$",
            "wROAS_US": "- wROAS US", "wROAS_EU": "- wROAS EU",
            "wROAS_US_WO_Renewals": "- wROAS US (w/o renewals)",
            "wROAS_EU_WO_Renewals": "- wROAS EU (w/o renewals)",
            "aROAS_US": "- aROAS US", "aROAS_EU": "- aROAS EU",
            "wSPU_US": "- wSPU US", "wSPU_EU": "- wSPU EU",
            "aSPU_US": "- aSPU US", "aSPU_EU": "- aSPU EU",
            "Web_RPU_US": "- Web Revenue per Unit US", "Web_RPU_EU": "- Web Revenue per Unit EU",
            "Web_RPU_US_WO_Renewals": "- Web Revenue per Unit US (w/o renewals)",
            "Web_RPU_EU_WO_Renewals": "- Web Revenue per Unit EU (w/o renewals)",
            "fRPU_US": "- fRPU US", "fRPU_EU": "- fRPU EU",
            "rRPU_US": "- rRPU US", "rRPU_EU": "- rRPU EU",
            "Amazon_RPU_US": "- Amazon Revenue per Unit US", "Amazon_RPU_EU": "- Amazon Revenue per Unit EU",
            "Customers_US": "- Customers US", "Customers_EU": "- Customers EU",
            "Returning_Customers_US": "- Returning US", "Returning_Customers_EU": "- Returning EU",
            "First_Time_Customers_US": "^- First-time US$", "First_Time_Customers_EU": "^- First-time EU$",
        }
        for field, label in regional_map.items():
            revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, field, label, log,
                                    contains=label.startswith("^"), default=missing_summary_default(field))
        revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "DTC_US_Subscription_Units", "- BB 1 year Pro Subscription", log, occurrence=1)
        revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "DTC_EU_Subscription_Units", "- BB 1 year Pro Subscription", log, occurrence=2)
        revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "DTC_US_Gift_Bag_Units", "- Gift Bag", log, occurrence=2)
        has_amazon_region = find_label(sheet, "Amazon Revenue US") is not None or find_label(sheet, "- Amazon Orders US") is not None
        if has_amazon_region:
            revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "Amazon_US_Hardware_Units", "- Hardware (units sold)", log, occurrence=3)
            revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "Amazon_US_Addons_Units", "- Add-ons (units sold)", log, occurrence=3)
            revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "Amazon_EU_Hardware_Units", "- Hardware (units sold)", log, occurrence=4)
            revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "Amazon_EU_Addons_Units", "- Add-ons (units sold)", log, occurrence=4)
        else:
            for field in ["Amazon_US_Hardware_Units", "Amazon_US_Addons_Units", "Amazon_EU_Hardware_Units", "Amazon_EU_Addons_Units"]:
                revenue = put_values(revenue, dates, field, [0.0] * len(dates))
    else:
        for field in ["DTC_US_Revenue", "DTC_US_Orders", "DTC_US_Spend", "Meta_Spend_US", "Google_Spend_US",
                      "Web_CR_US", "Web_AOV_US", "fAOV_US", "rAOV_US", "Returning_Customers_US", "First_Time_Customers_US"]:
            base = field.replace("_US", "")
            if base in revenue.columns:
                revenue = put_values(revenue, dates, field, numeric_series(revenue, dates, base).values)
        if "Total_DTC_Spend" in revenue.columns:
            vals = numeric_series(revenue, dates, "Total_DTC_Spend").values
            revenue = put_values(revenue, dates, "DTC_US_Spend", vals)
            revenue = put_values(revenue, dates, "DTC_Total_Spend", vals)
        for field in ["DTC_EU_Revenue", "DTC_EU_Orders", "DTC_EU_Spend", "Meta_Spend_EU", "Google_Spend_EU"]:
            revenue = put_values(revenue, dates, field, [0.0] * len(dates))
        revenue = put_sheet_row(revenue, sheet, cols, dates, file, sheet_name, "DTC_US_Subscription_Units", "- BB 1 year Pro Subscription", log, occurrence=1)
        revenue = put_values(revenue, dates, "DTC_EU_Subscription_Units", [0.0] * len(dates))
        revenue = put_values(revenue, dates, "Amazon_US_Hardware_Units", numeric_series(revenue, dates, "Amazon_Hardware_Units").values)
        revenue = put_values(revenue, dates, "Amazon_US_Addons_Units", numeric_series(revenue, dates, "Amazon_Addons_Units").values)
        revenue = put_values(revenue, dates, "Amazon_EU_Hardware_Units", [0.0] * len(dates))
        revenue = put_values(revenue, dates, "Amazon_EU_Addons_Units", [0.0] * len(dates))
        for field in ["Web_CR_EU", "Web_AOV_EU", "fAOV_EU", "rAOV_EU", "Returning_Customers_EU", "First_Time_Customers_EU"]:
            revenue = put_values(revenue, dates, field, [np.nan] * len(dates))
    return mask_customer_rates_without_customers(revenue, dates, regional=not old)


# Boundary between the Summary sheet's revenue blocks. The region and subscription
# blocks list their components as "- " rows, so a block runs until the next heading.
SUMMARY_BLOCK_BOUND = r"^-?\s*(Yearly Premium|Amazon|Total Revenue|DTC Revenue)"

SUMMARY_PRODUCT_MAP = {
    "Hardware": "- Hardware",
    "Addons": "- Add-ons",
    "Merch": "- Merch",
    "Seeds": "- Seeds",
    "Taxes": "- Taxes",
    "Shipping": "- Shipping",
    "Gift_Bag": "- Gift Bag",
}


def fill_dtc_from_summary(
    revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], prefix: str, region: str, log: SyncLog
) -> pd.DataFrame:
    """Read a region's DTC financials from the Summary sheet rather than its P&L tab.

    The EU P&L states its breakdown in euros while its revenue totals are in dollars,
    so summing those components mixed currencies. The Summary carries the same
    breakdown already converted, and its components add up to the region's revenue
    figure to the cent in every workbook, so it is both the correct currency and the
    reconciling source. Taxes sit in two places there, product tax inside the region
    block and subscription tax under the subscription block, and both are kept so the
    split survives into the app.
    """
    sheet = wb.read_sheet("Summary", rows=(1, 120), max_col=45)
    if sheet is None:
        log.skip(wb.path, "Summary", prefix, "sheet missing")
        return revenue
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(wb.path, "Summary", "date columns", f"missing date {dates[0]}")
        return revenue

    def set_field(field: str, row: int | None, label: str) -> None:
        nonlocal revenue
        if row is None:
            revenue = put_values(revenue, dates, field, [0.0] * len(dates))
            log.skip(wb.path, "Summary", field, f"missing label {label}")
        else:
            revenue = put_values(revenue, dates, field, row_values(sheet, row, cols))
            log.source(dates, wb.path, "Summary", field, f"row {row}: {label}")

    region_anchor = r"^- DTC Revenue US&CA" if region == "US" else r"^- DTC Revenue EU"
    start = find_label(sheet, region_anchor, contains=True)
    if start is None:
        log.skip(wb.path, "Summary", prefix, f"missing region block {region}")
        return revenue
    next_block = find_label(sheet, SUMMARY_BLOCK_BOUND, contains=True, after=start + 1)
    end = len(sheet) if next_block is None else next_block - 1

    for name, label in SUMMARY_PRODUCT_MAP.items():
        set_field(f"{prefix}_{name}", find_label(sheet, label, after=start + 1, before=end), label)

    # Through November 2024 the subscription was a component of the region block; from
    # December 2024 it moved to its own block, and from January 2026 that block splits
    # into a line-item total and its own tax row.
    sub_field = f"{prefix}_Subscription"
    tax_field = f"{prefix}_Subscription_Taxes"
    inline_sub = find_label(sheet, "- Yearly Pro Subscription", after=start + 1, before=end)
    if inline_sub is not None:
        set_field(sub_field, inline_sub, "- Yearly Pro Subscription")
        return put_values(revenue, dates, tax_field, [0.0] * len(dates))

    sub_anchor = (
        r"^- Yearly Premium Subscription US&CA" if region == "US" else r"^- Yearly Premium Subscription EU"
    )
    sub_start = find_label(sheet, sub_anchor, contains=True)
    if sub_start is None:
        revenue = put_values(revenue, dates, sub_field, [0.0] * len(dates))
        log.skip(wb.path, "Summary", sub_field, f"missing subscription block {region}")
        return put_values(revenue, dates, tax_field, [0.0] * len(dates))
    sub_next = find_label(sheet, SUMMARY_BLOCK_BOUND, contains=True, after=sub_start + 1)
    sub_end = len(sheet) if sub_next is None else sub_next - 1
    line_item = find_label(sheet, "- Line Item Total", after=sub_start + 1, before=sub_end)
    if line_item is None:
        # Not itemised yet, so the anchor row carries the figure and its tax is still
        # inside the region block's tax line.
        set_field(sub_field, sub_start, sub_anchor)
        revenue = put_values(revenue, dates, tax_field, [0.0] * len(dates))
    else:
        set_field(sub_field, line_item, "- Line Item Total")
        set_field(
            tax_field,
            find_label(sheet, "- Taxes", after=sub_start + 1, before=sub_end),
            "- Taxes (subscription)",
        )
    return revenue


def fill_financials(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], sheet_name: str, prefix: str, log: SyncLog, amazon: bool = False) -> pd.DataFrame:
    sheet = wb.read_sheet(sheet_name, rows=(1, 90 if amazon else 120), max_col=45)
    if sheet is None:
        log.skip(wb.path, sheet_name, prefix, "sheet missing")
        return revenue
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
        return revenue
    if amazon:
        start = find_label(sheet, "Amazon Orders", contains=True)
        if start is None:
            log.skip(wb.path, sheet_name, prefix, "missing Amazon Orders section")
            return revenue
        end = section_end(sheet, start, ["Units Sold", "Revenue"])
        mapping = {"Hardware": "Hardware", "Addons": "Addons", "Tax": "Tax", "Shipping": "Shipping", "GiftWrap": "Gift Wrap Price"}
        for name, label in mapping.items():
            field = f"{prefix}_{name}"
            row = find_label(sheet, label, after=start + 1, before=end)
            if row is None:
                revenue = put_values(revenue, dates, field, [0.0] * len(dates))
                log.skip(wb.path, sheet_name, field, f"missing label {label}")
            else:
                revenue = put_values(revenue, dates, field, row_values(sheet, row, cols))
                log.source(dates, wb.path, sheet_name, field, f"row {row}: {label}")
        return revenue
    mapping = {
        "Hardware": "- Hardware", "Addons": "- Add-ons", "Merch": "- Merch", "Seeds": "- Seeds",
        "Subscription": "- Yearly Pro Subscription", "Taxes": "- Taxes", "Shipping": "- Shipping", "Gift_Bag": "- Gift Bag",
    }
    for name, label in mapping.items():
        revenue = put_sheet_row(revenue, sheet, cols, dates, wb.path, sheet_name, f"{prefix}_{name}", label, log)
    return revenue


def fill_products(
    revenue: pd.DataFrame,
    wb: WorkbookCache,
    dates: list[date],
    sheet_name: str,
    prefix: str,
    products: list[str],
    log: SyncLog,
    start_pattern: str = "Units Sold",
    end_patterns: Iterable[str] = ("Revenue", "Units Cancelled", "Refund", "Merch Units"),
) -> pd.DataFrame:
    sheet = wb.read_sheet(sheet_name, rows=(1, 180), max_col=45)
    if sheet is None:
        log.skip(wb.path, sheet_name, prefix, "sheet missing")
        return revenue
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
        return revenue
    start = find_label(sheet, start_pattern, contains=True)
    if start is None:
        log.skip(wb.path, sheet_name, prefix, "missing Units Sold section")
        return revenue
    end = section_end(sheet, start, end_patterns)
    for product in products:
        row, label = find_product_label(sheet, product, after=start + 1, before=end)
        field = f"{prefix}_{product}"
        values = [0.0] * len(dates)
        if row is None:
            log.skip(wb.path, sheet_name, field, f"missing product row {product}")
        else:
            values = row_values(sheet, row, cols)
            log.source(dates, wb.path, sheet_name, field, f"row {row}: {label}")
        revenue = put_values(revenue, dates, field, values)
    return revenue


def fill_products_sum(
    revenue: pd.DataFrame,
    wb: WorkbookCache,
    dates: list[date],
    sheet_names: list[str],
    prefix: str,
    products: list[str],
    log: SyncLog,
    start_pattern: str = "Units Sold",
    end_patterns: Iterable[str] = ("Revenue", "Units Cancelled", "Refund", "Merch Units"),
) -> pd.DataFrame:
    totals = {product: np.zeros(len(dates), dtype=float) for product in products}
    for sheet_name in sheet_names:
        sheet = wb.read_sheet(sheet_name, rows=(1, 180), max_col=45)
        if sheet is None:
            log.skip(wb.path, sheet_name, prefix, "sheet missing")
            continue
        cols = date_cols(sheet, dates)
        if cols is None:
            log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
            continue
        start = find_label(sheet, start_pattern, contains=True)
        if start is None:
            log.skip(wb.path, sheet_name, prefix, "missing Units Sold section")
            continue
        end = section_end(sheet, start, end_patterns)
        for product in products:
            row, label = find_product_label(sheet, product, after=start + 1, before=end)
            field = f"{prefix}_{product}"
            if row is None:
                log.skip(wb.path, sheet_name, field, f"missing product row {product}")
                continue
            totals[product] += np.asarray(row_values(sheet, row, cols), dtype=float)
            log.source(dates, wb.path, sheet_name, field, f"row {row}: {label}")
    for product, values in totals.items():
        revenue = put_values(revenue, dates, f"{prefix}_{product}", values)
    return revenue


def fill_app_products(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    # 2023 workbooks title this sheet "APP - P&L", so match without regard to case.
    matches = [name for name in wb.sheet_names() if name.strip().lower() == "app - p&l"]
    sheet_name = matches[0] if matches else "App - P&L"
    sheet = wb.read_sheet(sheet_name, rows=(1, 80), max_col=45)
    if sheet is None:
        log.skip(wb.path, sheet_name, "app products", "sheet missing")
        return revenue
    cols = positional_date_cols(sheet, dates, wb, sheet_name, "app_date_columns", log)
    if cols is None:
        return revenue
    gross_orders = find_label(sheet, "Gross Orders")
    if gross_orders is not None:
        net_revenue = find_label(sheet, "Net Revenue", after=gross_orders + 1) or len(sheet)
        apple_orders = find_label(sheet, "Apple Store Orders", after=gross_orders + 1, before=net_revenue) or gross_orders
        google_orders = find_label(sheet, "Google Store Orders", after=gross_orders + 1, before=net_revenue) or gross_orders
        for field, label, after in [
            ("apple_yearly_sub", "- Yearly Subscription", apple_orders + 1),
            ("apple_monthly_sub", "- Monthly Subscription", apple_orders + 1),
            ("google_yearly_sub", "- Yearly Subscription", google_orders + 1),
            ("google_monthly_sub", "- Monthly Subscription", google_orders + 1),
        ]:
            before = google_orders - 1 if field.startswith("apple_") else net_revenue
            row = find_label(sheet, label, after=after, before=before)
            if row is None:
                revenue = put_values(revenue, dates, field, [0.0] * len(dates))
                log.skip(wb.path, sheet_name, field, f"missing label {label}")
            else:
                revenue = put_values(revenue, dates, field, row_values(sheet, row, cols))
                log.source(dates, wb.path, sheet_name, field, f"row {row}: {label}")

    advertising = find_label(sheet, "Advertising")
    if advertising is not None:
        end = section_end(sheet, advertising, ("Estimated Subscription Profit",))
        for field, label in {
            "App_Spend_Meta": "Meta Spend",
            "App_Spend_Apple": "Apple Spend",
            "App_Spend_Google": "Google Spend",
            "Total_App_Spend": "SUM",
        }.items():
            row = find_label(sheet, label, after=advertising + 1, before=end)
            if row is None:
                revenue = put_values(revenue, dates, field, [0.0] * len(dates))
                log.skip(wb.path, sheet_name, field, f"missing label {label} after Advertising")
            else:
                revenue = put_values(revenue, dates, field, row_values(sheet, row, cols))
                log.source(dates, wb.path, sheet_name, field, f"row {row}: {label}")
    return revenue


def fill_digital_marketplace_products(revenue: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    matches = [name for name in wb.sheet_names() if "Digital Marketplaces" in name]
    if not matches:
        log.skip(wb.path, "Digital Marketplaces - P&L", "digital marketplace products", "sheet missing")
        return revenue
    sheet_name = matches[0]
    sheet = wb.read_sheet(sheet_name, rows=(1, 280), max_col=45)
    if sheet is None:
        return revenue
    cols = positional_date_cols(sheet, dates, wb, sheet_name, "digital_marketplace_date_columns", log)
    if cols is None:
        return revenue
    sections = {
        "rachio": "Units Sold \\(Gross\\) - Rachio",
        "weatherflow": "Units Sold \\(Gross\\) - Weatherflow",
        "huckberry": "Units Sold \\(Gross\\) - Huckberry",
    }
    for prefix, pattern in sections.items():
        start = find_label(sheet, pattern, contains=True)
        if start is None:
            log.skip(wb.path, sheet_name, prefix, f"missing section {pattern}")
            continue
        end = section_end(sheet, start, ("Units and Revenue Cancelled", "Revenue", "Orders Return", "RETURN"))
        products = HUCKBERRY_PRODUCTS if prefix == "huckberry" else CORE_SKU_PRODUCTS
        for product in products:
            row, label = find_product_label(sheet, product, after=start + 1, before=end)
            field = f"{prefix}_{product}"
            values = [0.0] * len(dates)
            if row is None:
                log.skip(wb.path, sheet_name, field, f"missing product row {product}")
            else:
                values = row_values(sheet, row, cols)
                log.source(dates, wb.path, sheet_name, field, f"row {row}: {label}")
            revenue = put_values(revenue, dates, field, values)
    return revenue


# Before the dedicated survey tab arrived in November 2023, the post-purchase answers sit in
# a block on the daily sales tab, holding each day's share of respondents with no respondent
# count beside them. Every share is that day's answers over its respondents, so the count is
# the smallest denominator that turns all of them back into whole answers. Rebuilding the
# November 2023 tab this way reproduces its published participant count on all thirty days.
INLINE_SURVEY_CHANNELS = [
    "Facebook / Instagram", "Friends / Family", "TikTok", "TV / Radio", "Blog / Article",
    "Reddit", "Google, Youtube", "Yahoo, Bing",
    # Retired answers: the search engines shared a single option through April 2023, and
    # Pinterest was offered over the same span.
    "Google, Yahoo, Bing", "Pinterest",
]
# The tab keeps its name until July 2023, when the workbook was rebuilt around the Summary
# and the daily tab was set aside under a new one.
INLINE_SURVEY_SHEETS = ("Sales", "OLD Sales")


# Questions present in the dedicated post-purchase data tabs but historically omitted
# from survey_data.csv. The dashboard numbers these after its existing Q1-Q6 views;
# the source workbooks themselves do not assign stable question numbers because the
# questionnaire changed over time.
EXTRA_SURVEY_QUESTIONS = {
    "q7": (
        "Will Bird Buddy be the first bird feeder in your yard?",
        ["Yes", "No"],
    ),
    "q8": (
        "How old are you?",
        ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"],
    ),
    "q9": (
        "What is your gender?",
        ["Male", "Female"],
    ),
    "q10": (
        "Did you compare us with other smart bird feeders before purchasing?",
        ["Yes, I did extensive research", "Yes, but very briefly", "No, not at all"],
    ),
    "q11": (
        "How important do you find acquiring knowledge in bird feeding?",
        ["Very, I love learning about birds", "It's not the main point for me, but nice", "Not at all"],
    ),
    "q12": (
        "How would you rate your bird knowledge?",
        ["Beginner (New to birding)", "Intermediate (Moderate understanding)", "Advanced (In-depth knowledge)"],
    ),
    "q13": (
        "How would you rate the bird knowledge of the person receiving the gift?",
        ["Beginner (New to birding)", "Intermediate (Moderate understanding)", "Advanced (In-depth knowledge)"],
    ),
    "q14": (
        "Are you familiar with the concept of a pollinator garden?",
        ["Yes, I am growing one", "Yes, but haven't tried", "No, I have no idea what this is"],
    ),
    "q15": (
        "Have you ever used a bird feeder before this purchase?",
        ["Yes", "No, never"],
    ),
}


def recover_participants(shares: np.ndarray, rounded: bool, limit: int = 4000) -> int | None:
    """The smallest respondent count that makes every share of a day a whole answer."""
    if shares.sum() <= 0 or not np.isfinite(shares).all():
        return None
    for participants in range(1, limit + 1):
        counts = np.round(shares * participants)
        # A share written to four places pins its answer only to within half of the last
        # place, so the slack a count is allowed grows with the count. Tabs from July 2023
        # carry some days out in full, which pins them far tighter.
        tolerance = 0.5e-4 * participants + 1e-6 if rounded else 1e-6 * participants + 1e-9
        if np.all(np.abs(shares * participants - counts) <= tolerance) and abs(counts.sum() - participants) < 0.5:
            return participants
    return None


def allocate_counts(shares: np.ndarray, participants: int) -> np.ndarray:
    """Whole answers for a day that add up to the respondent count exactly."""
    scaled = shares * participants
    counts = np.floor(scaled)
    leftover = int(round(participants - counts.sum()))
    if leftover:
        # Hand the spare answers to the shares that lost the most to the floor, and take
        # them back from those that lost the least, so the total lands on the count.
        order = np.argsort(-(scaled - counts) if leftover > 0 else (scaled - counts))
        counts[order[:abs(leftover)]] += np.sign(leftover)
    return counts


def repair_participants(
    shares: np.ndarray,
    limit: int = 4000,
    max_corrections: int = 2,
    max_drift: float = 0.01,
) -> tuple[int, np.ndarray] | None:
    """Whole answers for a day whose shares do not quite total one hundred per cent.

    A handful of days carry a mistyped share, so no respondent count reproduces them and
    the day would otherwise be dropped. The reading that needs the fewest cells moved, and
    moves them least, is taken as the one that was meant; anything needing more than a
    couple of cells shifted, or a shift of more than a point, is left alone.
    """
    if shares.sum() <= 0 or not np.isfinite(shares).all():
        return None
    for participants in range(1, limit + 1):
        counts = allocate_counts(shares, participants)
        if counts.min() < 0:
            continue
        drift = np.abs(shares - counts / participants)
        # The smallest count that fits is the one to take. A large enough count can be made
        # to sit close to any set of shares, which would read far more respondents into a
        # day than it saw.
        if int((drift > 0.5e-4 + 1e-9).sum()) <= max_corrections and drift.max() <= max_drift:
            return participants, counts
    return None


def fill_survey_inline(
    survey: pd.DataFrame,
    wb: WorkbookCache,
    dates: list[date],
    revenue: pd.DataFrame,
    log: SyncLog,
) -> pd.DataFrame:
    """Post-purchase answers for a month that predates the dedicated survey tab.

    Only the first question ran in this era, so the answer counts and the respondent total
    are all that can be filled; the follow-up questions and the new/returning split have no
    source. The tab does not publish an engagement rate either, but every month that does
    divides respondents by DTC orders, so the rate is rebuilt that way.
    """
    if any(re.search(r"(PP|Post ?[- ]?Purchase).*Results", name, re.IGNORECASE) for name in wb.sheet_names()):
        return survey
    for sheet_name in INLINE_SURVEY_SHEETS:
        sheet = wb.read_sheet(sheet_name, rows=(1, 95), max_col=45)
        if sheet is None:
            continue
        header = find_label(sheet, r"Post.?purchase Survey", contains=True)
        if header is None:
            continue
        cols = survey_date_cols(sheet, dates)
        if cols is None:
            log.skip(wb.path, sheet_name, "survey date columns", f"missing date {dates[0]}")
            return survey
        # A couple of the answers also head unrelated blocks further down the tab, so the
        # search stops a few rows past the longest answer list the era ever used.
        found = [(channel, find_label(sheet, channel, after=header + 1, before=header + len(INLINE_SURVEY_CHANNELS) + 3))
                 for channel in INLINE_SURVEY_CHANNELS]
        found = [(channel, row) for channel, row in found if row is not None]
        if not found:
            log.skip(wb.path, sheet_name, "inline survey", "no answers under the survey header")
            return survey

        shares = np.array([row_values(sheet, row, cols) for _, row in found], dtype=float)
        participants = np.zeros(len(dates), dtype=float)
        counts = np.zeros_like(shares)
        for index, day in enumerate(dates):
            day_shares = shares[:, index]
            if day_shares.sum() <= 0:
                continue
            # July 2023 onward mixes days written out in full with days rounded to four
            # places, so how tightly a day pins its answers is judged a day at a time.
            rounded = bool(np.allclose(day_shares, np.round(day_shares, 4), atol=1e-12))
            resolved = recover_participants(day_shares, rounded)
            if resolved is not None:
                participants[index] = resolved
                counts[:, index] = np.round(day_shares * resolved)
                continue
            repaired = repair_participants(day_shares)
            if repaired is None:
                log.skip(wb.path, sheet_name, f"survey {day.isoformat()}",
                         f"shares total {day_shares.sum() * 100:.2f}% and do not resolve to whole answers")
                continue
            resolved, day_counts = repaired
            participants[index] = resolved
            counts[:, index] = day_counts
            moved = int((np.abs(day_shares - day_counts / resolved) > 0.5e-4 + 1e-9).sum())
            log.source([day], wb.path, sheet_name, "q0_participants",
                       f"shares total {day_shares.sum() * 100:.2f}%; rebuilt on {resolved} respondents "
                       f"with {moved} answer(s) adjusted")

        for (channel, row), values in zip(found, counts):
            survey = put_values(survey, dates, f"q1_{channel}", values)
            log.source(dates, wb.path, sheet_name, f"q1_{channel}", f"row {row}: {channel} share of respondents")
        survey = put_values(survey, dates, "q0_participants", participants)
        log.source(dates, wb.path, sheet_name, "q0_participants",
                   f"rows {found[0][1]}-{found[-1][1]}: smallest denominator of the day's shares")
        orders = numeric_series(revenue, dates, "DTC_Orders").to_numpy(dtype=float)
        rate = np.divide(participants, orders, out=np.zeros(len(dates), dtype=float), where=orders > 0)
        survey = put_values(survey, dates, "q0_engagement_rate", rate)
        log.source(dates, wb.path, sheet_name, "q0_engagement_rate", "respondents over DTC orders")
        return survey
    return survey


def raw_extra_question_counts(
    sheet: list[list[Any]],
    cols: list[int],
    question: str,
    answer_labels: list[str],
) -> tuple[dict[str, np.ndarray], list[tuple[int, int]]]:
    """Extract count blocks for one question from a dedicated PP data tab.

    Those tabs contain each block twice: integer response counts followed later by
    percentages. Conditional questions repeat once for every answer to "Who is this
    for?". A true count sequence is followed by its own Total submissions row (the age
    block instead repeats its question as the total label), which lets us aggregate the
    branches without accidentally summing the percentage copy.
    """
    label_rows = labels(sheet)
    width = len(cols)
    totals = {answer: np.zeros(width, dtype=float) for answer in answer_labels}
    used: list[tuple[int, int]] = []
    question_rows = [row for row, label in enumerate(label_rows, start=1) if label == question]

    for question_row in question_rows:
        # Stop before the next copy of this or another question. Nested response blocks
        # can have a branch label between the question and their first answer, so search
        # the whole region rather than assuming the answers start on the next row.
        end = len(label_rows)
        for row in range(question_row + 1, len(label_rows) + 1):
            label = label_rows[row - 1]
            normalized = re.sub(r"^%\s*", "", label)
            if "?" in normalized and normalized in {
                spec_question for spec_question, _ in EXTRA_SURVEY_QUESTIONS.values()
            }:
                end = row - 1
                break

        for first_answer in range(question_row + 1, end - len(answer_labels) + 2):
            candidate = label_rows[first_answer - 1:first_answer - 1 + len(answer_labels)]
            if candidate != answer_labels:
                continue
            after = first_answer + len(answer_labels)
            next_label = ""
            while after <= len(label_rows):
                next_label = label_rows[after - 1]
                if next_label:
                    break
                after += 1
            if next_label not in {"Total submissions:", question}:
                continue
            for offset, answer in enumerate(answer_labels):
                totals[answer] += np.asarray(row_values(sheet, first_answer + offset, cols), dtype=float)
            used.append((first_answer, first_answer + len(answer_labels) - 1))
    return totals, used


def results_extra_question_counts(
    sheet: list[list[Any]],
    cols: list[int],
    question: str,
    answer_labels: list[str],
) -> tuple[dict[str, np.ndarray], list[tuple[int, int]]]:
    """Fallback for November 2023, whose workbook has Results but no PP data tab."""
    label_rows = labels(sheet)
    width = len(cols)
    totals = {answer: np.zeros(width, dtype=float) for answer in answer_labels}
    used: list[tuple[int, int]] = []
    question_rows = [row for row, label in enumerate(label_rows, start=1) if label == question]

    for question_row in question_rows:
        answer_start = question_row + 1
        if label_rows[answer_start - 1:answer_start - 1 + len(answer_labels)] != answer_labels:
            continue

        # Global questions use the nearest participant row. Conditional questions sit
        # directly below one of the "Who is this for?" answers, whose share determines
        # the smaller base for that branch.
        participant_row = None
        for row in range(question_row - 1, 0, -1):
            if label_rows[row - 1] == "Number of participants":
                participant_row = row
                break
        if participant_row is None:
            continue
        base = np.asarray(row_values(sheet, participant_row, cols), dtype=float)
        branch_row = question_row - 1
        if branch_row > participant_row and label_rows[branch_row - 1] in {
            "Just me", "I will use with my family", "My parents", "Spouse"
        }:
            base *= np.asarray(row_values(sheet, branch_row, cols), dtype=float)

        for offset, answer in enumerate(answer_labels):
            shares = np.asarray(row_values(sheet, answer_start + offset, cols), dtype=float)
            totals[answer] += base * shares
        used.append((answer_start, answer_start + len(answer_labels) - 1))
    return totals, used


def fill_survey_extra(
    survey: pd.DataFrame,
    wb: WorkbookCache,
    dates: list[date],
    log: SyncLog,
) -> pd.DataFrame:
    """Import every post-purchase question not covered by the original Q1-Q6 parser."""
    totals = {
        f"{question_id}_{answer}": np.zeros(len(dates), dtype=float)
        for question_id, (_, answers) in EXTRA_SURVEY_QUESTIONS.items()
        for answer in answers
    }
    found = {question_id: False for question_id in EXTRA_SURVEY_QUESTIONS}

    data_sheets = [
        name for name in wb.sheet_names()
        if re.search(r"(PP|Post ?[- ]?Purchase).*Data", name, re.IGNORECASE)
    ]
    for sheet_name in data_sheets:
        sheet = wb.read_sheet(sheet_name, rows=(1, 360), max_col=45)
        if sheet is None:
            continue
        cols = survey_date_cols(sheet, dates)
        if cols is None:
            log.skip(wb.path, sheet_name, "extra survey date columns", f"missing date {dates[0]}")
            continue
        for question_id, (question, answer_labels) in EXTRA_SURVEY_QUESTIONS.items():
            counts, used = raw_extra_question_counts(sheet, cols, question, answer_labels)
            if not used:
                continue
            found[question_id] = True
            for answer in answer_labels:
                totals[f"{question_id}_{answer}"] += counts[answer]
            log.source(
                dates,
                wb.path,
                sheet_name,
                question_id,
                f"raw count rows {', '.join(f'{start}-{end}' for start, end in used)}: {question}",
            )

    # November 2023 predates the PP data tab, and December's data tab omits the feeder-
    # experience block even though its Results tab carries it. Recover either question
    # from Results only when no raw count block was found, avoiding any double count.
    result_sheets = [
        name for name in wb.sheet_names()
        if re.search(r"(PP|Post ?[- ]?Purchase).*Results", name, re.IGNORECASE)
    ]
    for sheet_name in result_sheets:
        sheet = wb.read_sheet(sheet_name, rows=(1, 220), max_col=45)
        if sheet is None:
            continue
        cols = survey_date_cols(sheet, dates)
        if cols is None:
            continue
        for question_id in ("q14", "q15"):
            if found[question_id]:
                continue
            question, answer_labels = EXTRA_SURVEY_QUESTIONS[question_id]
            counts, used = results_extra_question_counts(sheet, cols, question, answer_labels)
            if not used:
                continue
            found[question_id] = True
            for answer in answer_labels:
                totals[f"{question_id}_{answer}"] += counts[answer]
            log.source(
                dates,
                wb.path,
                sheet_name,
                question_id,
                f"participant-weighted result rows {', '.join(f'{start}-{end}' for start, end in used)}: {question}",
            )

    for question_id, (_, answer_labels) in EXTRA_SURVEY_QUESTIONS.items():
        for answer in answer_labels:
            survey = put_values(survey, dates, f"{question_id}_{answer}", totals[f"{question_id}_{answer}"])
        if not found[question_id] and data_sheets:
            log.skip(wb.path, ", ".join(data_sheets), question_id, "question not present in this survey version")
    return survey


def fill_survey_q0(survey: pd.DataFrame, wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    participants = np.zeros(len(dates), dtype=float)
    weighted_rate_num = np.zeros(len(dates), dtype=float)
    q1_labels = ["Facebook / Instagram", "Friends / Family", "TikTok", "TV / Radio", "Blog / Article", "Reddit", "Google, Youtube", "Yahoo, Bing"]
    q2_labels = ["I saw an ad", "I saw a post about Bird Buddy on my friend's feed", "I saw an organic post from Bird Buddy"]
    q3_labels = ["Just me", "I will use with my family", "My parents", "Spouse"]

    def count_values(sheet: list[list[Any]], cols: list[int], sheet_name: str, field: str, label: str, base: np.ndarray, after: int = 1, before: float = math.inf, days: list[date] | None = None) -> np.ndarray:
        row = find_label(sheet, label, after=after, before=before)
        if row is None:
            log.skip(wb.path, sheet_name, field, f"missing survey label {label}")
            return np.zeros(len(base), dtype=float)
        log.source(days or dates, wb.path, sheet_name, field, f"row {row}: {label}")
        return base * np.asarray(row_values(sheet, row, cols), dtype=float)

    def put_counts(sheet: list[list[Any]], cols: list[int], sheet_name: str, prefix: str, label_list: list[str], base: np.ndarray, after: int = 1, before: float = math.inf, days: list[date] | None = None) -> dict[str, np.ndarray]:
        nonlocal survey
        out: dict[str, np.ndarray] = {}
        for label in label_list:
            field = f"{prefix}_{label}"
            values = count_values(sheet, cols, sheet_name, field, label, base, after=after, before=before, days=days)
            survey = put_values(survey, days or dates, field, values)
            out[label] = values
        return out

    # "PP - Results" from Dec 2023 on, spelled out as "Post Purchase Survey Results" before.
    survey_sheets = [
        name for name in wb.sheet_names()
        if re.search(r"(PP|Post ?[- ]?Purchase).*Results", name, re.IGNORECASE)
    ]
    # April 2024 carries both eras of the tab side by side, the survey having been recast on
    # the tenth: the combined tab covers the days up to then and the split tab the rest. So
    # the combined reading is used only on the days no split tab answers for.
    split_days = np.zeros(len(dates), dtype=bool)
    for name in survey_sheets:
        probe = wb.read_sheet(name, rows=(1, 220), max_col=45)
        if probe is None or find_label(probe, "New Customers") is None or find_label(probe, "Existing Customers") is None:
            continue
        probe_cols = survey_date_cols(probe, dates)
        probe_row = find_label(probe, "Number of participants")
        if probe_cols is None or probe_row is None:
            continue
        split_days |= np.asarray(row_values(probe, probe_row, probe_cols), dtype=float) > 0
    for sheet_name in survey_sheets:
        sheet = wb.read_sheet(sheet_name, rows=(1, 220), max_col=45)
        if sheet is None:
            continue
        cols = survey_date_cols(sheet, dates)
        if cols is None:
            log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
            continue
        p_row = find_label(sheet, "Number of participants")
        r_row = find_label(sheet, "Engagement Rate")
        if p_row is None or r_row is None:
            log.skip(wb.path, sheet_name, "q0", "missing participants/rate rows")
            continue
        p = np.asarray(row_values(sheet, p_row, cols), dtype=float)
        r = np.asarray(row_values(sheet, r_row, cols), dtype=float)
        participants += p
        weighted_rate_num += p * r
        log.source(dates, wb.path, sheet_name, "q0_participants", f"row {p_row}")
        log.source(dates, wb.path, sheet_name, "q0_engagement_rate", f"row {r_row}")

        # These three only exist on later tabs. Searching for bare "Yes"/"No" without the
        # question header would pick up unrelated answers (November 2023's bird-feeder
        # experience question was once read as the gift question that way).
        q5_start = find_label(sheet, "Did you buy this for your household?")
        q6_start = find_label(sheet, "Did you buy this as a gift?")
        q4_start = find_label(sheet, "Are you a new or existing customer?")
        age_start = find_label(sheet, "How old are you?")
        new_start = find_label(sheet, "New Customers")
        existing_start = find_label(sheet, "Existing Customers")

        if q5_start is not None:
            q5_end = (q6_start - 1) if q6_start else math.inf
            put_counts(sheet, cols, sheet_name, "q5", ["Yes", "No"], p, after=q5_start + 1, before=q5_end)
        if q6_start is not None:
            q6_end = (q4_start - 1) if q4_start else math.inf
            put_counts(sheet, cols, sheet_name, "q6", ["Yes", "No"], p, after=q6_start + 1, before=q6_end)

        empty_segment = np.zeros(len(dates), dtype=float)
        if q4_start is not None:
            q4_end = (age_start - 1) if age_start else math.inf
            q4 = put_counts(sheet, cols, sheet_name, "q4", ["New customer", "Existing customer"], p,
                            after=q4_start + 1, before=q4_end)
        else:
            q4 = {"New customer": empty_segment, "Existing customer": empty_segment}

        new_base = q4["New customer"]
        existing_base = q4["Existing customer"]
        if new_start is None or existing_start is None:
            # From November 2023 to March 2024 the tab carries one set of answers instead of
            # splitting them by new and returning customer, so the totals are read off that
            # single block and the two segment breakdowns are left empty.
            survey_start = find_label(sheet, r"Post.?purchase Survey", contains=True)
            covered = ~split_days
            if not covered.any() or survey_start is None:
                log.skip(wb.path, sheet_name, "q1-q3", "missing New Customers or Existing Customers sections")
                continue
            days = [day for day, take in zip(dates, covered) if take]
            day_cols = [col for col, take in zip(cols, covered) if take]
            day_p = p[covered]
            who_start = find_label(sheet, r"Who is this for\?", contains=True, after=survey_start + 1)
            facebook_start = find_label(sheet, r"Where on Facebook/Instagram", contains=True, after=survey_start + 1)
            q1_end = (who_start - 1) if who_start else math.inf
            combined_q1 = put_counts(sheet, day_cols, sheet_name, "q1", q1_labels, day_p, after=survey_start + 1, before=q1_end, days=days)
            if facebook_start:
                put_counts(sheet, day_cols, sheet_name, "q2", q2_labels, combined_q1["Facebook / Instagram"],
                           after=facebook_start, before=q1_end, days=days)
            if who_start:
                # Each question block is asked of its own set of respondents and states the
                # count just above itself, so the nearest one going up is the right base.
                who_p_row = find_label(sheet, "Number of participants", occurrence="last", before=who_start - 1)
                who_base = np.asarray(row_values(sheet, who_p_row, day_cols), dtype=float) if who_p_row else day_p
                put_counts(sheet, day_cols, sheet_name, "q3", q3_labels, who_base, after=who_start + 1, days=days)
            continue

        new_who_start = find_label(sheet, "Who is this for?", after=new_start + 1, before=existing_start - 1) or 0
        new_where_start = find_label(sheet, "Where did you hear about Bird Buddy?", after=new_start + 1, before=existing_start - 1) or 0
        new_who_end = (new_where_start - 1) if new_where_start else existing_start - 1
        existing_who_start = find_label(sheet, "Who is this for?", after=existing_start + 1) or 0
        existing_where_start = find_label(sheet, "Where did you hear about Bird Buddy?", after=existing_start + 1) or 0
        existing_who_end = (existing_where_start - 1) if existing_where_start else math.inf

        # A handful of days leave the new-against-returning split blank while still saying how
        # many answered and what they said, which would otherwise zero both segments and drop
        # the day. Each segment's shares give its own size back, and the pair is only taken
        # when the two sizes add up to the respondents the tab reports.
        def segment_shares(after: int, before: float, index: int) -> np.ndarray:
            rows = [find_label(sheet, label, after=after, before=before) for label in q1_labels]
            return np.array([row_values(sheet, row, cols)[index] if row else 0.0 for row in rows], dtype=float)

        recovered = False
        for index in np.nonzero((p > 0) & (new_base + existing_base <= 0))[0]:
            sizes = []
            for after, before in [(new_where_start + 1, existing_start - 1), (existing_where_start + 1, math.inf)]:
                shares = segment_shares(after, before, index)
                sizes.append(recover_participants(shares, bool(np.allclose(shares, np.round(shares, 4), atol=1e-12))))
            if None in sizes or sum(sizes) != round(p[index]):
                log.skip(wb.path, sheet_name, f"q4 {dates[index].isoformat()}",
                         "new against returning split is blank and the segments do not add up to the respondents")
                continue
            new_base[index], existing_base[index] = sizes
            recovered = True
            log.source([dates[index]], wb.path, sheet_name, "q4_New customer",
                       f"split blank; segments rebuilt from their own shares as {sizes[0]} new and {sizes[1]} returning")
        if recovered:
            survey = put_values(survey, dates, "q4_New customer", new_base)
            survey = put_values(survey, dates, "q4_Existing customer", existing_base)

        new_q3 = put_counts(sheet, cols, sheet_name, "Nq3", q3_labels, new_base, after=new_who_start + 1, before=new_who_end)
        new_q1 = put_counts(sheet, cols, sheet_name, "Nq1", q1_labels, new_base, after=new_where_start + 1, before=existing_start - 1)
        new_q2 = put_counts(sheet, cols, sheet_name, "Nq2", q2_labels, new_q1["Facebook / Instagram"], after=new_where_start + 1, before=existing_start - 1)

        existing_q3 = put_counts(sheet, cols, sheet_name, "Oq3", q3_labels, existing_base, after=existing_who_start + 1, before=existing_who_end)
        existing_q1 = put_counts(sheet, cols, sheet_name, "Oq1", q1_labels, existing_base, after=existing_where_start + 1)
        existing_q2 = put_counts(sheet, cols, sheet_name, "Oq2", q2_labels, existing_q1["Facebook / Instagram"], after=existing_where_start + 1)

        for label in q1_labels:
            survey = put_values(survey, dates, f"q1_{label}", new_q1[label] + existing_q1[label])
        for label in q2_labels:
            survey = put_values(survey, dates, f"q2_{label}", new_q2[label] + existing_q2[label])
        for label in q3_labels:
            survey = put_values(survey, dates, f"q3_{label}", new_q3[label] + existing_q3[label])
    rate = np.divide(weighted_rate_num, participants, out=np.zeros_like(weighted_rate_num), where=participants > 0)
    survey = put_values(survey, dates, "q0_participants", participants)
    survey = put_values(survey, dates, "q0_engagement_rate", rate)
    return survey


def read_note_rows(sheet: list[list[Any]], cols: list[int], merges: list[tuple[int, int, int, int]],
                   note_rows: Iterable[int]) -> list[dict[str, Any]]:
    """Notes off a run of rows, each spanning the days its merged cell covers."""
    rows = []
    for row_num in note_rows:
        for col in cols:
            value = sheet[row_num - 1][col - 1] if row_num - 1 < len(sheet) and col - 1 < len(sheet[row_num - 1]) else None
            text = normalize_label(value)
            if not text:
                continue
            start_col = end_col = col
            for min_row, min_col, max_row, max_col in merges:
                if min_row <= row_num <= max_row and min_col <= col <= max_col:
                    start_col = max(min(cols), min_col)
                    end_col = min(max(cols), max_col)
                    break
            start_date = as_date_cell(sheet[0][start_col - 1])
            end_date = as_date_cell(sheet[0][end_col - 1])
            # A cell can contain a headline followed by detail lines (for example,
            # OLD/NEW pricing). Keep that cell intact so the dashboard renders it as
            # one note block instead of a separate item for every line.
            rows.append({"start": start_date, "end": end_date, "note": text})
    return rows


def extract_notes(wb: WorkbookCache, dates: list[date], log: SyncLog) -> pd.DataFrame:
    empty = pd.DataFrame(columns=["start", "end", "note"])
    # Before the Summary tab existed the notes were kept on the daily sales tab, on a row of
    # their own rather than in the band above the figures.
    if "Summary" in wb.sheet_names():
        sheet_name, rows_read = "Summary", (1, 12)
    else:
        sheet_name, rows_read = "Sales", (1, 60)
    sheet = wb.read_sheet(sheet_name, rows=rows_read, max_col=45)
    if sheet is None:
        return empty
    cols = date_cols(sheet, dates)
    if cols is None:
        log.skip(wb.path, sheet_name, "date columns", f"missing date {dates[0]}")
        return empty

    if sheet_name == "Summary":
        dtc_row = find_label(sheet, "DTC Revenue") or (len(sheet) + 1)
        note_rows = [row for row in range(3, max(3, dtc_row))
                     if normalize_label(sheet[row - 1][0] if row - 1 < len(sheet) else None) != "Weekend Work"]
    else:
        notes_row = find_label(sheet, "Notes")
        if notes_row is None:
            log.skip(wb.path, sheet_name, "notes", "no Notes row on the sales tab")
            return empty
        note_rows = [notes_row]

    rows = read_note_rows(sheet, cols, wb.merge_ranges(sheet_name), note_rows)
    return pd.DataFrame(rows).drop_duplicates() if rows else empty


def apply_huckberry_november_2024_backfill(
    revenue: pd.DataFrame, dates: list[date], log: SyncLog | None = None
) -> pd.DataFrame:
    """Restore the Huckberry block that lives outside November 2024's daily Summary."""
    if not dates or (dates[0].year, dates[0].month) != (2024, 11):
        return revenue

    fields = {
        "Huckberry_Revenue": 0,
        "Huckberry_Orders": 1,
        "huckberry_SKU 3 - Blue w/ Solar": 2,
        "huckberry_SKU 3 - Blue w/ Solar PRO": 3,
    }
    for field, value_index in fields.items():
        values = [HUCKBERRY_NOVEMBER_2024.get(day, (0.0, 0, 0, 0))[value_index] for day in dates]
        revenue = put_values(revenue, dates, field, values)

    # The Summary's own total omitted the separate Huckberry block, so restore it
    # there as well. derive_totals() then carries it into the DM and B2B totals.
    huckberry_revenue = np.array(
        [HUCKBERRY_NOVEMBER_2024.get(day, (0.0, 0, 0, 0))[0] for day in dates], dtype=float
    )
    huckberry_orders = np.array(
        [HUCKBERRY_NOVEMBER_2024.get(day, (0.0, 0, 0, 0))[1] for day in dates], dtype=float
    )
    if "Total_Revenue" in revenue.columns:
        revenue = put_values(
            revenue, dates, "Total_Revenue",
            numeric_series(revenue, dates, "Total_Revenue").values + huckberry_revenue,
        )
    if "Total_Orders" in revenue.columns:
        revenue = put_values(
            revenue, dates, "Total_Orders",
            numeric_series(revenue, dates, "Total_Orders").values + huckberry_orders,
        )
    if log is not None:
        log.source(
            dates,
            Path("manual_backfills/huckberry_november_2024"),
            "HuckBerry Sales",
            "Huckberry_Revenue",
            "separate summary block: $6,664.53, 20 orders, 21 units (V1 9; V2 12)",
        )
    return revenue


def derive_totals(revenue: pd.DataFrame, dates: list[date]) -> pd.DataFrame:
    def sum_existing(fields: Iterable[str]) -> np.ndarray:
        # Ordered by the month's dates, not by the frame's rows: a month that is only
        # partly in the file already gets its missing days appended at the end, and the
        # write side maps values back by date, so row order would misalign the two.
        fields = [field for field in fields if field in revenue.columns]
        total = np.zeros(len(dates), dtype=float)
        for field in fields:
            total += numeric_series(revenue, dates, field).to_numpy(dtype=float)
        return total

    def assign(field: str, values: Iterable[float]) -> None:
        nonlocal revenue
        revenue = put_values(revenue, dates, field, values)

    dtc_hardware_products = [
        "SKU 1 - Blue", "SKU 2 - Yellow", "SKU 3 - Blue w/ Solar", "SKU 4 - Yellow w/ Solar",
        "SKU 1 - Blue PRO", "SKU 2 - Yellow PRO", "SKU 3 - Blue w/ Solar PRO", "SKU 4 - Yellow w/ Solar PRO",
        "SKU 5 - HBF", "SKU 6 - HBF w/ Solar",
    ]
    dtc_addon_products = [
        "Wall Mount", "Suet Ball Holder", "3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow",
        "Solar Roof Single - Blue", "Solar Roof Single - Yellow", "Perch Extender - Blue", "Perch Extender - Yellow",
        "Solar Roof (HBF)", "Housing - only (HBF)", "Nature Station", "Nature Cam PRO",
    ]
    # The pre-Summary era's own product names, deduplicated because the two mounts carry
    # the same name in both eras and a repeat here would count those units twice.
    dtc_hardware_products = list(dict.fromkeys(dtc_hardware_products + PRE_SUMMARY_HARDWARE_PRODUCTS))
    dtc_addon_products = list(dict.fromkeys(dtc_addon_products + PRE_SUMMARY_ADDON_PRODUCTS))
    dtc_seed_products = [
        "Seasonal Curation - 8lb", "Seasonal Curation - 20lb", "Buddy Bites - 8lb", "Buddy Bites - 20lb",
        "Snack n' Soar - 8lb", "Snack n' Soar - 20lb", "Avian Choice - 8lb", "Avian Choice - 20lb",
    ]
    amazon_hardware_products = [
        "SKU 1 - Blue", "SKU 2 - Yellow", "SKU 3 - Blue w/ Solar", "SKU 4 - Yellow w/ Solar",
        "SKU 1 - Blue PRO", "SKU 2 - Yellow PRO", "SKU 3 - Blue w/ Solar PRO", "SKU 4 - Yellow w/ Solar PRO",
        "SKU 5 - HBF", "SKU 6 - HBF w/ Solar", "SKU 5 - HBF PRO", "SKU 6 - HBF w/ Solar PRO",
    ]
    amazon_addon_products = [
        "Wall Mount", "Suet Ball Holder", "3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow",
        "Solar Roof Single - Blue", "Solar Roof Single - Yellow", "Perch Extender - Blue", "Perch Extender - Yellow",
        "Nature Cam PRO",
    ]

    assign("DTC_US_Hardware_Units", sum_existing(f"dtc_us_{p}" for p in dtc_hardware_products))
    assign("DTC_EU_Hardware_Units", sum_existing(f"dtc_eu_{p}" for p in dtc_hardware_products))
    assign("DTC_Hardware_Units", sum_existing(f"dtc_{p}" for p in dtc_hardware_products))
    assign("DTC_US_Addons_Units", sum_existing(f"dtc_us_{p}" for p in dtc_addon_products))
    assign("DTC_EU_Addons_Units", sum_existing(f"dtc_eu_{p}" for p in dtc_addon_products))
    assign("DTC_Addons_Units", sum_existing(f"dtc_{p}" for p in dtc_addon_products))
    assign("DTC_US_Seeds_Units", sum_existing(f"dtc_us_{p}" for p in dtc_seed_products))
    assign("DTC_EU_Seeds_Units", sum_existing(f"dtc_eu_{p}" for p in dtc_seed_products))
    assign("DTC_Seeds_Units", sum_existing(f"dtc_{p}" for p in dtc_seed_products))
    for field in ["DTC_Merch_Units", "DTC_US_Merch_Units", "DTC_EU_Merch_Units"]:
        assign(field, np.zeros(len(dates), dtype=float))
    assign("Amazon_Hardware_Units", sum_existing(f"amazon_{p}" for p in amazon_hardware_products))
    assign("Amazon_Addons_Units", sum_existing(f"amazon_{p}" for p in amazon_addon_products))
    # Up to Nov 2023 the Summary's Digital Marketplaces subtotal counts IndieGoGo as one
    # of its marketplaces, and the Total Revenue formula then adds the IndieGoGo row on
    # top of that subtotal, so IndieGoGo lands in the total twice. From Dec 2023 the
    # subtotal drops it. Comparing the imported subtotal against its own parts says which
    # way this workbook is built, and the double count comes back off where it is there.
    summary_dm = numeric_series(revenue, dates, "Digital_Marketplaces_Revenue").values
    dm_parts = sum_existing(["Rachio_Revenue", "Weatherflow_Revenue", "Huckberry_Revenue"])
    indiegogo = numeric_series(revenue, dates, "IndieGoGo_Revenue").values
    double_counted = np.isclose(summary_dm, dm_parts + indiegogo, atol=0.01) & (indiegogo != 0)

    assign("Digital_Marketplaces_Revenue", dm_parts)
    assign("Digital_Marketplaces_Orders", sum_existing(["Rachio_Orders", "Weatherflow_Orders", "Huckberry_Orders"]))
    if double_counted.any() and "Total_Revenue" in revenue.columns:
        assign("Total_Revenue", numeric_series(revenue, dates, "Total_Revenue").values - np.where(double_counted, indiegogo, 0.0))
    assign("Retail_Revenue", sum_existing(["BestBuy_Revenue", "Target_Revenue", "Walmart_Revenue", "Costco_Revenue", "Chewy_Revenue"]))
    assign("Retail_Orders", sum_existing(["BestBuy_Orders", "Target_Orders", "Walmart_Orders", "Costco_Orders", "Chewy_Orders"]))
    assign("B2B_Revenue", numeric_series(revenue, dates, "Retail_Revenue").values)
    assign("B2B_Orders", numeric_series(revenue, dates, "Retail_Orders").values)
    assign("Total_Retail_Revenue", numeric_series(revenue, dates, "Retail_Revenue").values)
    assign("Total_Retail_Orders", numeric_series(revenue, dates, "Retail_Orders").values)
    assign("Total_DM_Revenue", numeric_series(revenue, dates, "Digital_Marketplaces_Revenue").values)
    assign("Total_DM_Orders", numeric_series(revenue, dates, "Digital_Marketplaces_Orders").values)
    assign("Total_B2B_Revenue", numeric_series(revenue, dates, "Retail_Revenue").values + numeric_series(revenue, dates, "Digital_Marketplaces_Revenue").values)
    assign("Total_B2B_Orders", numeric_series(revenue, dates, "Retail_Orders").values + numeric_series(revenue, dates, "Digital_Marketplaces_Orders").values)
    assign("Amazon_Spend_EU", sum_existing(["Amazon_Spend_UK", "Amazon_Spend_FR", "Amazon_Spend_GER"]))
    assign("Retail_Spend", sum_existing(["BestBuy_Spend", "Target_Spend", "Walmart_Spend", "Chewy_Spend"]))
    assign("App_Revenue", sum_existing(["Google_Store", "Apple_Store", "App_Comission", "App_Tax"]))
    assign("App_Orders", sum_existing(["Google_Store_Orders", "Apple_Store_Orders"]))

    for suffix in ["Revenue", "Hardware", "Addons", "Merch", "Seeds", "Subscription", "Subscription_Taxes",
                   "Taxes", "Shipping", "Unallocated", "Gift_Cards", "Gift_Bag",
                   "Orders", "Hardware_Units", "Addons_Units", "Merch_Units", "Seeds_Units", "Subscription_Units", "Gift_Bag_Units"]:
        us, eu, base, total = f"DTC_US_{suffix}", f"DTC_EU_{suffix}", f"DTC_{suffix}", f"DTC_Total_{suffix}"
        if all(field in revenue.columns for field in [us, eu, base, total]):
            values = numeric_series(revenue, dates, us).values + numeric_series(revenue, dates, eu).values
            assign(total, values)
            assign(base, values)
    if all(field in revenue.columns for field in ["DTC_US_Spend", "DTC_EU_Spend", "DTC_Total_Spend", "Total_DTC_Spend"]):
        values = numeric_series(revenue, dates, "DTC_US_Spend").values + numeric_series(revenue, dates, "DTC_EU_Spend").values
        assign("DTC_Total_Spend", values)
        assign("Total_DTC_Spend", values)
    for product in DTC_BASE_PRODUCTS:
        base, us, eu = f"dtc_{product}", f"dtc_us_{product}", f"dtc_eu_{product}"
        if all(field in revenue.columns for field in [base, us, eu]):
            assign(base, numeric_series(revenue, dates, us).values + numeric_series(revenue, dates, eu).values)
    for product in AMAZON_PRODUCTS:
        base, us, eu = f"amazon_{product}", f"amazon_us_{product}", f"amazon_eu_{product}"
        if all(field in revenue.columns for field in [base, us, eu]):
            base_vals = numeric_series(revenue, dates, base).values
            us_vals = numeric_series(revenue, dates, us).values.copy()
            eu_vals = numeric_series(revenue, dates, eu).values.copy()
            unsplit = (us_vals + eu_vals == 0) & (base_vals != 0)
            us_vals[unsplit] = base_vals[unsplit]
            eu_vals[unsplit] = 0
            assign(us, us_vals)
            assign(eu, eu_vals)
            assign(base, us_vals + eu_vals)
    for suffix in ["Revenue", "Hardware", "Addons", "Tax", "Shipping", "GiftWrap", "Orders", "Hardware_Units", "Addons_Units"]:
        base, us, eu = f"Amazon_{suffix}", f"Amazon_US_{suffix}", f"Amazon_EU_{suffix}"
        if all(field in revenue.columns for field in [base, us, eu]):
            base_vals = numeric_series(revenue, dates, base).values
            us_vals = numeric_series(revenue, dates, us).values.copy()
            eu_vals = numeric_series(revenue, dates, eu).values.copy()
            unsplit = (us_vals + eu_vals == 0) & (base_vals != 0)
            us_vals[unsplit] = base_vals[unsplit]
            eu_vals[unsplit] = 0
            assign(us, us_vals)
            assign(eu, eu_vals)
            if suffix != "Revenue" or np.any(us_vals + eu_vals > 0):
                assign(base, us_vals + eu_vals)
    if all(field in revenue.columns for field in ["Amazon_Spend", "Amazon_Spend_US", "Amazon_Spend_EU"]):
        base_vals = numeric_series(revenue, dates, "Amazon_Spend").values
        us_vals = numeric_series(revenue, dates, "Amazon_Spend_US").values.copy()
        eu_vals = numeric_series(revenue, dates, "Amazon_Spend_EU").values.copy()
        unsplit = (us_vals + eu_vals == 0) & (base_vals != 0)
        us_vals[unsplit] = base_vals[unsplit]
        assign("Amazon_Spend_US", us_vals)
        assign("Amazon_Spend_EU", eu_vals)
    assign("Fees", sum_existing(["Affiliate_Fees", "Rachio_Fees", "Weatherflow_Fees", "Costco_Fees"]))

    # The Summary's Total Revenue row counts Digital Marketplaces up to Nov 2024 and
    # stops once the retail and DM blocks move below the total. Checked against every
    # workbook on both revenue and order counts, so the boundary is a month, not a
    # layout guess. Adding it back for the later era keeps one definition throughout:
    # DTC + Amazon + IndieGoGo + Digital Marketplaces, with retail and app outside.
    if dates and (min(dates).year, min(dates).month) > DM_INSIDE_SUMMARY_TOTAL_THROUGH:
        for total, part in [
            ("Total_Revenue", "Digital_Marketplaces_Revenue"),
            ("Total_Orders", "Digital_Marketplaces_Orders"),
        ]:
            if total in revenue.columns:
                assign(total, numeric_series(revenue, dates, total).values + numeric_series(revenue, dates, part).values)
    return revenue


def ensure_columns(df: pd.DataFrame, columns: Iterable[str], default: float = 0.0) -> pd.DataFrame:
    for col in dict.fromkeys(columns):
        if col not in df.columns:
            df[col] = default
    return df


def load_csv(path: Path, required_columns: Iterable[str] = ()) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["Date"] = pd.to_datetime(df["Date"]).dt.date
    df = ensure_columns(df, required_columns)
    for col in df.columns:
        if col != "Date":
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def zero_dates(df: pd.DataFrame, dates: list[date], rate_like: bool = False) -> pd.DataFrame:
    df = ensure_dates(df, dates)
    idx_dates = pd.to_datetime(df["Date"]).dt.date
    cols = [col for col in df.columns if col != "Date"]
    df.loc[idx_dates.isin(dates), cols] = 0.0
    if rate_like:
        rate_cols = [col for col in cols if re.search(r"ROAS|SPU|CR|AOV|RPU|Customers", col)]
        df.loc[idx_dates.isin(dates), rate_cols] = np.nan
    return df


def discover_files(sheet_dir: Path) -> list[Path]:
    year_dirs = [path for path in sheet_dir.iterdir() if path.is_dir() and re.match(r"^20\d{2}$", path.name)]
    if year_dirs:
        files = [file for year_dir in year_dirs for file in year_dir.glob("*.xlsx")]
    else:
        files = list(sheet_dir.glob("*.xlsx"))
    files = [path for path in files if path.exists() and not path.name.startswith("~$")]
    return sorted(files, key=lambda path: (extract_year(path), extract_month(path)))


def apply_file_filters(files: list[Path], args: argparse.Namespace) -> list[Path]:
    if args.year:
        years = {int(part.strip()) for part in args.year.split(",") if part.strip()}
        files = [file for file in files if extract_year(file) in years]
    if args.month:
        months = {int(part.strip()) for part in args.month.split(",") if part.strip()}
        files = [file for file in files if extract_month(file) in months]
    if args.since:
        since = datetime.strptime(args.since + ("-01" if len(args.since) == 7 else ""), "%Y-%m-%d").date()
        since_key = since.year * 100 + since.month
        files = [file for file in files if extract_year(file) * 100 + extract_month(file) >= since_key]
    if args.only:
        pattern = re.compile(args.only, re.IGNORECASE)
        files = [file for file in files if pattern.search(file.name)]
    return files


def backup_once(path: Path) -> None:
    if not path.exists():
        return
    backup = path.with_name(f"{path.stem}.backup_{STAMP}_before_python_sync{path.suffix}")
    if not backup.exists():
        shutil.copy2(path, backup)


def write_outputs(revenue: pd.DataFrame, survey: pd.DataFrame, notes: pd.DataFrame, log: SyncLog, output_dir: Path,
                  survey_only: bool = False) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    survey.to_csv(output_dir / "survey_data.csv", index=False, na_rep="")
    if not survey_only:
        revenue.to_csv(output_dir / "revenue_data.csv", index=False, na_rep="")
        notes.to_csv(output_dir / "campaign_notes.csv", index=False, na_rep="")
    pd.DataFrame(log.sources).to_csv(output_dir / f"google_sheets_sync_sources_{STAMP}.csv", index=False)
    pd.DataFrame(log.skips).to_csv(output_dir / f"google_sheets_sync_skips_{STAMP}.csv", index=False)


def sync_revenue_month(revenue: pd.DataFrame, wb: WorkbookCache, file: Path, dates: list[date], log: SyncLog) -> pd.DataFrame:
    revenue = zero_dates(revenue, dates, rate_like=True)
    month_mask = pd.to_datetime(revenue["Date"]).dt.date.isin(dates)

    revenue = fill_summary(revenue, wb, dates, log)
    revenue = fill_pre_summary(revenue, wb, dates, log)
    if uses_regional_dtc(file):
        revenue = fill_dtc_from_summary(revenue, wb, dates, "DTC_US", "US", log)
        revenue = fill_dtc_from_summary(revenue, wb, dates, "DTC_EU", "EU", log)
        revenue = fill_products(revenue, wb, dates, "DTC US&CA - P&L", "dtc_us", DTC_BASE_PRODUCTS, log)
        revenue = fill_products(revenue, wb, dates, "DTC EU - P&L", "dtc_eu", DTC_BASE_PRODUCTS, log)
    else:
        revenue = fill_financials(revenue, wb, dates, "DTC - P&L", "DTC", log)
        for suffix in ["Revenue", "Hardware", "Addons", "Merch", "Seeds", "Subscription", "Subscription_Taxes",
                       "Taxes", "Shipping", "Unallocated", "Gift_Cards", "Gift_Bag",
                       "Orders", "Hardware_Units", "Addons_Units", "Merch_Units", "Seeds_Units", "Subscription_Units"]:
            for target_suffix, source_suffix in [(f"US_{suffix}", suffix), (f"Total_{suffix}", suffix)]:
                source = f"DTC_{source_suffix}"
                target = f"DTC_{target_suffix}"
                if source in revenue.columns:
                    revenue.loc[month_mask, target] = revenue.loc[month_mask, source]
            revenue.loc[month_mask, f"DTC_EU_{suffix}"] = 0.0
        revenue = fill_products(revenue, wb, dates, "DTC - P&L", "dtc", DTC_BASE_PRODUCTS, log)
        for product in DTC_BASE_PRODUCTS:
            revenue.loc[month_mask, f"dtc_us_{product}"] = revenue.loc[month_mask, f"dtc_{product}"]
            revenue.loc[month_mask, f"dtc_eu_{product}"] = 0.0

    if "AMAZON - P&L" in wb.sheet_names():
        revenue = fill_financials(revenue, wb, dates, "AMAZON - P&L", "Amazon", log, amazon=True)
        revenue = fill_products(revenue, wb, dates, "AMAZON - P&L", "amazon", AMAZON_PRODUCTS, log)
        for suffix in ["Hardware", "Addons", "Tax", "Shipping", "GiftWrap"]:
            revenue.loc[month_mask, f"Amazon_US_{suffix}"] = revenue.loc[month_mask, f"Amazon_{suffix}"]
            revenue.loc[month_mask, f"Amazon_EU_{suffix}"] = 0.0
        for product in AMAZON_PRODUCTS:
            revenue.loc[month_mask, f"amazon_us_{product}"] = revenue.loc[month_mask, f"amazon_{product}"]
            revenue.loc[month_mask, f"amazon_eu_{product}"] = 0.0
    else:
        revenue = fill_products_sum(revenue, wb, dates, ["AMAZON US&CA - P&L", "AMAZON EU - P&L"], "amazon", AMAZON_PRODUCTS, log)
        revenue = fill_products(revenue, wb, dates, "AMAZON US&CA - P&L", "amazon_us", AMAZON_PRODUCTS, log)
        revenue = fill_products(revenue, wb, dates, "AMAZON EU - P&L", "amazon_eu", AMAZON_PRODUCTS, log)

    revenue = fill_products(revenue, wb, dates, "WALMART - P&L", "walmart", RETAIL_MARKETPLACE_PRODUCTS, log, start_pattern="Units Sold")
    revenue = fill_products(revenue, wb, dates, "COSTCO - P&L", "costco", RETAIL_MARKETPLACE_PRODUCTS, log, start_pattern="Units Sold \\(Gross\\) - Costco")
    revenue = fill_digital_marketplace_products(revenue, wb, dates, log)
    revenue = fill_app_products(revenue, wb, dates, log)
    revenue = apply_huckberry_november_2024_backfill(revenue, dates, log)
    return derive_totals(revenue, dates)


def sync(args: argparse.Namespace) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, SyncLog, list[Path], date, date]:
    root = Path.cwd()
    data_dir = root / "App_py" / "data"
    sheet_dir = root / "Google Sheets"
    revenue = load_csv(data_dir / "revenue_data.csv", REQUIRED_REVENUE_COLS)
    survey = load_csv(data_dir / "survey_data.csv", ["q0_participants", "q0_engagement_rate"])
    notes = pd.read_csv(data_dir / "campaign_notes.csv")
    if "start" in notes.columns:
        notes["start"] = pd.to_datetime(notes["start"]).dt.date
    if "end" in notes.columns:
        notes["end"] = pd.to_datetime(notes["end"]).dt.date

    files = apply_file_filters(discover_files(sheet_dir), args)
    if not files:
        raise SystemExit("No workbook files matched the sync filters.")
    all_sync_dates = [d for file in files for d in month_dates(extract_year(file), extract_month(file))]
    sync_start, sync_end = min(all_sync_dates), max(all_sync_dates)
    all_new_notes: list[pd.DataFrame] = []
    log = SyncLog()

    for file in files:
        dates = month_dates(extract_year(file), extract_month(file))
        wb = WorkbookCache(file)
        if not args.survey_only:
            revenue = sync_revenue_month(revenue, wb, file, dates, log)
            all_new_notes.append(extract_notes(wb, dates, log))
        survey = zero_dates(survey, dates)
        survey = fill_survey_q0(survey, wb, dates, log)
        survey = fill_survey_extra(survey, wb, dates, log)
        survey = fill_survey_inline(survey, wb, dates, revenue, log)

    if args.survey_only:
        revenue = revenue.sort_values("Date")
        survey = survey.sort_values("Date")
        return revenue, survey, notes, log, files, sync_start, sync_end

    if "start" in notes.columns:
        note_start = pd.to_datetime(notes["start"]).dt.date
        notes = notes.loc[~((note_start >= sync_start) & (note_start <= sync_end))].copy()
    new_notes = pd.concat(all_new_notes, ignore_index=True) if all_new_notes else pd.DataFrame(columns=["start", "end", "note"])
    if not new_notes.empty:
        note_cols = list(notes.columns[:3]) if len(notes.columns) >= 3 else ["note", "start", "end"]
        new_notes = new_notes[["note", "start", "end"]]
        new_notes.columns = note_cols
        notes = pd.concat([notes, new_notes], ignore_index=True)
    notes = notes.drop_duplicates()
    if {"start", "end"}.issubset(notes.columns):
        notes = notes.sort_values(["start", "end", notes.columns[2]])
    revenue = revenue.sort_values("Date")
    survey = survey.sort_values("Date")
    return revenue, survey, notes, log, files, sync_start, sync_end


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync Google Sheets sales workbooks into the Shiny for Python CSV data.")
    parser.add_argument("--year", default=os.environ.get("SYNC_YEAR", ""))
    parser.add_argument("--month", default=os.environ.get("SYNC_MONTH", ""))
    parser.add_argument("--since", default=os.environ.get("SYNC_SINCE", ""))
    parser.add_argument("--only", default=os.environ.get("SYNC_ONLY", ""))
    parser.add_argument("--output-dir", default="")
    parser.add_argument("--no-backup", action="store_true")
    # Survey answers reach further back than the revenue does, so they can be pulled in for a
    # month whose figures are not wanted in the dashboard yet.
    parser.add_argument("--survey-only", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    revenue, survey, notes, log, files, sync_start, sync_end = sync(args)
    output_dir = Path(args.output_dir) if args.output_dir else Path.cwd() / "App_py" / "data"
    if not args.output_dir and not args.no_backup:
        targets = ["survey_data.csv"] if args.survey_only else ["revenue_data.csv", "survey_data.csv", "campaign_notes.csv"]
        for filename in targets:
            backup_once(output_dir / filename)
    write_outputs(revenue, survey, notes, log, output_dir, survey_only=args.survey_only)
    print(f"Synced {len(files)} workbooks")
    print(f"Date range: {sync_start} to {sync_end}")
    print(f"Source rows: {len(log.sources)}")
    print(f"Skipped items: {len(log.skips)}")


if __name__ == "__main__":
    main()

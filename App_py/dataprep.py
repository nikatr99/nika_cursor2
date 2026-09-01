"""Loading and repairing the daily revenue and survey frames.

Everything here is the data layer: reading the synced CSVs, deriving the
regional DTC and Amazon splits, attaching the Metorik renewals series,
separating subscription tax from product tax before 2026, and taking the
subscription side off the headline when the renewals toggle is on. The
reasoning behind each repair is documented in App_py/README.md and
docs/subscription_tax_before_2026.txt.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

import numpy as np
import pandas as pd

DATA_DIR = Path(__file__).parent / "data"


def load_csv(name: str, date_cols: Sequence[str]) -> pd.DataFrame:
    df = pd.read_csv(DATA_DIR / name)
    for col in date_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def group_campaign_note_lines(notes: pd.DataFrame) -> pd.DataFrame:
    """Rejoin detail lines split by older versions of the workbook importer."""
    if notes.empty or not {"start", "end", "note"}.issubset(notes.columns):
        return notes

    grouped: list[dict[str, object]] = []
    for row in notes.to_dict("records"):
        text = str(row["note"]).strip()
        is_detail = bool(re.match(r"^(?:[-*•]\s+)(?:OLD|NEW)\s*:", text, flags=re.IGNORECASE))
        same_period = bool(
            grouped
            and grouped[-1]["start"] == row["start"]
            and grouped[-1]["end"] == row["end"]
        )
        if is_detail and same_period:
            grouped[-1]["note"] = f'{grouped[-1]["note"]}\n{text}'
        else:
            grouped.append({**row, "note": text})
    return pd.DataFrame(grouped, columns=notes.columns)


DTC_REGION_CHOICES = {
    "all": "All DTC",
    "us": "US/CA",
    "eu": "EU",
}

AMAZON_REGION_CHOICES = {
    "all": "All Amazon",
    "us": "US",
    "eu": "EU",
}

# The Shopify-era line-up predates the feeder coming in two colours, so those columns are
# all the blue version and are grouped onto the blue tiles below. Region splitting reads
# the product columns off the data instead of a list; see product_base_cols.


def product_base_cols(df: pd.DataFrame, prefix: str) -> List[str]:
    """Every product column a channel reports, read off the frame rather than a list.

    The lists above name the line-up as it stood when each was written, so a SKU the sync
    started carrying later was left out of the region switch and kept its all-region figure
    when a region was picked: the Hummingbird PRO feeders showed US units under EU. Only
    the products use a lower-case channel prefix, the financials being capitalised, so the
    columns can be picked out and the switch covers whatever the sync produces.
    """
    skip = (f"{prefix}_us_", f"{prefix}_eu_")
    return [col for col in df.columns if col.startswith(f"{prefix}_") and not col.startswith(skip)]


def numeric_col(df: pd.DataFrame, col: str) -> pd.Series:
    if col not in df.columns:
        return pd.Series(0.0, index=df.index)
    return pd.to_numeric(df[col], errors="coerce").fillna(0)


def monthly_date(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["Date"] = out["Date"].dt.to_period("M").dt.to_timestamp()
    return out


def prepare_dtc_segments(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    updates: dict[str, pd.Series | float] = {}
    dtc_pairs = [
        ("Revenue", "DTC_Revenue", "DTC_EU_Revenue"),
        ("Hardware", "DTC_Hardware", "DTC_EU_Hardware"),
        ("Addons", "DTC_Addons", "DTC_EU_Addons"),
        ("Merch", "DTC_Merch", "DTC_EU_Merch"),
        ("Seeds", "DTC_Seeds", "DTC_EU_Seeds"),
        ("Subscription", "DTC_Subscription", "DTC_EU_Subscription"),
        ("Subscription_Taxes", "DTC_Subscription_Taxes", "DTC_EU_Subscription_Taxes"),
        ("Taxes", "DTC_Taxes", "DTC_EU_Taxes"),
        ("Shipping", "DTC_Shipping", "DTC_EU_Shipping"),
        ("Gift_Cards", "DTC_Gift_Cards", "DTC_EU_Gift_Cards"),
        ("Unallocated", "DTC_Unallocated", "DTC_EU_Unallocated"),
        ("Orders", "DTC_Orders", "DTC_EU_Orders"),
        ("Hardware_Units", "DTC_Hardware_Units", "DTC_EU_Hardware_Units"),
        ("Addons_Units", "DTC_Addons_Units", "DTC_EU_Addons_Units"),
        ("Merch_Units", "DTC_Merch_Units", "DTC_EU_Merch_Units"),
        ("Seeds_Units", "DTC_Seeds_Units", "DTC_EU_Seeds_Units"),
        ("Subscription_Units", "DTC_Subscription_Units", "DTC_EU_Subscription_Units"),
    ]
    for suffix, combined_col, eu_col in dtc_pairs:
        # The unified DTC_* columns already carry US and EU together, matching the
        # Summary sheet, so they are the combined figure rather than the US one.
        # Adding EU on top of them double-counted Europe across the whole DTC side.
        combined = numeric_col(out, combined_col)
        eu = numeric_col(out, eu_col)
        us_col = f"DTC_US_{suffix}"
        updates[us_col] = numeric_col(out, us_col) if us_col in out.columns else (combined - eu)
        updates[f"DTC_Total_{suffix}"] = combined
    if "DTC_US_Spend" not in out.columns:
        updates["DTC_US_Spend"] = numeric_col(out, "Total_DTC_Spend")
    if "DTC_EU_Spend" not in out.columns:
        updates["DTC_EU_Spend"] = 0.0
    updates["DTC_Total_Spend"] = numeric_col(out, "Total_DTC_Spend")
    regional_metric_cols = [
        "Web_CR",
        "Web_AOV",
        "Web_AOV_WO_Renewals",
        "fAOV",
        "rAOV",
        "Web_RPU",
        "Web_RPU_WO_Renewals",
        "fRPU",
        "rRPU",
        "Customers",
        "Returning_Customers",
        "First_Time_Customers",
    ]
    for base_col in regional_metric_cols:
        if base_col not in out.columns:
            continue
        us_col = f"{base_col}_US"
        eu_col = f"{base_col}_EU"
        base_values = numeric_col(out, base_col)
        if us_col in out.columns:
            updates[us_col] = pd.to_numeric(out[us_col], errors="coerce").fillna(base_values)
        else:
            updates[us_col] = base_values
        if eu_col in out.columns:
            updates[eu_col] = pd.to_numeric(out[eu_col], errors="coerce")
        else:
            updates[eu_col] = np.nan
    for base_col in product_base_cols(out, "dtc"):
        suffix = base_col.removeprefix("dtc_")
        us_col = f"dtc_us_{suffix}"
        eu_col = f"dtc_eu_{suffix}"
        if us_col not in out.columns:
            updates[us_col] = numeric_col(out, base_col)
        if eu_col not in out.columns:
            updates[eu_col] = 0.0
    if updates:
        out = pd.concat([out.drop(columns=[c for c in updates if c in out.columns]), pd.DataFrame(updates, index=out.index)], axis=1)
    return out


def apply_dtc_region(df: pd.DataFrame, region: str) -> pd.DataFrame:
    out = df.copy()
    region = region if region in DTC_REGION_CHOICES else "all"
    prefix = {"all": "DTC_Total", "us": "DTC_US", "eu": "DTC_EU"}[region]
    dtc_columns = [
        ("DTC_Revenue", "Revenue"),
        ("DTC_Hardware", "Hardware"),
        ("DTC_Addons", "Addons"),
        ("DTC_Merch", "Merch"),
        ("DTC_Seeds", "Seeds"),
        ("DTC_Gift_Bag", "Gift_Bag"),
        ("DTC_Subscription", "Subscription"),
        ("DTC_Subscription_Taxes", "Subscription_Taxes"),
        ("DTC_Taxes", "Taxes"),
        ("DTC_Shipping", "Shipping"),
        ("DTC_Gift_Cards", "Gift_Cards"),
        ("DTC_Unallocated", "Unallocated"),
        ("DTC_Orders", "Orders"),
        ("DTC_Hardware_Units", "Hardware_Units"),
        ("DTC_Addons_Units", "Addons_Units"),
        ("DTC_Merch_Units", "Merch_Units"),
        ("DTC_Seeds_Units", "Seeds_Units"),
        ("DTC_Subscription_Units", "Subscription_Units"),
    ]
    for target_col, suffix in dtc_columns:
        source_col = f"{prefix}_{suffix}"
        if source_col in out.columns:
            out[target_col] = numeric_col(out, source_col)
    spend_col = {"all": "DTC_Total_Spend", "us": "DTC_US_Spend", "eu": "DTC_EU_Spend"}[region]
    out["Total_DTC_Spend"] = numeric_col(out, spend_col)
    if region in {"us", "eu"}:
        for metric_col in [
            "Web_CR",
            "Web_AOV",
            "Web_AOV_WO_Renewals",
            "fAOV",
            "rAOV",
            "Web_RPU",
            "Web_RPU_WO_Renewals",
            "fRPU",
            "rRPU",
            "Customers",
            "Returning_Customers",
            "First_Time_Customers",
        ]:
            source_col = f"{metric_col}_{region.upper()}"
            if source_col in out.columns:
                out[metric_col] = pd.to_numeric(out[source_col], errors="coerce")
        for channel in ["Meta", "Google"]:
            segmented = f"{channel}_Spend_{region.upper()}"
            if segmented in out.columns:
                out[f"{channel}_Spend"] = numeric_col(out, segmented)
        if region == "eu":
            for col in ["Bing_Spend", "TikTok_Spend", "Nextdoor_Spend", "Affiliate_Fees"]:
                if col in out.columns:
                    out[col] = 0.0
    for base_col in product_base_cols(out, "dtc"):
        suffix = base_col.removeprefix("dtc_")
        source_col = base_col if region == "all" else f"dtc_{region}_{suffix}"
        if source_col in out.columns:
            out[base_col] = numeric_col(out, source_col)
    return out


def dtc_region_label(region: str) -> str:
    return DTC_REGION_CHOICES.get(region, DTC_REGION_CHOICES["all"])


def prepare_amazon_segments(df: pd.DataFrame) -> pd.DataFrame:
    out = df

    def ensure_pair(base_col: str, us_col: str, eu_col: str) -> None:
        base = numeric_col(out, base_col)
        us = numeric_col(out, us_col) if us_col in out.columns else pd.Series(0.0, index=out.index)
        eu = numeric_col(out, eu_col) if eu_col in out.columns else pd.Series(0.0, index=out.index)
        unsplit = (us.fillna(0) + eu.fillna(0) == 0) & (base.fillna(0) != 0)
        out[us_col] = us.mask(unsplit, base)
        out[eu_col] = eu.mask(unsplit, 0.0)

    for suffix in ["Revenue", "Hardware", "Addons", "Tax", "Shipping", "GiftWrap", "Orders", "Hardware_Units", "Addons_Units"]:
        ensure_pair(f"Amazon_{suffix}", f"Amazon_US_{suffix}", f"Amazon_EU_{suffix}")
    ensure_pair("Amazon_Spend", "Amazon_Spend_US", "Amazon_Spend_EU")

    for base_col in product_base_cols(out, "amazon"):
        suffix = base_col.removeprefix("amazon_")
        ensure_pair(base_col, f"amazon_us_{suffix}", f"amazon_eu_{suffix}")
    return out


def apply_amazon_region(df: pd.DataFrame, region: str) -> pd.DataFrame:
    out = df.copy()
    region = region if region in AMAZON_REGION_CHOICES else "all"
    if region == "all":
        return out

    prefix = f"Amazon_{region.upper()}"
    for target_col, suffix in [
        ("Amazon_Revenue", "Revenue"),
        ("Amazon_Hardware", "Hardware"),
        ("Amazon_Addons", "Addons"),
        ("Amazon_Tax", "Tax"),
        ("Amazon_Shipping", "Shipping"),
        ("Amazon_GiftWrap", "GiftWrap"),
        ("Amazon_Orders", "Orders"),
        ("Amazon_Hardware_Units", "Hardware_Units"),
        ("Amazon_Addons_Units", "Addons_Units"),
    ]:
        source_col = f"{prefix}_{suffix}"
        if source_col in out.columns:
            out[target_col] = numeric_col(out, source_col)

    spend_col = f"Amazon_Spend_{region.upper()}"
    if spend_col in out.columns:
        out["Amazon_Spend"] = numeric_col(out, spend_col)

    for metric_col in ["Amazon_RPU", "aROAS", "aSPU"]:
        source_col = f"{metric_col}_{region.upper()}"
        if source_col in out.columns:
            out[metric_col] = pd.to_numeric(out[source_col], errors="coerce")

    for base_col in product_base_cols(out, "amazon"):
        suffix = base_col.removeprefix("amazon_")
        source_col = f"amazon_{region}_{suffix}"
        if source_col in out.columns:
            out[base_col] = numeric_col(out, source_col)
    return out


def amazon_region_label(region: str) -> str:
    return AMAZON_REGION_CHOICES.get(region, AMAZON_REGION_CHOICES["all"])


# Renewal revenue needs no outside source: the workbook reports the subscription as
# its own line throughout, and its "w/o Subscriptions" region header is the same
# figure as its "revenue w/o renewals", so dropping that line is the exclusion.
#
# Order counts and pre-2026 subscription tax are the exceptions. The workbook counts
# renewal orders inside its DTC order total with no line to separate them, and its
# subscription unit count only starts in October 2024 and runs at 55-91% of all
# orders, so it cannot stand in. The Metorik export (see
# scripts/build_renewals_series.py) is the only renewal order count there is.
RENEWAL_COLS = ["Renewal_Orders", "Renewal_Tax"]

# Europe's export reports euros against a workbook kept in dollars at the daily rate,
# so only the two currency-free quantities cross over: the order count, which agrees
# with the workbook's own EU order total month for month, and the tax share.
EU_RENEWAL_COLS = {"Renewal_Orders": "Renewal_Orders_EU", "Renewal_Tax_Share": "Renewal_Tax_Share_EU"}

# The workbook reports subscription tax as its own line only from January 2026.
SUBSCRIPTION_TAX_SPLIT_FROM = pd.Timestamp("2026-01-01")

# Europe's subscription tax is plain VAT: the workbook's own effective rate is 21.0%
# in every month of 2026, so it carries the earlier years too.
EU_SUBSCRIPTION_TAX_RATE = 0.21

# The lines the Summary sheet adds up to reach DTC Revenue, split the way the
# workbook splits them. Its "w/o Subscriptions" region header is the product side
# alone, and is the same figure as its "revenue w/o renewals", so excluding
# renewals is exactly dropping the subscription side.
DTC_PRODUCT_PARTS = ["Hardware", "Addons", "Merch", "Seeds", "Gift_Bag", "Taxes", "Shipping", "Gift_Cards", "Unallocated"]
DTC_SUBSCRIPTION_PARTS = ["Subscription", "Subscription_Taxes"]
DTC_REVENUE_PARTS = DTC_PRODUCT_PARTS + DTC_SUBSCRIPTION_PARTS


def merge_renewals_file(df: pd.DataFrame, filename: str, columns: Dict[str, str]) -> pd.DataFrame:
    """Merge one Metorik series onto the daily frame, zero where it has no coverage."""
    out = df.copy()
    path = DATA_DIR / filename
    if not path.exists():
        for target in columns.values():
            out[target] = 0.0
        return out
    ren = pd.read_csv(path, usecols=["Date"] + list(columns))
    ren["Date"] = pd.to_datetime(ren["Date"], errors="coerce")
    # Shares average over a repeated day where amounts and counts add up.
    how = {col: "mean" if "Share" in col else "sum" for col in columns}
    ren = ren.dropna(subset=["Date"]).groupby("Date", as_index=False).agg(how)
    out = out.merge(ren.rename(columns=columns), on="Date", how="left")
    for target in columns.values():
        out[target] = pd.to_numeric(out[target], errors="coerce").fillna(0.0).clip(lower=0.0)
    return out


def attach_renewals(df: pd.DataFrame) -> pd.DataFrame:
    out = merge_renewals_file(df, "renewals_daily_us.csv", {col: col for col in RENEWAL_COLS})
    return merge_renewals_file(out, "renewals_daily_eu.csv", EU_RENEWAL_COLS)


def split_subscription_tax(df: pd.DataFrame) -> pd.DataFrame:
    """Separate subscription tax from product tax before January 2026.

    Until then the workbook has no subscription tax line and its region tax row is
    the whole tax, subscriptions included. Nothing is missing from the total: that
    row equals the P&L's total tax to the cent for every month through December
    2025, and from 2026 the two rows split and add back to the same figure. Only
    the split is absent, which would otherwise leave the product tax line, and so
    the excl-renewals headline, overstated for the earlier years.

    So the amount is moved between the two lines and the total is untouched. Both
    stores are measured rather than modelled, and both agree closely with the
    workbook's own subscription tax over the months where the two overlap: 0.09% for
    the US, which takes Metorik's renewal tax directly, and 0.07% for Europe, which
    takes Metorik's renewal share of tax and applies it to the workbook's own euro-
    free tax line. Europe falls back to the VAT rate only before its renewals begin,
    where a renewal share of zero would otherwise miss the tax on new subscriptions.
    """
    if "Date" not in df.columns:
        return df
    out = df.copy()
    early = out["Date"] < SUBSCRIPTION_TAX_SPLIT_FROM
    zero = pd.Series(0.0, index=out.index)
    renewal_tax = numeric_col(out, "Renewal_Tax") if "Renewal_Tax" in out.columns else zero
    eu_subscription = numeric_col(out, "DTC_EU_Subscription") if "DTC_EU_Subscription" in out.columns else zero
    eu_share = numeric_col(out, "Renewal_Tax_Share_EU") if "Renewal_Tax_Share_EU" in out.columns else zero
    eu_tax = numeric_col(out, "DTC_EU_Taxes") if "DTC_EU_Taxes" in out.columns else zero
    eu_shift = (eu_tax * eu_share).where(eu_share > 0, eu_subscription * EU_SUBSCRIPTION_TAX_RATE)
    shifts = {
        "US": renewal_tax.where(early, 0.0),
        "EU": eu_shift.where(early, 0.0),
    }
    updates: Dict[str, pd.Series] = {}
    for scope, shift in shifts.items():
        tax_col, sub_tax_col = f"DTC_{scope}_Taxes", f"DTC_{scope}_Subscription_Taxes"
        if tax_col not in out.columns or sub_tax_col not in out.columns:
            shifts[scope] = zero
            continue
        # Never carve out more tax than the line holds, so it cannot go negative.
        shift = shift.clip(lower=0.0, upper=numeric_col(out, tax_col).clip(lower=0.0))
        shifts[scope] = shift
        updates[tax_col] = numeric_col(out, tax_col) - shift
        updates[sub_tax_col] = numeric_col(out, sub_tax_col) + shift
    combined = sum(shifts.values())
    for col, sign in (("DTC_Taxes", -1.0), ("DTC_Subscription_Taxes", 1.0)):
        if col in out.columns:
            updates[col] = numeric_col(out, col) + sign * combined
    if updates:
        out = pd.concat(
            [out.drop(columns=[c for c in updates if c in out.columns]), pd.DataFrame(updates, index=out.index)],
            axis=1,
        )
    return out


def rebased_rates(
    df: pd.DataFrame,
    scope: str,
    product_revenue: pd.Series,
    orders_before: pd.Series,
    orders_after: pd.Series,
    removed_orders: pd.Series,
) -> Dict[str, pd.Series]:
    """Rebuild the per-order rates the workbook stores as finished figures.

    Revenue and order columns drop the subscription side under the toggle, but AOV and
    the customer mix arrive pre-computed and would keep reporting the full basis, so
    the visualization tab would contradict the cards above it. AOV is the workbook's
    own revenue over its own orders to the cent for every day on record, so it is
    rebuilt the same way from the adjusted pair.

    The mix is rebased on the workbook's own percentages rather than on the returning
    order columns, whose 2024 values sit on a basis that does not reconcile with them.
    A renewal is by definition a repeat purchase, so it leaves the returning side and
    the base while first-time orders stand.

    Web CR is deliberately left alone: it is pasted in from analytics, where an
    automatic renewal never produced a session or a checkout, so it already counts new
    sales only and scaling it would remove renewals twice.
    """
    suffix = "" if scope == "Total" else f"_{scope}"
    base = orders_after.replace(0.0, np.nan)
    updates: Dict[str, pd.Series] = {}
    aov_col = f"Web_AOV{suffix}"
    if aov_col in df.columns:
        updates[aov_col] = product_revenue.clip(lower=0.0) / base
    returning_col = f"Returning_Customers{suffix}"
    if returning_col in df.columns:
        returning_orders = numeric_col(df, returning_col) * orders_before - removed_orders
        updates[returning_col] = (returning_orders / base).clip(lower=0.0, upper=1.0)
    first_col = f"First_Time_Customers{suffix}"
    if first_col in df.columns:
        updates[first_col] = (numeric_col(df, first_col) * orders_before / base).clip(lower=0.0, upper=1.0)
    return updates


def apply_renewals_exclusion(df: pd.DataFrame, enabled: bool) -> pd.DataFrame:
    """Set DTC revenue to the Summary sheet total, optionally net of renewals.

    Off, DTC revenue is the Summary sheet's DTC Revenue: the product lines plus the
    subscription line and its tax, so the breakdown adds up to the headline. On, the
    subscription side comes off and the product lines alone are the headline, which
    is the workbook's own "w/o Subscriptions" region header.

    The workbook reports the subscription as its own line for the whole history, so
    this holds for every date range without needing the Metorik series to size it.

    Applied before the region transforms so the corrected US and combined figures
    propagate into the active DTC columns, and applied identically to the current
    and prior-year windows so year-over-year stays like-for-like. The rates the
    workbook stores pre-computed are rebuilt alongside, so the visualization tab
    reads the same basis as the cards.
    """
    if "Date" not in df.columns:
        return df
    out = df.copy()
    zero = pd.Series(0.0, index=out.index)

    def renewals(col: str) -> pd.Series:
        return numeric_col(out, col) if col in out.columns else zero

    us_renewals, eu_renewals = renewals("Renewal_Orders"), renewals("Renewal_Orders_EU")
    renewal_orders = {"US": us_renewals, "EU": eu_renewals, "Total": us_renewals + eu_renewals}
    updates: Dict[str, pd.Series] = {}

    def total_of(scope: str, wanted: Sequence[str]) -> pd.Series:
        present = [numeric_col(out, f"DTC_{scope}_{part}") for part in wanted if f"DTC_{scope}_{part}" in out.columns]
        return sum(present) if present else zero

    for scope in ("US", "EU", "Total"):
        product = total_of(scope, DTC_PRODUCT_PARTS)
        subscriptions = total_of(scope, DTC_SUBSCRIPTION_PARTS)
        if not enabled:
            updates[f"DTC_{scope}_Revenue"] = product + subscriptions
            continue
        updates[f"DTC_{scope}_Revenue"] = product.clip(lower=0.0)
        # The subscription side is off the headline, so its lines are cleared to keep
        # the breakdown adding up.
        for part in DTC_SUBSCRIPTION_PARTS:
            if f"DTC_{scope}_{part}" in out.columns:
                updates[f"DTC_{scope}_{part}"] = zero
        scope_orders = renewal_orders[scope]
        orders_before = numeric_col(out, f"DTC_{scope}_Orders") if f"DTC_{scope}_Orders" in out.columns else zero
        for col in (f"DTC_{scope}_Orders", f"DTC_{scope}_Subscription_Units"):
            if col in out.columns:
                updates[col] = (numeric_col(out, col) - scope_orders).clip(lower=0.0)
        updates.update(
            rebased_rates(
                out,
                scope,
                product,
                orders_before,
                (orders_before - scope_orders).clip(lower=0.0),
                scope_orders,
            )
        )
        if scope == "Total" and "Total_Revenue" in out.columns:
            updates["Total_Revenue"] = (numeric_col(out, "Total_Revenue") - subscriptions).clip(lower=0.0)
    if updates:
        out = pd.concat(
            [out.drop(columns=[c for c in updates if c in out.columns]), pd.DataFrame(updates, index=out.index)],
            axis=1,
        )
    return out


def survey_participants(df: pd.DataFrame) -> pd.Series:
    if "q0_participants" in df.columns:
        return pd.to_numeric(df["q0_participants"], errors="coerce").fillna(0)
    q1_cols = [col for col in df.columns if col.startswith("q1_")]
    if not q1_cols:
        return pd.Series(0.0, index=df.index)
    return df[q1_cols].fillna(0).sum(axis=1)


def engagement_frame(survey_df: pd.DataFrame, revenue_df: pd.DataFrame, by_month: bool) -> pd.DataFrame:
    if survey_df.empty:
        return pd.DataFrame(columns=["Date", "Participants", "Denominator", "Rate"])
    survey = survey_df[["Date"]].copy()
    survey["Participants"] = survey_participants(survey_df)
    if "q0_engagement_rate" in survey_df.columns:
        survey["ImportedRate"] = pd.to_numeric(survey_df["q0_engagement_rate"], errors="coerce")
    else:
        survey["ImportedRate"] = np.nan
    if "DTC_Orders" in revenue_df.columns:
        orders = revenue_df[["Date", "DTC_Orders"]].copy()
        orders["DTC_Orders"] = pd.to_numeric(orders["DTC_Orders"], errors="coerce").fillna(0)
    else:
        orders = pd.DataFrame({"Date": revenue_df["Date"], "DTC_Orders": 0.0})
    out = pd.merge(survey, orders, on="Date", how="left").fillna({"DTC_Orders": 0})
    has_imported = out["ImportedRate"].notna()
    positive_imported = has_imported & (out["ImportedRate"] > 0)
    out["Denominator"] = out["DTC_Orders"]
    out.loc[positive_imported, "Denominator"] = out.loc[positive_imported, "Participants"] / out.loc[positive_imported, "ImportedRate"]
    fallback_rate = np.where(out["DTC_Orders"] > 0, out["Participants"] / out["DTC_Orders"], 0)
    out["Rate"] = np.where(has_imported, out["ImportedRate"].fillna(0), fallback_rate)
    if by_month:
        work = monthly_date(out[["Date", "Participants", "Denominator"]])
        out = work.groupby("Date", as_index=False)[["Participants", "Denominator"]].sum()
        out["Rate"] = np.where(out["Denominator"] > 0, out["Participants"] / out["Denominator"], 0)
    return out[["Date", "Participants", "Denominator", "Rate"]]

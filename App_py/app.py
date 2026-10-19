from __future__ import annotations

import base64
import html
import os
import re
import secrets
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import numpy as np
import pandas as pd
import plotly.graph_objects as go
from shiny import App, Inputs, Outputs, Session, reactive, render, ui
from shinywidgets import output_widget, render_widget

from dataprep import (
    AMAZON_REGION_CHOICES,
    DTC_PRODUCT_PARTS,
    DTC_REGION_CHOICES,
    DTC_REVENUE_PARTS,
    DTC_SUBSCRIPTION_PARTS,
    EU_RENEWAL_COLS,
    EU_SUBSCRIPTION_TAX_RATE,
    RENEWAL_COLS,
    SUBSCRIPTION_TAX_SPLIT_FROM,
    amazon_region_label,
    apply_amazon_region,
    apply_dtc_region,
    apply_renewals_exclusion,
    attach_renewals,
    dtc_region_label,
    engagement_frame,
    group_campaign_note_lines,
    load_csv,
    merge_renewals_file,
    monthly_date,
    numeric_col,
    prepare_amazon_segments,
    prepare_dtc_segments,
    product_base_cols,
    rebased_rates,
    rebuild_unit_totals,
    split_subscription_tax,
    survey_participants,
)
from figures import empty_fig, fig_date_tickformat, finish_fig, normalize_fig_dates
from formatting import (
    fmt_detail_rate,
    fmt_money,
    fmt_money_r,
    fmt_num,
    fmt_pct,
    fmt_rate,
    safe_div,
    to_rgba,
    weighted_mean,
    yoy_pct_html,
)


ROOT = Path(__file__).parent
DATA_DIR = ROOT / "data"


revenue_data = load_csv("revenue_data.csv", ["Date"])
survey_data = load_csv("survey_data.csv", ["Date"])
campaign_notes_df = group_campaign_note_lines(load_csv("campaign_notes.csv", ["start", "end"]))


ADDITIVE_COLS = [
    "DTC_Revenue",
    "DTC_Hardware",
    "DTC_Addons",
    "DTC_Merch",
    "DTC_Seeds",
    "DTC_Subscription",
    "DTC_Subscription_Taxes",
    "DTC_Taxes",
    "DTC_Shipping",
    "DTC_Gift_Cards",
    "DTC_Unallocated",
    "Amazon_Revenue",
    "Amazon_US_Revenue",
    "Amazon_EU_Revenue",
    "Amazon_UK_Revenue",
    "Amazon_FR_Revenue",
    "Amazon_GER_Revenue",
    "Amazon_Hardware",
    "Amazon_US_Hardware",
    "Amazon_EU_Hardware",
    "Amazon_Addons",
    "Amazon_US_Addons",
    "Amazon_EU_Addons",
    "Amazon_Tax",
    "Amazon_US_Tax",
    "Amazon_EU_Tax",
    "Amazon_Shipping",
    "Amazon_US_Shipping",
    "Amazon_EU_Shipping",
    "Amazon_GiftWrap",
    "Amazon_US_GiftWrap",
    "Amazon_EU_GiftWrap",
    "Rachio_Revenue",
    "Weatherflow_Revenue",
    "Digital_Marketplaces_Revenue",
    "Huckberry_Revenue",
    "Total_Revenue",
    "B2B_Revenue",
    "BestBuy_Revenue",
    "Target_Revenue",
    "Walmart_Revenue",
    "Walmart_Retail_Revenue",
    "Costco_Revenue",
    "Chewy_Revenue",
    "Ace_Hardware_Revenue",
    "Retail_Revenue",
    "Total_Retail_Revenue",
    "Total_DM_Revenue",
    "Total_B2B_Revenue",
    "Costco_Hardware",
    "Costco_Tax",
    "Costco_Shipping",
    "App_Revenue",
    "Google_Store",
    "Apple_Store",
    "DTC_Orders",
    "DTC_Hardware_Units",
    "DTC_Addons_Units",
    "DTC_Subscription_Units",
    "Amazon_Orders",
    "Amazon_US_Orders",
    "Amazon_EU_Orders",
    "Amazon_UK_Orders",
    "Amazon_FR_Orders",
    "Amazon_GER_Orders",
    "Amazon_Hardware_Units",
    "Amazon_Addons_Units",
    "Amazon_US_Hardware_Units",
    "Amazon_EU_Hardware_Units",
    "Amazon_US_Addons_Units",
    "Amazon_EU_Addons_Units",
    "Total_Orders",
    "B2B_Orders",
    "BestBuy_Orders",
    "Target_Orders",
    "Walmart_Orders",
    "Walmart_Retail_Orders",
    "Costco_Orders",
    "Chewy_Orders",
    "Ace_Hardware_Orders",
    "Retail_Orders",
    "Total_Retail_Orders",
    "Total_DM_Orders",
    "Total_B2B_Orders",
    "Huckberry_Orders",
    "App_Orders",
    "Google_Store_Orders",
    "Apple_Store_Orders",
    "Meta_Spend",
    "Google_Spend",
    "Bing_Spend",
    "TikTok_Spend",
    "Snapchat_Spend",
    "Amazon_Spend",
    "Amazon_Spend_US",
    "Amazon_Spend_EU",
    "Amazon_Spend_UK",
    "Amazon_Spend_FR",
    "Amazon_Spend_GER",
    "Nextdoor_Spend",
    "IndieGoGo_Spend",
    "BestBuy_Spend",
    "Target_Spend",
    "Walmart_Spend",
    "Chewy_Spend",
    "Retail_Spend",
    "Affiliate_Fees",
    "Rachio_Fees",
    "Weatherflow_Fees",
    "Costco_Fees",
    "Total_DTC_Spend",
    "Total_Spend",
    "App_Spend_Meta",
    "App_Spend_Apple",
    "App_Spend_Google",
    "Total_App_Spend",
]
for col in ADDITIVE_COLS:
    if col in revenue_data.columns:
        revenue_data[col] = revenue_data[col].fillna(0)


DATE_MIN = revenue_data["Date"].min().date()

# The current month is zero-filled to its last calendar day, so anchor the selectable
# range to the newest day that actually carries activity.
ACTIVITY_COLS = [
    col
    for col in ("Total_Revenue", "Total_Spend", "Total_Orders", "DTC_Revenue", "Amazon_Revenue", "B2B_Revenue")
    if col in revenue_data.columns
]
if ACTIVITY_COLS:
    _active_days = revenue_data[ACTIVITY_COLS].abs().sum(axis=1, skipna=True) > 0
else:
    _active_days = pd.Series(False, index=revenue_data.index)
if bool(_active_days.any()):
    DATE_MAX = revenue_data.loc[_active_days, "Date"].max().date()
else:
    DATE_MAX = revenue_data["Date"].max().date()

DEFAULT_DATE_START = DATE_MAX.replace(day=1)
DEFAULT_DATE_END = DATE_MAX


PALETTE = {
    "green": "#2ecc71",
    "red": "#A52A2A",
    "blue": "#3498db",
    "yellow": "#f1c40f",
    "purple": "#9b59b6",
    "gray": "#7b868c",
    "dark": "#34495e",
    "orange": "#f39c12",
}
SET2 = [
    "#66c2a5",
    "#fc8d62",
    "#8da0cb",
    "#e78ac3",
    "#a6d854",
    "#ffd92f",
    "#e5c494",
    "#b3b3b3",
]


def existing(cols: Iterable[str], data: Optional[pd.DataFrame] = None) -> List[str]:
    df = revenue_data if data is None else data
    return [col for col in cols if col in df.columns]


def sum_cols(df: pd.DataFrame, cols: Iterable[str]) -> pd.Series:
    keep = existing(cols, df)
    if not keep:
        return pd.Series(0, index=df.index, dtype="float64")
    return df[keep].fillna(0).sum(axis=1)


def sum_value(df: pd.DataFrame, col: str) -> float:
    if col not in df.columns:
        return 0.0
    return float(pd.to_numeric(df[col], errors="coerce").fillna(0).sum())


# Marks where the subscription side of the breakdown begins.
DTC_SUBSCRIPTION_LABEL = "Subscriptions"

RENEWALS_HINT = (
    "Takes the subscription line, its tax and every renewal order out of DTC, so revenue, "
    "ROAS, AOV and the customer mix count new sales only. Applied to the prior-year side of "
    "the comparison too. Web CR already counts web checkouts only, so it is unchanged."
)

BLENDED_WO_RENEWALS_NOTE = (
    "Total revenue less the subscription line and its tax, divided by total spend. "
    "Built from the figures on this page, so it follows the date range and moves with them."
)
BLENDED_WO_RENEWALS_RETAIL_NOTE = (
    "Same as the line above with retail revenue added on top, divided by total spend. "
    "Retail is Target, Best Buy, Chewy, Walmart, Walmart Retail, Costco and Ace Hardware, "
    "and it is otherwise kept out of total revenue."
)
BLENDED_SHEETS_NOTE = (
    "The historical figure as calculated in the Summary sheets, carried across unchanged. "
    "It can differ from the line above: it is a daily rate averaged over the range rather "
    "than a single division, and its retail figures predate the sell-through workbook, so "
    "Best Buy in particular is lower there."
)

# The store moved off Shopify at the end of June 2023, and the workbooks changed shape with
# it: from July the components are reported on a tab that adds up to the headline, before
# that they are not. Both facts belong on the same note.
WOOCOMMERCE_FROM = pd.Timestamp("2023-07-01")
DTC_PLATFORM_NOTE = (
    "Revenue up to June 2023 is Shopify. The store moved to WooCommerce in July 2023, which "
    "is the source from then on. The Shopify workbooks report their product lines on a "
    "separate tab that does not tie to the day's takings, so that gap is shown as "
    "Unallocated rather than being credited to a product."
)
INDIEGOGO_CAMPAIGN_ENDED = pd.Timestamp("2021-11-01")
INDIEGOGO_CAMPAIGN_NOTE = (
    "The first crowdfunding campaign, which ran to October 2021 and which the Sales tab of "
    "that era carries as a single line beside the store's own takings. Only the money raised "
    "is reported for those months, so the breakdown and the order count below stay empty; the "
    "2023 campaign reports both."
)
DTC_GIFT_CARDS_NOTE = (
    "Gift card sales, which the Shopify-era workbooks report as their own line: $91k over "
    "the December 2022 holidays, then $22-30k a month to May 2023. Separate from Gift Bag, "
    "which is a physical product. Later workbooks do not report them, so the line stops "
    "after June 2023."
)
DTC_UNALLOCATED_NOTE = (
    "Revenue the Shopify-era workbooks do not break down. From July 2021 through September "
    "2022 they do not split revenue by product at all, so nearly all of it sits here; unit "
    "counts for those months are still reported and come through. From October 2022 the "
    "product lines arrive, reported gross while the headline is net, so the two rarely tie: "
    "the breakdown sits about 4% above the headline in November 2022, when discounting was "
    "heaviest, and the gap narrows month by month until it is within a point either way from "
    "March 2023, reading negative wherever the breakdown comes out above the headline. Kept "
    "as its own line so the breakdown still adds up to the headline without crediting a "
    "product with revenue it cannot account for."
)


# The tax split works on the workbook's own columns, so it runs before the region
# transforms derive the combined and per-region figures from them.
revenue_data = prepare_amazon_segments(prepare_dtc_segments(split_subscription_tax(attach_renewals(revenue_data))))


def date_window(value: Tuple[object, object]) -> Tuple[pd.Timestamp, pd.Timestamp]:
    start, end = value
    return pd.Timestamp(start), pd.Timestamp(end)


def prev_year_window(start: pd.Timestamp, end: pd.Timestamp) -> Tuple[pd.Timestamp, pd.Timestamp]:
    return start - pd.DateOffset(years=1), end - pd.DateOffset(years=1)


def spans_more_than_two_months(value: Tuple[object, object]) -> bool:
    start, end = date_window(value)
    return bool(pd.notna(start) and pd.notna(end) and end > start + pd.DateOffset(months=2))


def aggregate_sum(df: pd.DataFrame, cols: Sequence[str], by_month: bool) -> pd.DataFrame:
    keep = ["Date"] + existing(cols, df)
    out = df[keep].copy()
    for col in cols:
        if col not in out.columns:
            out[col] = 0
    if by_month:
        out = monthly_date(out).groupby("Date", as_index=False)[list(cols)].sum()
    return out


def tag_card(title: str, value: str, accent: str, subtitle: Optional[str] = None):
    return ui.div(
        ui.div(title, class_="metric-label"),
        ui.div(value, class_="metric-value", style=f"color:{accent};"),
        ui.div(subtitle or "", class_="metric-subtitle"),
        class_="metric-card",
    )


def summary_detail(content: str):
    return ui.div(ui.HTML(content), class_="summary-detail")


def summary_click_metric(
    title: str,
    value: str,
    *,
    color_class: str,
    input_id: Optional[str] = None,
    detail: Optional[str] = None,
    yoy: Optional[str] = None,
    note: Optional[str] = None,
):
    value_tag = (
        ui.input_action_button(input_id, value, class_=f"summary-click-value {color_class}")
        if input_id
        else ui.div(value, class_=f"summary-value {color_class}")
    )
    label = (
        ui.HTML(f'{html.escape(title)}<i class="summary-detail-note" data-note="{html.escape(note, quote=True)}">i</i>')
        if note
        else title
    )
    return ui.div(
        ui.div(label, class_="summary-sub-label"),
        value_tag,
        ui.HTML(yoy) if yoy else None,
        summary_detail(detail) if detail else None,
        class_="summary-item",
    )


def summary_plain_metric(title: str, value: str, *, title_class: str, input_id: Optional[str] = None, detail: Optional[str] = None, yoy: Optional[str] = None):
    value_tag = (
        ui.input_action_button(input_id, value, class_="summary-click-value summary-black")
        if input_id
        else ui.div(value, class_="summary-value summary-black")
    )
    return ui.div(
        ui.div(title, class_=title_class),
        value_tag,
        ui.HTML(yoy) if yoy else None,
        summary_detail(detail) if detail else None,
        class_="summary-item",
    )


def summary_kpi(label: str, value: str, input_id: Optional[str] = None, detail: Optional[str] = None, yoy: Optional[str] = None):
    value_tag = (
        ui.input_action_button(input_id, value, class_="summary-kpi-click")
        if input_id
        else ui.div(value, class_="summary-kpi-value")
    )
    return ui.div(
        ui.div(ui.HTML(label), class_="summary-kpi-label"),
        value_tag,
        ui.HTML(yoy) if yoy else None,
        summary_detail(detail) if detail else None,
        class_="summary-kpi",
    )


def summary_order(label: str, value: str, input_id: str, detail: Optional[str] = None, yoy: Optional[str] = None):
    return ui.div(
        ui.input_action_button(input_id, value, class_="summary-order-value"),
        ui.div(label, class_="summary-order-label"),
        ui.HTML(yoy) if yoy else None,
        summary_detail(detail) if detail else None,
        class_="summary-order",
    )


def summary_band(title: str, value: str, kind: str, tooltip: str, yoy: Optional[str] = None):
    return ui.div(
        ui.div(
            ui.span(title, class_="summary-band-label"),
            ui.span(
                ui.span("i", class_=f"summary-info {'red' if kind == 'spend' else 'green'}"),
                ui.span(tooltip, class_="summary-tooltip-text"),
                class_="summary-tooltip-container",
            ),
            class_="summary-band-title",
        ),
        ui.div(
            ui.span(value, class_="summary-band-value-text"),
            ui.HTML(yoy) if yoy else None,
            class_="summary-band-value",
        ),
        class_=f"summary-total-band {kind}",
    )


def section(title: str, output_id: str, *controls, height: int = 500, sku_export: bool = False):
    return ui.div(
        ui.div(
            ui.h2(ui.HTML(title), class_="section-title"),
            ui.div(*controls, class_="control-row") if controls else None,
            class_="section-head",
        ),
        ui.div(
            output_widget(output_id, width="100%", height=f"{height}px"),
            ui.div(
                export_button(output_id, by_sku=True),
                export_button(output_id),
                class_="chart-export-bar",
            )
            if sku_export
            else export_button(output_id),
            class_="chart-card",
        ),
        class_="app-section",
    )


def export_button(output_id: str, by_sku: bool = False):
    if by_sku:
        return ui.download_button(
            f"download_{output_id}_sku",
            "SKU",
            class_="chart-export",
            title="Export CSV with SKU codes instead of product names",
        )
    return ui.download_button(
        f"download_{output_id}",
        "CSV",
        class_="chart-export",
        title="Export CSV",
    )


def clean_select(input_id: str, label, choices, *, selected=None, width: Optional[str] = None):
    return ui.input_select(input_id, label, choices, selected=selected, width=width)


def menu_title(icon_svg: str, text: str):
    return ui.HTML(f'<span class="menu-title"><span class="menu-icon">{icon_svg}</span>{text}</span>')


ICON_CHART_LINE = """
<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 19h18"/><path d="m5 15 4-4 4 3 6-7"/></svg>
"""
ICON_CHART_BAR = """
<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 19h18"/><path d="M7 16V9"/><path d="M12 16V5"/><path d="M17 16v-3"/></svg>
"""
ICON_DOLLAR = """
<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2v20"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7H14a3.5 3.5 0 0 1 0 7H6"/></svg>
"""
ICON_PIE = """
<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12A9 9 0 1 1 12 3v9Z"/><path d="M12 3a9 9 0 0 1 9 9h-9Z"/></svg>
"""
ICON_CLIPBOARD = """
<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 3h6l1 2h3v16H5V5h3Z"/><path d="m9 14 2 2 4-5"/></svg>
"""


def product_img(src: str, alt: str, badge: Optional[str] = None):
    classes = ["product-image-wrap"]
    if badge:
        classes.append("is-pro")
    if src in {"nature-cam.svg", "nature-cam-icon.png"}:
        classes.append("is-nature-cam")
    return ui.div(
        ui.tags.img(src=src, alt=alt, class_="product-img"),
        ui.span(badge, class_="product-badge") if badge else None,
        class_=" ".join(classes),
    )


def merged_control():
    return ui.div(
        ui.div(
            ui.div(
                ui.input_radio_buttons(
                    "pnl_channel_preset",
                    "Preset",
                    {key: label for key, (label, _) in PNL_CHANNEL_PRESETS.items()},
                    selected="all",
                    inline=True,
                ),
                class_="pnl-preset-control",
            ),
            ui.div(
                ui.div(
                    ui.input_checkbox("pnl_sku_mix", "SKU mix", False),
                    class_="date-toggle",
                    title=(
                        "Show each row as a share of its channel's feeder units instead of a count. "
                        "Hardware reads as a mix adding to 100%; add-ons, seeds and gift bags read as "
                        "an attach rate per feeder. Channels with no feeders of their own show nothing."
                    ),
                ),
                ui.div(
                    ui.input_checkbox("pnl_merge_products", "Merge products", False),
                    class_="date-toggle",
                ),
                ui.div(
                    ui.input_checkbox("pnl_merge_families", "Merge SBF/HBF", False),
                    class_="date-toggle",
                    title=(
                        "One line per feeder family, with each retail bundle kept on its own row "
                        "and Nature Cam PRO reported as hardware. Colour and PRO variants collapse "
                        "into the family line."
                    ),
                ),
                class_="pnl-merge-toggle",
            ),
            class_="pnl-control-head",
        ),
        ui.div(
            ui.input_checkbox_group(
                "pnl_channels",
                "Channels",
                {channel: channel_header(channel) for channel in PNL_UNIT_CHANNELS},
                selected=PNL_UNIT_CHANNELS,
                inline=True,
            ),
            class_="pnl-channel-picker",
        ),
        class_="pnl-control-row",
    )


SURVEY_TITLES = {
    "Q1": "Q1: Where did you hear about Bird Buddy?",
    "Q2": "Q2: Where on FB/IG have you heard about Bird Buddy?",
    "Q3": "Q3: Who is this for?",
    "Q4": "Q4: Are you a new or existing customer?",
    "Q5": "Q5: Did you buy this for your household?",
    "Q6": "Q6: Did you buy this as a gift?",
    "Q7": "Q7: Will Bird Buddy be the first bird feeder in your yard?",
    "Q8": "Q8: How old are you?",
    "Q9": "Q9: What is your gender?",
    "Q10": "Q10: Did you compare us with other smart bird feeders before purchasing?",
    "Q11": "Q11: How important is acquiring knowledge in bird feeding?",
    "Q12": "Q12: How would you rate your bird knowledge?",
    "Q13": "Q13: How would you rate the gift recipient's bird knowledge?",
    "Q14": "Q14: Are you familiar with the concept of a pollinator garden?",
    "Q15": "Q15: Had you used a bird feeder before this purchase?",
}


SURVEY_OUTPUTS = {
    "Q1": "q1_pie_chart",
    "Q2": "q2_pie_chart",
    "Q3": "q3_pie_chart",
    "Q4": "q4_pie_chart",
    "Q5": "q5_pie_chart",
    "Q6": "q6_pie_chart",
    "Q7": "q7_pie_chart",
    "Q8": "q8_pie_chart",
    "Q9": "q9_pie_chart",
    "Q10": "q10_pie_chart",
    "Q11": "q11_pie_chart",
    "Q12": "q12_pie_chart",
    "Q13": "q13_pie_chart",
    "Q14": "q14_pie_chart",
    "Q15": "q15_pie_chart",
}


def survey_card(key: str):
    output_id = SURVEY_OUTPUTS[key]
    return ui.div(
        ui.div(
            ui.h3(SURVEY_TITLES[key]),
            ui.input_action_button(f"expand_{key.lower()}", "Wide", class_="survey-action"),
            class_="survey-card-head",
        ),
        ui.div(
            output_widget(output_id, width="360px", height="360px"),
            export_button(output_id),
            class_="survey-chart-frame",
        ),
        class_="survey-card",
    )


def survey_wide_card(key: str):
    output_id = SURVEY_OUTPUTS[key]
    return ui.div(
        ui.div(
            ui.h3(SURVEY_TITLES[key]),
            ui.input_action_button("back_all", "Back", class_="survey-action"),
            class_="survey-card-head",
        ),
        ui.div(
            output_widget(output_id, width="100%", height="520px"),
            export_button(output_id),
            class_="survey-chart-frame wide",
        ),
        class_="survey-wide-card",
    )


SKU_PRODUCTS = [
    {
        "name": "Blue Smart Bird Feeder",
        "sku": "BBG1002BAB BBG1002BAC",
        "image": "sku-blue.png",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_SKU 1 - Blue", "dtc_Bird Buddy"],
            "Amazon": ["amazon_SKU 1 - Blue"],
            "Rachio": ["rachio_SKU 1 - Blue"],
            "Weatherflow": ["weatherflow_SKU 1 - Blue"],
            "Walmart": ["walmart_SKU 1 - Blue"],
            "Costco": ["costco_SKU 1 - Blue"],
            "Huckberry": ["huckberry_SKU 1 - Blue"],
        },
    },
    {
        "name": "Yellow Smart Bird Feeder",
        "sku": "BYG1002BAB BYG1002BAC",
        "image": "sku-yellow.webp",
        "color": PALETTE["yellow"],
        "cols": {
            "DTC": ["dtc_SKU 2 - Yellow"],
            "Amazon": ["amazon_SKU 2 - Yellow"],
            "Rachio": ["rachio_SKU 2 - Yellow"],
            "Weatherflow": ["weatherflow_SKU 2 - Yellow"],
            "Walmart": ["walmart_SKU 2 - Yellow"],
            "Costco": ["costco_SKU 2 - Yellow"],
            "Huckberry": ["huckberry_SKU 2 - Yellow"],
        },
    },
    {
        "name": "Blue Smart Bird Feeder with Solar Roof",
        "sku": "BBG1003BAB BBG1003BAC",
        "image": "sku-blue-solar.png",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_SKU 3 - Blue w/ Solar", "dtc_Bird Buddy with Solar Roof"],
            "Amazon": ["amazon_SKU 3 - Blue w/ Solar"],
            "Rachio": ["rachio_SKU 3 - Blue w/ Solar"],
            "Weatherflow": ["weatherflow_SKU 3 - Blue w/ Solar"],
            "Walmart": ["walmart_SKU 3 - Blue w/ Solar"],
            "Costco": ["costco_SKU 3 - Blue w/ Solar"],
            "Huckberry": ["huckberry_SKU 3 - Blue w/ Solar"],
        },
    },
    {
        "name": "Yellow Smart Bird Feeder with Solar Roof",
        "sku": "BYG1003BAB BYG1003BAC",
        "image": "sku-yellow-solar.png",
        "color": PALETTE["yellow"],
        "cols": {
            "DTC": ["dtc_SKU 4 - Yellow w/ Solar"],
            "Amazon": ["amazon_SKU 4 - Yellow w/ Solar"],
            "Rachio": ["rachio_SKU 4 - Yellow w/ Solar"],
            "Weatherflow": ["weatherflow_SKU 4 - Yellow w/ Solar"],
            "Walmart": ["walmart_SKU 4 - Yellow w/ Solar"],
            "Costco": ["costco_SKU 4 - Yellow w/ Solar"],
            "Huckberry": ["huckberry_SKU 4 - Yellow w/ Solar"],
        },
    },
    {
        "name": "Smart Bird Feeder PRO",
        "sku": "BBG1002BAD BBG1002BAD-T",
        "image": "sku-blue.png",
        "badge": "PRO",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_SKU 1 - Blue PRO"],
            "Amazon": ["amazon_SKU 1 - Blue PRO"],
            "Huckberry": ["huckberry_SKU 1 - Blue PRO"],
            "Rachio": [],
            "Weatherflow": [],
            "Walmart": [],
        },
    },
    {
        "name": "Smart Bird Feeder PRO with Solar Roof",
        "sku": "BBG1003BAD BBG1003BAD-T",
        "image": "sku-blue-solar.png",
        "badge": "PRO",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_SKU 3 - Blue w/ Solar PRO"],
            "Amazon": ["amazon_SKU 3 - Blue w/ Solar PRO"],
            "Huckberry": ["huckberry_SKU 3 - Blue w/ Solar PRO"],
            "Rachio": [],
            "Weatherflow": [],
            "Walmart": [],
        },
    },
    {
        "name": "Smart Hummingbird Feeder",
        "sku": "BWH1023BAA",
        "image": "sku-hbf.webp",
        "cols": {"DTC": ["dtc_SKU 5 - HBF"], "Amazon": ["amazon_SKU 5 - HBF"], "Rachio": [], "Weatherflow": [], "Walmart": []},
    },
    {
        "name": "Smart Hummingbird Feeder with Solar Roof",
        "sku": "BWH1025BAA",
        "image": "sku-hbf-solar.webp",
        "cols": {"DTC": ["dtc_SKU 6 - HBF w/ Solar"], "Amazon": ["amazon_SKU 6 - HBF w/ Solar"], "Rachio": [], "Weatherflow": [], "Walmart": []},
    },
    {
        "name": "Smart Hummingbird Feeder PRO",
        "sku": "BWH1023BAB BWH1023BAB-T",
        "image": "sku-hbf.webp",
        "badge": "PRO",
        "cols": {
            "DTC": ["dtc_SKU 5 - HBF PRO"],
            "Amazon": ["amazon_SKU 5 - HBF PRO"],
            "Rachio": [],
            "Weatherflow": [],
            "Walmart": [],
            "Costco": [],
            "Huckberry": [],
        },
    },
    {
        "name": "Smart Hummingbird Feeder with Solar Roof PRO",
        "sku": "BWH1025BAB BWH1025BAB-T",
        "image": "sku-hbf-solar.webp",
        "badge": "PRO",
        "cols": {
            "DTC": ["dtc_SKU 6 - HBF w/ Solar PRO"],
            "Amazon": ["amazon_SKU 6 - HBF w/ Solar PRO"],
            "Rachio": [],
            "Weatherflow": [],
            "Walmart": [],
            "Costco": [],
            "Huckberry": [],
        },
    },
    {
        "name": "Bird Buddy Home",
        "sku": "BBG1003BAE",
        "image": "bird-buddy-home.webp",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_Bird Buddy 2"],
            "Amazon": [],
            "Rachio": [],
            "Weatherflow": [],
            "Walmart": [],
            "Costco": [],
            "Huckberry": [],
        },
    },
    {
        "name": "Smart Bird Feeder PRO Solar with PEX",
        "sku": "BBS4052RAA",
        "image": "sbf-pro-solar-pex-retail.webp",
        "badge": "Retail SKU",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_Smart Bird Feeder PRO Solar with PEX (Retail SKU)"],
            "Amazon": [],
            "Rachio": [],
            "Weatherflow": [],
            "Walmart": [],
            "Costco": [],
            "Huckberry": [],
        },
    },
]


ADDON_PRODUCTS = [
    {
        "name": "Wall Mount",
        "sku": "BNG1009BAA BNG1009BAA-T",
        "image": "wall mount.png",
        "note": "A Fence Mount is listed beside this one from July 2021 to June 2023, 3,981 units in all, 98% of them by June 2022 after which it dwindles to nothing. It is the same bracket sold under a second name, so those units are counted here.",
        "cols": {
            "DTC": ["dtc_Wall Mount", "dtc_Fence Mount"],
            "Amazon": ["amazon_Wall Mount"],
            "Walmart": ["walmart_Wall Mount"],
            "Costco": ["costco_Wall Mount"],
            "Huckberry": ["huckberry_Wall Mount"],
        },
    },
    {
        "name": "Suet Ball Holder",
        "sku": "BNG1011BAA BNG1011BAA-T",
        "image": "suet ball.png",
        "cols": {
            "DTC": ["dtc_Suet Ball Holder"],
            "Amazon": ["amazon_Suet Ball Holder"],
            "Walmart": ["walmart_Suet Ball Holder"],
            "Costco": ["costco_Suet Ball Holder"],
            "Huckberry": ["huckberry_Suet Ball Holder"],
        },
    },
    {
        "name": "3-in-1 Nutrition Set - Blue",
        "display_name": "Blue 3-in-1 Nutrition Set",
        "sku": "BCG1013BAA BCG1013BAA-T",
        "image": "nutrition blue.png",
        "color": PALETTE["blue"],
        "note": "Sold as Water Fountain from July 2022 to February 2023, before the 3-in-1 Nutrition Set name took over in March. Same product, so those 9,861 units are counted here.",
        "cols": {
            "DTC": ["dtc_3-in-1 Nutrition Set - Blue", "dtc_3-in-1 Nutrition Set", "dtc_Water Fountain"],
            "Amazon": ["amazon_3-in-1 Nutrition Set - Blue"],
            "Walmart": ["walmart_3-in-1 Nutrition Set - Blue"],
            "Costco": ["costco_3-in-1 Nutrition Set - Blue"],
            "Huckberry": ["huckberry_3-in-1 Nutrition Set - Blue"],
        },
    },
    {
        "name": "3-in-1 Nutrition Set - Yellow",
        "display_name": "Yellow 3-in-1 Nutrition Set",
        "sku": "BYG1013BAA BYG1013BAA-T",
        "image": "nutrition yellow.png",
        "color": PALETTE["yellow"],
        "cols": {
            "DTC": ["dtc_3-in-1 Nutrition Set - Yellow"],
            "Amazon": ["amazon_3-in-1 Nutrition Set - Yellow"],
            "Walmart": ["walmart_3-in-1 Nutrition Set - Yellow"],
            "Costco": ["costco_3-in-1 Nutrition Set - Yellow"],
            "Huckberry": ["huckberry_3-in-1 Nutrition Set - Yellow"],
        },
    },
    {
        "name": "Solar Roof Single - Blue",
        "display_name": "Blue Solar Roof Single",
        "sku": "BBG1005BAA BBG1005BAA-T",
        "image": "solar roof blue.png",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_Solar Roof Single - Blue", "dtc_Solar Roof Single"],
            "Amazon": ["amazon_Solar Roof Single - Blue"],
            "Walmart": ["walmart_Solar Roof Single - Blue"],
            "Costco": ["costco_Solar Roof Single - Blue"],
            "Huckberry": ["huckberry_Solar Roof Single - Blue"],
        },
    },
    {
        "name": "Solar Roof Single - Yellow",
        "display_name": "Yellow Solar Roof Single",
        "sku": "BYG1005BAA BYG1005BAA-T",
        "image": "solar roof yellow.png",
        "color": PALETTE["yellow"],
        "cols": {
            "DTC": ["dtc_Solar Roof Single - Yellow"],
            "Amazon": ["amazon_Solar Roof Single - Yellow"],
            "Walmart": ["walmart_Solar Roof Single - Yellow"],
            "Costco": ["costco_Solar Roof Single - Yellow"],
            "Huckberry": ["huckberry_Solar Roof Single - Yellow"],
        },
    },
    {
        "name": "Perch Extender - Blue",
        "display_name": "Blue Perch Extender",
        "sku": "BBG1021BAA BBG1021BAA-T",
        "image": "perch blue.png",
        "color": PALETTE["blue"],
        "cols": {
            "DTC": ["dtc_Perch Extender - Blue"],
            "Amazon": ["amazon_Perch Extender - Blue"],
            "Walmart": ["walmart_Perch Extender - Blue"],
            "Costco": ["costco_Perch Extender - Blue"],
            "Huckberry": ["huckberry_Perch Extender - Blue"],
        },
    },
    {
        "name": "Perch Extender - Yellow",
        "display_name": "Yellow Perch Extender",
        "sku": "BYG1021BAA BYG1021BAA-T",
        "image": "perch yellow.png",
        "color": PALETTE["yellow"],
        "cols": {
            "DTC": ["dtc_Perch Extender - Yellow"],
            "Amazon": ["amazon_Perch Extender - Yellow"],
            "Walmart": ["walmart_Perch Extender - Yellow"],
            "Costco": ["costco_Perch Extender - Yellow"],
            "Huckberry": ["huckberry_Perch Extender - Yellow"],
        },
    },
    {
        "name": "Solar Roof (HBF)",
        "display_name": "HBF Solar Roof Single",
        "sku": "BWH1026BAA BWH1026BAA-T",
        "image": "hbf roof.png",
        "color": PALETTE["red"],
        "cols": {"DTC": ["dtc_Solar Roof (HBF)"], "Amazon": [], "Walmart": []},
    },
    {
        "name": "Housing - only (HBF)",
        "display_name": "HBF Housing",
        "sku": "BWH1022BAA BWH1022BAA-T",
        "image": "hbf housing.png",
        "color": PALETTE["red"],
        "cols": {"DTC": ["dtc_Housing - only (HBF)"], "Amazon": [], "Walmart": []},
    },
    {
        "name": "Nature Station Essential",
        "sku": "BBS4055AAA BWS1004BAC-T",
        "image": "nature-station-essential.webp",
        "cols": {"DTC": ["dtc_Nature Station"], "Amazon": [], "Walmart": []},
    },
    {
        "name": "Nature Station Bloom",
        "sku": "BKP1037BAA BKP1037BAA-T",
        "image": "nature-station-bloom.webp",
        "cols": {"DTC": ["dtc_Nature Station Bloom"], "Amazon": [], "Walmart": []},
    },
    {
        "name": "Pollinator Pot",
        "sku": "BKP1038BAA BKP1038BAA-T",
        "image": "pollinator-pot.webp",
        "cols": {"DTC": ["dtc_Pollinator Pot"], "Amazon": [], "Walmart": []},
    },
    {
        "name": "Nature Cam PRO",
        "sku": "BWS1004BAC BWS1004BAC-T",
        "image": "nature-cam-icon.png",
        "badge": "PRO",
        "cols": {"DTC": ["dtc_Nature Cam PRO"], "Amazon": ["amazon_Nature Cam PRO"], "Walmart": []},
    },
]


PNL_UNIT_CHANNELS = ["DTC", "Amazon", "Rachio", "Weatherflow", "Target", "BestBuy", "Chewy", "Walmart", "Walmart Retail", "Costco", "Ace Hardware", "Huckberry"]
PNL_ADDON_CHANNELS = ["DTC", "Amazon", "Chewy", "Walmart", "Costco", "Huckberry"]
PNL_DIGITAL_CHANNELS = ["Rachio", "Weatherflow", "Huckberry"]
PNL_RETAIL_CHANNELS = ["Target", "BestBuy", "Chewy", "Walmart", "Walmart Retail", "Costco", "Ace Hardware"]
PNL_ROLLUP_CHANNELS = ["DTC", "Amazon", "Digital", "Retail"]
PNL_VIS_CHANNEL_CHOICES = {
    "All": "All",
    "DTC": "DTC",
    "Amazon": "Amazon",
    "Digital": "Digital Marketplaces",
    "Retail": "Retail",
    "Rachio": "Rachio",
    "Weatherflow": "Weatherflow",
    "Huckberry": "Huckberry",
    "Target": "Target",
    "BestBuy": "BestBuy",
    "Chewy": "Chewy",
    "Walmart": "Walmart",
    "Walmart Retail": "Walmart Retail",
    "Costco": "Costco",
    "Ace Hardware": "Ace Hardware",
}
# Revenue and spend columns behind the Visualization tab's channel picker, in the same
# order as the P&L dropdown. Seven of these channels carry no spend of their own, so their
# entry leaves the spend column out and the chart draws revenue on its own rather than a
# flat zero line that would read as a bug.
REVENUE_SPEND_SOURCES = {
    "Total": ("Total_Revenue", "Total_Spend"),
    "DTC": ("DTC_Revenue", "Total_DTC_Spend"),
    "Amazon": ("Amazon_Revenue", "Amazon_Spend"),
    "App": ("App_Revenue", "Total_App_Spend"),
    "IndieGoGo": ("IndieGoGo_Revenue", "IndieGoGo_Spend"),
    "Digital": ("Digital_Marketplaces_Revenue", None),
    "Retail": ("B2B_Revenue", "Retail_Spend"),
    "Rachio": ("Rachio_Revenue", None),
    "Weatherflow": ("Weatherflow_Revenue", None),
    "Huckberry": ("Huckberry_Revenue", None),
    "Target": ("Target_Revenue", "Target_Spend"),
    "BestBuy": ("BestBuy_Revenue", "BestBuy_Spend"),
    "Chewy": ("Chewy_Revenue", "Chewy_Spend"),
    "Walmart": ("Walmart_Revenue", "Walmart_Spend"),
    "Walmart Retail": ("Walmart_Retail_Revenue", None),
    "Costco": ("Costco_Revenue", None),
    "Ace Hardware": ("Ace_Hardware_Revenue", None),
}
REVENUE_SPEND_CHOICES = {
    key: "Digital Marketplaces" if key == "Digital" else key for key in REVENUE_SPEND_SOURCES
}

# The composition charts, in stacking order, one entry per band with its colour. Kept
# here because each chart and its CSV export both read them and had drifted apart as
# copies. Retail and app carry the same colour in both charts, and both are gated by
# the Include Retail / Include App toggles: retail and app sit outside Total Revenue,
# so the revenue chart ties to the headline only while they are off.
REVENUE_SHARE_COLS = {
    "DTC_Revenue": PALETTE["green"],
    "Amazon_Revenue": PALETTE["blue"],
    "IndieGoGo_Revenue": PALETTE["dark"],
    "Digital_Marketplaces_Revenue": PALETTE["orange"],
    "Retail_Revenue": PALETTE["purple"],
    "App_Revenue": PALETTE["gray"],
}
TOTAL_SPEND_COLS = {
    "Total_DTC_Spend": PALETTE["red"],
    "Amazon_Spend": PALETTE["orange"],
    "Retail_Spend": PALETTE["purple"],
    "IndieGoGo_Spend": PALETTE["dark"],
    "Total_App_Spend": PALETTE["gray"],
    "Fees": PALETTE["blue"],
}
DTC_SPEND_COLS = {
    "Meta_Spend": PALETTE["red"],
    "Google_Spend": PALETTE["orange"],
    "Bing_Spend": PALETTE["purple"],
    "TikTok_Spend": PALETTE["dark"],
    "Snapchat_Spend": PALETTE["yellow"],
    "Nextdoor_Spend": PALETTE["blue"],
    "Affiliate_Fees": PALETTE["green"],
}
RETAIL_BAND_COLS = {"Retail_Revenue", "Retail_Spend"}
APP_BAND_COLS = {"App_Revenue", "Total_App_Spend"}


def retail_band_label(df: pd.DataFrame) -> str:
    """Name the chains behind the retail band, narrowed to the ones selling in the window.

    Retail is a rollup of seven accounts, which is too long to read in a legend and mostly
    noise on a short range where only two or three of them are active. Huckberry is not
    among them: it sells through Digital Marketplaces.
    """
    active = [
        channel
        for channel in PNL_RETAIL_CHANNELS
        if f"{channel.replace(' ', '_')}_Revenue" in df.columns
        and numeric_col(df, f"{channel.replace(' ', '_')}_Revenue").sum() > 0
    ]
    return f"Retail ({', '.join(active or PNL_RETAIL_CHANNELS)})"


def composition_bands(sources: dict, include_retail: bool, include_app: bool) -> dict:
    return {
        col: color
        for col, color in sources.items()
        if (include_retail or col not in RETAIL_BAND_COLS)
        and (include_app or col not in APP_BAND_COLS)
    }

PNL_ADDON_VIS_CHANNEL_CHOICES = {
    "All": "All",
    "DTC": "DTC",
    "Amazon": "Amazon",
    "Digital": "Digital Marketplaces",
    "Retail": "Retail",
    "Chewy": "Chewy",
    "Walmart": "Walmart",
    "Costco": "Costco",
    "Huckberry": "Huckberry",
}
PNL_CHANNEL_PRESETS = {
    "all": ("All channels", PNL_UNIT_CHANNELS),
    "retail": ("Retail only", PNL_RETAIL_CHANNELS),
    "dtc_amazon": ("DTC & Amazon", ["DTC", "Amazon"]),
    "digital": ("Digital only", PNL_DIGITAL_CHANNELS),
    "custom": ("Custom", []),
}
ADDON_SUMMARY_PRODUCTS = [
    {
        "name": "Wall Mount",
        "cols": {
            "DTC": ["dtc_Wall Mount", "dtc_Fence Mount"],
            "Amazon": ["amazon_Wall Mount"],
            "Walmart": ["walmart_Wall Mount"],
            "Costco": ["costco_Wall Mount"],
            "Huckberry": ["huckberry_Wall Mount"],
        },
    },
    {
        "name": "Suet Ball Holder",
        "cols": {
            "DTC": ["dtc_Suet Ball Holder"],
            "Amazon": ["amazon_Suet Ball Holder"],
            "Walmart": ["walmart_Suet Ball Holder"],
            "Costco": ["costco_Suet Ball Holder"],
            "Huckberry": ["huckberry_Suet Ball Holder"],
        },
    },
    {
        "name": "3-in-1 Nutrition Set",
        "cols": {
            "DTC": ["dtc_3-in-1 Nutrition Set - Blue", "dtc_3-in-1 Nutrition Set - Yellow", "dtc_3-in-1 Nutrition Set", "dtc_Water Fountain"],
            "Amazon": ["amazon_3-in-1 Nutrition Set - Blue", "amazon_3-in-1 Nutrition Set - Yellow"],
            "Walmart": ["walmart_3-in-1 Nutrition Set - Blue", "walmart_3-in-1 Nutrition Set - Yellow"],
            "Costco": ["costco_3-in-1 Nutrition Set - Blue", "costco_3-in-1 Nutrition Set - Yellow"],
            "Huckberry": ["huckberry_3-in-1 Nutrition Set - Blue", "huckberry_3-in-1 Nutrition Set - Yellow"],
        },
    },
    {
        "name": "Solar Roof Single",
        "cols": {
            "DTC": ["dtc_Solar Roof Single - Blue", "dtc_Solar Roof Single - Yellow", "dtc_Solar Roof Single"],
            "Amazon": ["amazon_Solar Roof Single - Blue", "amazon_Solar Roof Single - Yellow"],
            "Walmart": ["walmart_Solar Roof Single - Blue", "walmart_Solar Roof Single - Yellow"],
            "Costco": ["costco_Solar Roof Single - Blue", "costco_Solar Roof Single - Yellow"],
            "Huckberry": ["huckberry_Solar Roof Single - Blue", "huckberry_Solar Roof Single - Yellow"],
        },
    },
    {
        "name": "Perch Extender",
        "cols": {
            "DTC": ["dtc_Perch Extender - Blue", "dtc_Perch Extender - Yellow"],
            "Amazon": ["amazon_Perch Extender - Blue", "amazon_Perch Extender - Yellow"],
            "Walmart": ["walmart_Perch Extender - Blue", "walmart_Perch Extender - Yellow"],
            "Costco": ["costco_Perch Extender - Blue", "costco_Perch Extender - Yellow"],
            "Huckberry": ["huckberry_Perch Extender - Blue", "huckberry_Perch Extender - Yellow"],
        },
    },
    {"name": "Solar Roof (HBF)", "cols": {"DTC": ["dtc_Solar Roof (HBF)"], "Amazon": []}},
    {"name": "Housing - only (HBF)", "cols": {"DTC": ["dtc_Housing - only (HBF)"], "Amazon": []}},
    {"name": "Nature Station Essential", "cols": {"DTC": ["dtc_Nature Station"], "Amazon": []}},
    {"name": "Nature Station Bloom", "cols": {"DTC": ["dtc_Nature Station Bloom"], "Amazon": []}},
    {"name": "Pollinator Pot", "cols": {"DTC": ["dtc_Pollinator Pot"], "Amazon": []}},
    {"name": "Nature Cam PRO", "cols": {"DTC": ["dtc_Nature Cam PRO"], "Amazon": ["amazon_Nature Cam PRO"]}},
]


def product_cols_for_channel(product: dict, channel: str) -> List[str]:
    if channel == "All":
        return [col for cols in product["cols"].values() for col in cols]
    if channel == "Digital":
        return [col for name in PNL_DIGITAL_CHANNELS for col in product["cols"].get(name, [])]
    if channel == "Retail":
        return [col for name in PNL_RETAIL_CHANNELS for col in product["cols"].get(name, [])]
    return list(product["cols"].get(channel, []))


SEED_PRODUCTS = [
    ("Seasonal Curation - 8lb", "BNE1035PUA", "seasonal 8.png", ["dtc_Seasonal Curation - 8lb"]),
    ("Seasonal Curation - 20lb", "BNT1035PUA", "seasonal 8.png", ["dtc_Seasonal Curation - 20lb"]),
    ("Buddy Bites - 8lb", "BNE1033PUA", "buddy 8.png", ["dtc_Buddy Bites - 8lb"]),
    ("Buddy Bites - 20lb", "BNT1033PUA", "buddy20.png", ["dtc_Buddy Bites - 20lb"]),
    ("Snack n' Soar - 8lb", "BNE1035PUA", "snack.png", ["dtc_Snack n' Soar - 8lb"]),
    ("Snack n' Soar - 20lb", "BNT1035PUA", "snack20.png", ["dtc_Snack n' Soar - 20lb"]),
    ("Avian Choice - 8lb", "BNE1034PUA", "avian.png", ["dtc_Avian Choice - 8lb"]),
    ("Avian Choice - 20lb", "BNT1034PUA", "avian20.png", ["dtc_Avian Choice - 20lb"]),
]


GIFT_BAG_PRODUCTS = [
    {
        "name": "Gift Bag",
        "sku": "BNC6020CUA",
        "image": "gift-wrap.png",
        "cols": {"DTC": ["DTC_Gift_Bag_Units"]},
    },
]


APP_SUB_PRODUCTS = [
    {
        "name": "1 Year Birdbuddy Premium Subscription",
        "sku": "BN24PROCAA BN24FAMCAA",
        "image": "premium.png",
        "cols": {
            "DTC": ["DTC_Subscription_Units"],
            "Apple": ["apple_yearly_sub"],
            "Google": ["google_yearly_sub"],
        },
    },
    {
        "name": "Monthly Birdbuddy Premium Subscription",
        "sku": "",
        "image": "premium2.png",
        "cols": {"DTC": [], "Apple": ["apple_monthly_sub"], "Google": ["google_monthly_sub"]},
    },
]


# The Unit Count chart's two grouping levels and the Seed chart's flavour grouping, held
# here so the SKU-coded export can map a grouped column back to the products behind it.
# "SBF" and "HBF" mean different sets at each level, so these stay two dicts rather than
# one merged lookup.
SKU_FAMILY_BUCKETS = {
    "SBF": [
        "Blue Smart Bird Feeder",
        "Yellow Smart Bird Feeder",
        "Blue Smart Bird Feeder with Solar Roof",
        "Yellow Smart Bird Feeder with Solar Roof",
        "Smart Bird Feeder PRO",
        "Smart Bird Feeder PRO with Solar Roof",
        "Smart Bird Feeder PRO Solar with PEX",
        "Bird Buddy Home",
    ],
    "HBF": [
        "Smart Hummingbird Feeder",
        "Smart Hummingbird Feeder with Solar Roof",
        "Smart Hummingbird Feeder PRO",
        "Smart Hummingbird Feeder with Solar Roof PRO",
    ],
}
SKU_TYPE_BUCKETS = {
    "SBF": ["Blue Smart Bird Feeder", "Yellow Smart Bird Feeder"],
    "SBF Solar": ["Blue Smart Bird Feeder with Solar Roof", "Yellow Smart Bird Feeder with Solar Roof"],
    "SBF PRO": ["Smart Bird Feeder PRO"],
    "SBF PRO Solar": ["Smart Bird Feeder PRO with Solar Roof"],
    "SBF PRO Solar (Retail)": ["Smart Bird Feeder PRO Solar with PEX"],
    "HBF": ["Smart Hummingbird Feeder"],
    "HBF Solar": ["Smart Hummingbird Feeder with Solar Roof"],
    "HBF PRO": ["Smart Hummingbird Feeder PRO"],
    "HBF PRO Solar": ["Smart Hummingbird Feeder with Solar Roof PRO"],
    "Bird Buddy Home": ["Bird Buddy Home"],
}
SEED_TYPE_BUCKETS = {
    "Seasonal Curation": ["dtc_Seasonal Curation - 8lb", "dtc_Seasonal Curation - 20lb"],
    "Buddy Bites": ["dtc_Buddy Bites - 8lb", "dtc_Buddy Bites - 20lb"],
    "Snack n' Soar": ["dtc_Snack n' Soar - 8lb", "dtc_Snack n' Soar - 20lb"],
    "Avian Choice": ["dtc_Avian Choice - 8lb", "dtc_Avian Choice - 20lb"],
}


def sku_codes(sku: object) -> List[str]:
    """A product's codes, since several products carry more than one, space separated."""
    return str(sku or "").split()


def join_codes(groups: Iterable[Iterable[str]]) -> str:
    seen: List[str] = []
    for group in groups:
        for code in group:
            if code not in seen:
                seen.append(code)
    return " ".join(seen)


def product_sku_map(products: Sequence[dict]) -> Dict[str, str]:
    return {product["name"]: join_codes([sku_codes(product.get("sku"))]) for product in products}


def bucket_sku_map(buckets: Dict[str, Sequence[str]], products: Sequence[dict]) -> Dict[str, str]:
    by_name = {product["name"]: product for product in products}
    return {
        label: join_codes(sku_codes(by_name.get(name, {}).get("sku")) for name in names)
        for label, names in buckets.items()
    }


def addon_sku_map(by_colour: bool) -> Dict[str, str]:
    """Add-on labels to codes, for either the per-colour tiles or the merged summary ones.

    The summary tiles carry no code of their own, so theirs come from whichever colour
    variants feed the same data columns.
    """
    if by_colour:
        return product_sku_map(ADDON_PRODUCTS)
    variants: Dict[str, List[dict]] = {}
    for product in ADDON_PRODUCTS:
        for cols in product["cols"].values():
            for col in cols:
                variants.setdefault(col, []).append(product)
    return {
        summary["name"]: join_codes(
            sku_codes(variant.get("sku"))
            for cols in summary["cols"].values()
            for col in cols
            for variant in variants.get(col, [])
        )
        for summary in ADDON_SUMMARY_PRODUCTS
    }


def seed_sku_map(by_weight: bool) -> Dict[str, str]:
    if by_weight:
        return {name: join_codes([sku_codes(sku)]) for name, sku, _image, _cols in SEED_PRODUCTS}
    by_col = {col: sku for name, sku, _image, cols in SEED_PRODUCTS for col in cols}
    return {
        label: join_codes(sku_codes(by_col.get(col)) for col in cols)
        for label, cols in SEED_TYPE_BUCKETS.items()
    }


def rename_to_sku(df: pd.DataFrame, mapping: Dict[str, str]) -> pd.DataFrame:
    """Swap product labels for their codes, keeping the label where none is configured.

    A label whose codes duplicate one already used keeps its name alongside them, so a
    repeated code in the product config cannot turn into two identical CSV headers.
    """
    used = {"Date"}
    renamed: Dict[str, str] = {}
    for col in df.columns:
        if col == "Date":
            continue
        code = mapping.get(col, "").strip()
        header = code or col
        if header in used:
            header = f"{code} ({col})"
        used.add(header)
        renamed[col] = header
    return df.rename(columns=renamed)


def cols_for_product(product_name: str, channels: Sequence[str] = PNL_UNIT_CHANNELS) -> Dict[str, List[str]]:
    prefixes = {
        "DTC": "dtc",
        "Amazon": "amazon",
        "Rachio": "rachio",
        "Weatherflow": "weatherflow",
        "Target": "target",
        "BestBuy": "bestbuy",
        "Chewy": "chewy",
        "Walmart": "walmart",
        "Walmart Retail": "walmart_retail",
        "Costco": "costco",
        "Ace Hardware": "ace_hardware",
        "Huckberry": "huckberry",
    }
    return {channel: [f"{prefixes[channel]}_{product_name}"] if channel in prefixes else [] for channel in channels}


def append_cols(product_name: str, channel: str, cols: Sequence[str], products: Sequence[dict] = SKU_PRODUCTS) -> None:
    for product in products:
        if product["name"] == product_name:
            product["cols"].setdefault(channel, [])
            for col in cols:
                if col not in product["cols"][channel]:
                    product["cols"][channel].append(col)
            return


SKU_PRODUCTS.extend(
    [
        {
            "name": "Smart Hummingbird Feeder PRO Solar (Retail SKU)",
            "sku": "BWH1025RAA",
            "image": "sku-hbf-solar.webp",
            "badge": "Retail SKU",
            "cols": cols_for_product("Smart Hummingbird Feeder PRO Solar (Retail SKU)"),
        },
        # The Nook line, from October 2026. The plain Nook is the SKU Target sells; the
        # Learning Bundle is the DTC pack with the Bird Anatomy book and keeps its own
        # row rather than folding into the Nook.
        {
            "name": "Bird Buddy Nook",
            "sku": "BBG1002BAE",
            "image": "nook.webp",
            "badge": "BB2",
            "cols": cols_for_product("Bird Buddy Nook"),
        },
        {
            "name": "Bird Buddy Nook Solar",
            "sku": "BBG1003BAF",
            "image": "nook-solar.webp",
            "badge": "BB2",
            "cols": cols_for_product("Bird Buddy Nook Solar"),
        },
        {
            "name": "Bird Buddy Nook (The Learning Bundle)",
            "sku": "BBG1002BAE-1",
            "image": "nook-learning-bundle.webp",
            "badge": "BB2",
            "cols": cols_for_product("Bird Buddy Nook (The Learning Bundle)"),
        },
    ]
)

for channel in ["Walmart", "Costco", "Huckberry"]:
    append_cols("Smart Bird Feeder PRO Solar with PEX", channel, [f"{channel.lower()}_Smart Bird Feeder PRO Solar with PEX (Retail SKU)"])
    append_cols("Smart Hummingbird Feeder PRO", channel, [f"{channel.lower()}_SKU 5 - HBF PRO"])
    append_cols("Smart Hummingbird Feeder with Solar Roof PRO", channel, [f"{channel.lower()}_SKU 6 - HBF w/ Solar PRO"])
for channel in ["DTC", "Amazon"]:
    prefix = "dtc" if channel == "DTC" else "amazon"
    append_cols("Smart Hummingbird Feeder PRO Solar (Retail SKU)", channel, [f"{prefix}_Smart Hummingbird Feeder PRO Solar (Retail SKU)"])
append_cols("Bird Buddy Home", "Amazon", ["amazon_Bird Buddy 2"])
# Target began selling it on 15 Oct 2026; the retail sell-through sync writes this column.
append_cols("Bird Buddy Home", "Target", ["target_Bird Buddy 2"])
for channel in ["Walmart", "Costco", "Huckberry"]:
    append_cols("Bird Buddy Home", channel, [f"{channel.lower()}_Bird Buddy 2"])

for product_name, product_key in [
    ("Blue Smart Bird Feeder", "SKU 1 - Blue"),
    ("Yellow Smart Bird Feeder", "SKU 2 - Yellow"),
    ("Blue Smart Bird Feeder with Solar Roof", "SKU 3 - Blue w/ Solar"),
    ("Yellow Smart Bird Feeder with Solar Roof", "SKU 4 - Yellow w/ Solar"),
    ("Smart Bird Feeder PRO", "SKU 1 - Blue PRO"),
    ("Smart Bird Feeder PRO with Solar Roof", "SKU 3 - Blue w/ Solar PRO"),
    ("Smart Bird Feeder PRO Solar with PEX", "Smart Bird Feeder PRO Solar with PEX (Retail SKU)"),
    ("Smart Hummingbird Feeder with Solar Roof", "SKU 6 - HBF w/ Solar"),
    ("Smart Hummingbird Feeder PRO Solar (Retail SKU)", "Smart Hummingbird Feeder PRO Solar (Retail SKU)"),
]:
    for channel, prefix in [("Target", "target"), ("BestBuy", "bestbuy"), ("Chewy", "chewy"), ("Walmart", "walmart"), ("Walmart Retail", "walmart_retail"), ("Ace Hardware", "ace_hardware")]:
        append_cols(product_name, channel, [f"{prefix}_{product_key}"])

ADDON_PRODUCTS.extend(
    [
        {
            "name": "Nook Perch Extender - White",
            "sku": "BBG1021WHT",
            "image": "nook-perch-extender.webp",
            "badge": "BB2",
            "cols": cols_for_product("Nook Perch Extender - White", PNL_ADDON_CHANNELS),
        },
        {
            "name": "Nook Solar Roof",
            "image": "nook-solar.webp",
            "badge": "BB2",
            "cols": cols_for_product("Nook Solar Roof", PNL_ADDON_CHANNELS),
        },
    ]
)

for addon_name, product_key in [
    ("3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Blue"),
    ("Perch Extender - Blue", "Perch Extender - Blue"),
]:
    append_cols(addon_name, "Chewy", [f"chewy_{product_key}"], products=ADDON_PRODUCTS)

for addon in ADDON_PRODUCTS:
    source_name = addon["name"]
    if source_name in {"Solar Roof (HBF)", "Housing - only (HBF)", "Nature Station Essential", "Nature Station Bloom", "Pollinator Pot"}:
        source_name = "Nature Station" if source_name == "Nature Station Essential" else source_name
        for channel in ["Walmart", "Costco", "Huckberry"]:
            addon["cols"].setdefault(channel, [])
            col = f"{channel.lower()}_{source_name}"
            if col not in addon["cols"][channel]:
                addon["cols"][channel].append(col)


# The workbook's own hardware-unit line stopped picking up new SKUs in February 2025,
# so it is rebuilt here from the per-SKU columns the P&L already reports. This runs
# once SKU_PRODUCTS is final, and feeds every per-unit metric downstream (wSPU, aSPU,
# Web RPU, Amazon RPU) as well as the summary cards.
def _hardware_unit_specs() -> Dict[str, List[str]]:
    specs: Dict[str, List[str]] = {}
    for channel, prefix, targets in (
        ("DTC", "dtc", ("DTC_Hardware_Units", "DTC_Total_Hardware_Units")),
        ("Amazon", "amazon", ("Amazon_Hardware_Units",)),
    ):
        base = [col for product in SKU_PRODUCTS for col in product_cols_for_channel(product, channel)]
        for target in targets:
            specs[target] = base
        scope = "DTC" if channel == "DTC" else "Amazon"
        for region in ("us", "eu"):
            specs[f"{scope}_{region.upper()}_Hardware_Units"] = [
                col.replace(f"{prefix}_", f"{prefix}_{region}_", 1) for col in base
            ]
    return specs


revenue_data = rebuild_unit_totals(revenue_data, _hardware_unit_specs())


def pnl_seed_items() -> List[dict]:
    seed_items = [
        {
            "name": name,
            "display_name": name.replace(" - 8lb", "").replace(" - 20lb", ""),
            "sku": sku,
            "image": image,
            "cols": {"DTC": cols},
        }
        for name, sku, image, cols in SEED_PRODUCTS
    ]
    for product, (name, _, _, _) in zip(seed_items, SEED_PRODUCTS):
        if name.endswith(" - 8lb"):
            product["display_name"] = "8lb " + name.removesuffix(" - 8lb")
            product["color"] = "#2b243f"
        elif name.endswith(" - 20lb"):
            product["display_name"] = "20lb " + name.removesuffix(" - 20lb")
            product["color"] = "#806ac6"
    return seed_items


def merged_products(
    groups: Sequence[dict],
    source_products: Sequence[dict],
    channels: Sequence[str],
) -> List[dict]:
    by_name = {product["name"]: product for product in source_products}
    out = []
    for group in groups:
        cols = {channel: [] for channel in channels}
        sku_parts = []
        for source_name in group["sources"]:
            source = by_name.get(source_name)
            if not source:
                continue
            for channel in channels:
                cols[channel].extend(source["cols"].get(channel, []))
            sku = source.get("sku", "").strip()
            if sku:
                sku_parts.extend(sku.split())
            else:
                fallback_skus = sorted(
                    {
                        re.sub(r"^(dtc|amazon|rachio|weatherflow|walmart|costco|huckberry)_", "", col)
                        for source_cols in source["cols"].values()
                        for col in source_cols
                    }
                )
                sku_parts.extend(fallback_skus)
        sku_line = " ".join(dict.fromkeys(part for part in sku_parts if part))
        out.append(
            {
                "name": group["name"],
                "display_name": group.get("display_name", group["name"]),
                "sku": group.get("sku", sku_line),
                "image": group["image"],
                "badge": group.get("badge"),
                "color": group.get("color"),
                "merged": True,
                "cols": cols,
            }
        )
    return out


def merged_seed_items() -> List[dict]:
    groups = [
        ("Seasonal Curation", "BNE1035PUA BNT1035PUA", "seasonal 8.png", ["Seasonal Curation - 8lb", "Seasonal Curation - 20lb"]),
        ("Buddy Bites", "BNE1033PUA BNT1033PUA", "buddy 8.png", ["Buddy Bites - 8lb", "Buddy Bites - 20lb"]),
        ("Snack n' Soar", "BNE1035PUA BNT1035PUA", "snack.png", ["Snack n' Soar - 8lb", "Snack n' Soar - 20lb"]),
        ("Avian Choice", "BNE1034PUA BNT1034PUA", "avian.png", ["Avian Choice - 8lb", "Avian Choice - 20lb"]),
    ]
    return [
        {
            "name": name,
            "sku": sku,
            "image": image,
            "merged": True,
            "cols": {"DTC": [col for seed_name, _, _, cols in SEED_PRODUCTS if seed_name in source_names for col in cols]},
        }
        for name, sku, image, source_names in groups
    ]


def merged_pnl_product_sets() -> tuple[List[dict], List[dict], List[dict]]:
    merged_skus = merged_products(
        [
            {
                "name": "Birdbuddy",
                "display_name": "Birdbuddy",
                "sku": "BBG1002BAB BBG1002BAC BYG1002BAB BYG1002BAC BBG1002BAD BBG1002BAD-T",
                "image": "sku-blue.png",
                "sources": ["Blue Smart Bird Feeder", "Yellow Smart Bird Feeder", "Smart Bird Feeder PRO"],
            },
            {
                "name": "Birdbuddy Solar",
                "display_name": "Birdbuddy Solar",
                "sku": "BBG1003BAB BBG1003BAC BYG1003BAB BYG1003BAC BBG1003BAD BBG1003BAD-T BBS4052RAA",
                "image": "sku-blue-solar.png",
                "sources": [
                    "Blue Smart Bird Feeder with Solar Roof",
                    "Yellow Smart Bird Feeder with Solar Roof",
                    "Smart Bird Feeder PRO with Solar Roof",
                    "Smart Bird Feeder PRO Solar with PEX",
                ],
            },
            {
                "name": "Smart Hummingbird Feeder",
                "image": "sku-hbf.webp",
                "sources": ["Smart Hummingbird Feeder", "Smart Hummingbird Feeder PRO"],
            },
            {
                "name": "Smart Hummingbird Feeder Solar",
                "image": "sku-hbf-solar.webp",
                "sku": "BWH1025BAA BWH1025BAB BWH1025BAB-T BWH1025RAA",
                "sources": [
                    "Smart Hummingbird Feeder with Solar Roof",
                    "Smart Hummingbird Feeder with Solar Roof PRO",
                    "Smart Hummingbird Feeder PRO Solar (Retail SKU)",
                ],
            },
            {
                "name": "Bird Buddy Home",
                "image": "bird-buddy-home.webp",
                "sources": ["Bird Buddy Home"],
            },
        ],
        SKU_PRODUCTS,
        PNL_UNIT_CHANNELS,
    )
    merged_addons = merged_products(
        [
            {"name": "Wall Mount", "sku": "BNG1009BAA BNG1009BAA-T", "image": "wall mount.png", "sources": ["Wall Mount"]},
            {"name": "Suet Ball Holder", "sku": "BNG1011BAA BNG1011BAA-T", "image": "suet ball.png", "sources": ["Suet Ball Holder"]},
            {
                "name": "3-in-1 Nutrition Set",
                "sku": "BCG1013BAA BCG1013BAA-T BYG1013BAA BYG1013BAA-T",
                "image": "nutrition blue.png",
                "sources": ["3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow"],
            },
            {
                "name": "Solar Roof Single",
                "sku": "BBG1005BAA BBG1005BAA-T BYG1005BAA BYG1005BAA-T",
                "image": "solar roof blue.png",
                "sources": ["Solar Roof Single - Blue", "Solar Roof Single - Yellow"],
            },
            {
                "name": "Perch Extender",
                "sku": "BBG1021BAA BBG1021BAA-T BYG1021BAA BYG1021BAA-T",
                "image": "perch blue.png",
                "sources": ["Perch Extender - Blue", "Perch Extender - Yellow"],
            },
            {
                "name": "HBF Solar Roof Single",
                "sku": "BWH1026BAA BWH1026BAA-T",
                "image": "hbf roof.png",
                "sources": ["Solar Roof (HBF)"],
            },
            {
                "name": "HBF Housing",
                "sku": "BWH1022BAA BWH1022BAA-T",
                "image": "hbf housing.png",
                "sources": ["Housing - only (HBF)"],
            },
            {
                "name": "Nature Station",
                "image": "nature-station-essential.webp",
                "sources": ["Nature Station Essential", "Nature Station Bloom"],
            },
            {"name": "Pollinator Pot", "image": "pollinator-pot.webp", "sources": ["Pollinator Pot"]},
            {"name": "Nature Cam PRO", "sku": "BWS1004BAC BWS1004BAC-T", "image": "nature-cam-icon.png", "badge": "PRO", "sources": ["Nature Cam PRO"]},
        ],
        ADDON_PRODUCTS,
        PNL_ADDON_CHANNELS,
    )
    return merged_skus, merged_addons, merged_seed_items()


def family_pnl_product_sets() -> tuple[List[dict], List[dict], List[dict]]:
    """The SBF/HBF grouping: one line per feeder family, retail bundles kept apart.

    Unlike the default merge, which folds the retail bundle into the solar line it is
    built on, each bundle is its own row here because it carries an accessory the plain
    solar feeder does not. Colour and PRO variants collapse into the family line, and
    Nature Cam PRO is reported as hardware rather than as an add-on.

    Pole System is the two Nature Stations and Planter Base is the Pollinator Pot;
    both are named for the part the customer buys rather than the SKU it ships under.

    The Nook rows joined in October 2026 and keep the same shape as the rest: one line
    per thing sold, with the Learning Bundle apart from the bare Nook.
    """
    sources = [*SKU_PRODUCTS, *ADDON_PRODUCTS]
    family_skus = merged_products(
        [
            {
                "name": "SBF",
                "image": "sku-blue.png",
                "sources": ["Blue Smart Bird Feeder", "Yellow Smart Bird Feeder", "Smart Bird Feeder PRO"],
            },
            {
                "name": "SBF w Solar Roof",
                "image": "sku-blue-solar.png",
                "sources": [
                    "Blue Smart Bird Feeder with Solar Roof",
                    "Yellow Smart Bird Feeder with Solar Roof",
                    "Smart Bird Feeder PRO with Solar Roof",
                ],
            },
            {
                "name": "SBF w Solar Roof + Perch Extender (Retail)",
                "image": "sku-blue-solar.png",
                "badge": "Retail SKU",
                "sources": ["Smart Bird Feeder PRO Solar with PEX"],
            },
            {
                "name": "HBF",
                "image": "sku-hbf.webp",
                "sources": ["Smart Hummingbird Feeder", "Smart Hummingbird Feeder PRO"],
            },
            {
                "name": "HBF w Solar Roof",
                "image": "sku-hbf-solar.webp",
                "sources": [
                    "Smart Hummingbird Feeder with Solar Roof",
                    "Smart Hummingbird Feeder with Solar Roof PRO",
                ],
            },
            {
                "name": "HBF w Solar Roof + extra base&flower ports (Retail)",
                "image": "sku-hbf-solar.webp",
                "badge": "Retail SKU",
                "sources": ["Smart Hummingbird Feeder PRO Solar (Retail SKU)"],
            },
            {
                "name": "Nook",
                "image": "nook.webp",
                "badge": "BB2",
                "sources": ["Bird Buddy Nook"],
            },
            {
                "name": "Nook w Solar Roof",
                "image": "nook-solar.webp",
                "badge": "BB2",
                "sources": ["Bird Buddy Nook Solar"],
            },
            {
                "name": "Nook + Bird Anatomy book (Learning Bundle)",
                "image": "nook-learning-bundle.webp",
                "badge": "BB2",
                "sources": ["Bird Buddy Nook (The Learning Bundle)"],
            },
            {
                "name": "Nature Cam PRO",
                "image": "nature-cam-icon.png",
                "badge": "PRO",
                "sources": ["Nature Cam PRO"],
            },
        ],
        sources,
        PNL_UNIT_CHANNELS,
    )
    family_addons = merged_products(
        [
            {
                "name": "SBF Solar Roof",
                "image": "solar roof blue.png",
                "sources": ["Solar Roof Single - Blue", "Solar Roof Single - Yellow"],
            },
            {"name": "Wall Mount", "image": "wall mount.png", "sources": ["Wall Mount"]},
            {"name": "Suet Ball Holder", "image": "suet ball.png", "sources": ["Suet Ball Holder"]},
            {
                "name": "3-in-1 Nutrition Set",
                "image": "nutrition blue.png",
                "sources": ["3-in-1 Nutrition Set - Blue", "3-in-1 Nutrition Set - Yellow"],
            },
            {
                "name": "Perch Extender",
                "image": "perch blue.png",
                "sources": ["Perch Extender - Blue", "Perch Extender - Yellow"],
            },
            {"name": "HBF housing", "image": "hbf housing.png", "sources": ["Housing - only (HBF)"]},
            {"name": "HBF Solar Roof", "image": "hbf roof.png", "sources": ["Solar Roof (HBF)"]},
            {
                "name": "Pole System",
                "image": "nature-station-essential.webp",
                "sources": ["Nature Station Essential", "Nature Station Bloom"],
            },
            {"name": "Planter Base", "image": "pollinator-pot.webp", "sources": ["Pollinator Pot"]},
            {
                "name": "Nook Perch Extender",
                "image": "nook-perch-extender.webp",
                "badge": "BB2",
                "sources": ["Nook Perch Extender - White"],
            },
            {
                "name": "Nook Solar Roof",
                "image": "nook-solar.webp",
                "badge": "BB2",
                "sources": ["Nook Solar Roof"],
            },
        ],
        ADDON_PRODUCTS,
        PNL_ADDON_CHANNELS,
    )
    return family_skus, family_addons, merged_seed_items()


# The product line-up the P&L is reporting: the raw SKUs, the default merge, or the
# SBF/HBF families above.
def pnl_product_sets(mode: str) -> tuple[List[dict], List[dict], List[dict]]:
    if mode == "families":
        return family_pnl_product_sets()
    if mode == "merged":
        return merged_pnl_product_sets()
    return list(SKU_PRODUCTS), list(ADDON_PRODUCTS), pnl_seed_items()


def metric_summary(df: pd.DataFrame) -> Dict[str, float]:
    nums = df.select_dtypes(include=[np.number]).fillna(0).sum().to_dict()
    total_revenue = nums.get("Total_Revenue", 0.0)
    total_spend = nums.get("Total_Spend", 0.0)
    dtc_revenue = nums.get("DTC_Revenue", 0.0)
    dtc_spend = nums.get("Total_DTC_Spend", 0.0)
    amazon_revenue = nums.get("Amazon_Revenue", 0.0)
    amazon_spend = nums.get("Amazon_Spend", 0.0)
    app_revenue = nums.get("App_Revenue", 0.0)
    app_spend = nums.get("Total_App_Spend", 0.0)

    dtc_hw_units = nums.get("DTC_Hardware_Units", 0.0)
    dtc_total_hw_units = nums.get("DTC_Total_Hardware_Units", dtc_hw_units)
    amazon_hw_units = nums.get("Amazon_Hardware_Units", 0.0)
    blended_units = dtc_total_hw_units + amazon_hw_units

    # Renewals come off the headline by clearing the subscription lines, so subtracting
    # them here gives the w/o-renewals basis whichever way the toggle is set.
    subscriptions = nums.get("DTC_Total_Subscription", nums.get("DTC_Subscription", 0.0)) + nums.get(
        "DTC_Total_Subscription_Taxes", nums.get("DTC_Subscription_Taxes", 0.0)
    )
    revenue_wo_renewals = total_revenue - subscriptions
    retail_revenue = nums.get("Retail_Revenue", 0.0)

    nums["Blended_ROAS_calc"] = safe_div(total_revenue, total_spend)
    nums["Blended_ROAS_WO_Renewals_calc"] = safe_div(revenue_wo_renewals, total_spend)
    nums["Blended_ROAS_WO_Renewals_Retail_calc"] = safe_div(revenue_wo_renewals + retail_revenue, total_spend)
    nums["wROAS_calc"] = safe_div(dtc_revenue, dtc_spend)
    nums["aROAS_calc"] = safe_div(amazon_revenue, amazon_spend)
    nums["appROAS_calc"] = safe_div(app_revenue, app_spend)
    nums["Blended_SPU_calc"] = safe_div(total_spend, blended_units)
    nums["wSPU_calc"] = safe_div(dtc_spend, dtc_hw_units)
    nums["aSPU_calc"] = safe_div(amazon_spend, amazon_hw_units)
    nums["appSPU_calc"] = safe_div(app_spend, nums.get("App_Orders", 0.0))
    nums["wROAS_US_calc"] = safe_div(nums.get("DTC_US_Revenue", 0.0), nums.get("DTC_US_Spend", 0.0))
    nums["wROAS_EU_calc"] = safe_div(nums.get("DTC_EU_Revenue", 0.0), nums.get("DTC_EU_Spend", 0.0))
    nums["aROAS_US_calc"] = safe_div(nums.get("Amazon_US_Revenue", 0.0), nums.get("Amazon_Spend_US", 0.0))
    nums["aROAS_EU_calc"] = safe_div(nums.get("Amazon_EU_Revenue", 0.0), nums.get("Amazon_Spend_EU", 0.0))
    nums["wSPU_US_calc"] = safe_div(nums.get("DTC_US_Spend", 0.0), nums.get("DTC_US_Hardware_Units", 0.0))
    nums["wSPU_EU_calc"] = safe_div(nums.get("DTC_EU_Spend", 0.0), nums.get("DTC_EU_Hardware_Units", 0.0))
    nums["aSPU_US_calc"] = safe_div(nums.get("Amazon_Spend_US", 0.0), nums.get("Amazon_US_Hardware_Units", 0.0))
    nums["aSPU_EU_calc"] = safe_div(nums.get("Amazon_Spend_EU", 0.0), nums.get("Amazon_EU_Hardware_Units", 0.0))

    if "DTC_Orders" in df.columns:
        weights = df["DTC_Orders"].fillna(0)
        for col in [
            "Web_CR",
            "Web_AOV",
            "Web_AOV_WO_Renewals",
            "fAOV",
            "rAOV",
            "Web_RPU",
            "Web_RPU_WO_Renewals",
            "fRPU",
            "rRPU",
            "Returning_Customers",
            "First_Time_Customers",
        ]:
            if col in df.columns:
                nums[f"{col}_weighted"] = weighted_mean(df[col], weights)
    weighted_specs = {
        "Blended_ROAS_WO_Renewals": "Total_Spend",
        "Blended_ROAS_WO_Renewals_Retail": "Total_Spend",
        "wROAS_WO_Renewals": "Total_DTC_Spend",
        "wROAS_US_WO_Renewals": "DTC_US_Spend",
        "wROAS_EU_WO_Renewals": "DTC_EU_Spend",
        "wSPU_US": "DTC_US_Hardware_Units",
        "wSPU_EU": "DTC_EU_Hardware_Units",
        "aSPU_US": "Amazon_US_Hardware_Units",
        "aSPU_EU": "Amazon_EU_Hardware_Units",
        "aROAS_US": "Amazon_Spend_US",
        "aROAS_EU": "Amazon_Spend_EU",
        "Amazon_RPU": "Amazon_Hardware_Units",
        "Amazon_RPU_US": "Amazon_US_Hardware_Units",
        "Amazon_RPU_EU": "Amazon_EU_Hardware_Units",
    }
    for col, weight_col in weighted_specs.items():
        if col in df.columns and weight_col in df.columns:
            nums[f"{col}_weighted"] = weighted_mean(df[col], df[weight_col].fillna(0))
    return nums


def product_counts(df: pd.DataFrame, products: Sequence[dict], channels: Sequence[str]) -> Dict[str, Dict[str, float]]:
    out: Dict[str, Dict[str, float]] = {}
    for product in products:
        row = {}
        for channel in channels:
            row[channel] = float(sum_cols(df, product_cols_for_channel(product, channel)).sum())
        row["All"] = float(sum(row.get(channel, 0.0) for channel in channels))
        out[product["name"]] = row
    return out


def hardware_base(counts: Dict[str, Dict[str, float]]) -> Dict[str, float]:
    """Feeder units per channel, the denominator every SKU-mix percentage uses."""
    base: Dict[str, float] = {}
    for row in counts.values():
        for channel, value in row.items():
            base[channel] = base.get(channel, 0.0) + value
    return base


def product_name_tag(product: dict):
    display_name = product.get("display_name", product["name"])
    note = product.get("note")
    # Products whose earlier name differs carry the reason on the row itself, so the
    # unit count reads as one product rather than looking like a gap in the history.
    tail = f'<i class="summary-detail-note" data-note="{html.escape(note, quote=True)}">i</i>' if note else ""
    if product.get("merged"):
        return ui.HTML(html.escape(display_name) + tail)
    color = product.get("color")
    if not color:
        return ui.HTML(display_name + tail)
    first, sep, rest = display_name.partition(" ")
    if not sep:
        return ui.HTML(f'<span style="color:{color};">{html.escape(display_name)}</span>{tail}')
    return ui.HTML(f'<span style="color:{color};">{first}</span> {rest}{tail}')


def channel_header(channel: str):
    if channel == "All":
        return ui.HTML("ALL<br/>CHANNELS")
    return channel


def channel_dom_key(channel: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", channel.lower()).strip("-") or "channel"


def total_label(channel: str):
    if channel == "All":
        return ui.HTML("GRAND<br/>TOTAL")
    return ui.HTML(f"{channel.upper()}<br/>TOTAL")


def mix_share(value: float, base: Optional[float]) -> Optional[float]:
    """A product's units as a share of its channel's hardware units.

    The denominator is always the feeder count, so the hardware rows read as a
    mix that adds to 100% and the add-on, seed and gift-bag rows read as an
    attach rate per feeder sold. Channels with no feeders of their own (the app
    stores) have no base, so they report nothing rather than a false zero.
    """
    if not base:
        return None
    return value / base


def mix_cell_text(value: float, share: Optional[float]) -> Tuple[str, str]:
    """The percentage shown in the cell, and the richer text for its hover tip."""
    if share is None:
        return "-", f"- ({fmt_num(value)} units)"
    return fmt_pct(share), f"{fmt_pct(share)} ({fmt_num(value)} units)"


def product_value_cell(
    product: dict,
    row_counts: Dict[str, float],
    channel: str,
    prev_row_counts: Optional[Dict[str, float]] = None,
    *,
    mix_base: Optional[Dict[str, float]] = None,
    prev_mix_base: Optional[Dict[str, float]] = None,
):
    current = row_counts.get(channel, 0)
    if mix_base is None:
        display = tip_value = fmt_num(current)
        yoy = (
            yoy_pct_html(current, prev_row_counts.get(channel, 0), prev_formatter=fmt_num)
            if prev_row_counts
            else ""
        )
    else:
        share = mix_share(current, mix_base.get(channel, 0.0))
        display, tip_value = mix_cell_text(current, share)
        prev_share = (
            mix_share(prev_row_counts.get(channel, 0), (prev_mix_base or {}).get(channel, 0.0))
            if prev_row_counts is not None
            else None
        )
        yoy = yoy_pct_html(share, prev_share, prev_formatter=fmt_pct) if share is not None else ""
    return ui.div(
        ui.div(display, class_=f"product-number {'all-channel' if channel == 'All' else ''}"),
        ui.HTML(yoy or ""),
        class_="product-number-wrap product-value-cell",
        **{
            "data-channel": channel_dom_key(channel),
            "data-channel-label": channel_header(channel) if isinstance(channel_header(channel), str) else "All Channels",
            "data-product": product.get("display_name", product["name"]),
            "data-sku": product.get("sku", ""),
            "data-value": tip_value,
        },
    )


def build_product_section(
    title: str,
    products: Sequence[dict],
    counts: Dict[str, Dict[str, float]],
    channels: Sequence[str],
    *,
    show_all: bool = True,
    values_width: Optional[int] = None,
    export_id: Optional[str] = None,
    prev_counts: Optional[Dict[str, Dict[str, float]]] = None,
    mix_base: Optional[Dict[str, float]] = None,
    prev_mix_base: Optional[Dict[str, float]] = None,
):
    value_channels = [*channels, "All"] if show_all else list(channels)
    value_width = values_width or (140 if len(value_channels) == 1 else 96 * len(channels) + (125 if show_all else 0))
    base_columns = ["140px"] if not show_all and len(channels) == 1 else ["96px" for _ in channels]
    value_columns = " ".join(base_columns + (["125px"] if show_all else []))
    section_style = f"--values-width:{value_width}px; --values-columns:{value_columns};"
    header = ui.div(
        ui.div(title, class_="product-title"),
        ui.div(
            *(
                ui.div(
                    channel_header(channel),
                    class_=f"product-channel {'all-channel' if channel == 'All' else ''}",
                    **{"data-channel": channel_dom_key(channel)},
                )
                for channel in value_channels
            ),
            class_="product-values",
        ),
        class_="product-header",
    )
    rows = []
    totals = {channel: 0.0 for channel in value_channels}
    prev_totals = {channel: 0.0 for channel in value_channels}
    for idx, product in enumerate(products):
        row_counts = counts[product["name"]]
        for channel in totals:
            totals[channel] += row_counts.get(channel, 0.0)
            if prev_counts:
                prev_totals[channel] += prev_counts.get(product["name"], {}).get(channel, 0.0)
        rows.append(
            ui.div(
                ui.div(
                    product_img(product["image"], product.get("display_name", product["name"]), product.get("badge")),
                    class_="product-image-cell",
                ),
                ui.div(
                    ui.div(
                        product_name_tag(product),
                        class_="product-name",
                    ),
                    ui.div(product.get("sku", ""), class_="product-sku"),
                    class_="product-copy",
                ),
                ui.div(
                    *(
                        product_value_cell(
                            product,
                            row_counts,
                            channel,
                            prev_counts.get(product["name"], {}) if prev_counts else None,
                            mix_base=mix_base,
                            prev_mix_base=prev_mix_base,
                        )
                        for channel in value_channels
                    ),
                    class_="product-values",
                ),
                class_="product-row alt" if idx % 2 else "product-row",
            )
        )
    def total_text(channel: str) -> Tuple[str, str]:
        value = totals[channel]
        if mix_base is None:
            return fmt_num(value), fmt_num(value)
        return mix_cell_text(value, mix_share(value, mix_base.get(channel, 0.0)))

    def total_yoy(channel: str) -> str:
        if not prev_counts:
            return ""
        if mix_base is None:
            return yoy_pct_html(totals[channel], prev_totals[channel], prev_formatter=fmt_num) or ""
        share = mix_share(totals[channel], mix_base.get(channel, 0.0))
        prev_share = mix_share(prev_totals[channel], (prev_mix_base or {}).get(channel, 0.0))
        if share is None:
            return ""
        return yoy_pct_html(share, prev_share, prev_formatter=fmt_pct) or ""

    total_row = ui.div(
        ui.div("", class_="product-total-spacer"),
        ui.div(
            *(
                ui.div(
                    ui.div(total_label(channel), class_="product-total-label"),
                    ui.div(
                        ui.div(total_text(channel)[0], class_=f"product-total-number {'all-channel' if channel == 'All' else ''}"),
                        ui.HTML(total_yoy(channel) or ""),
                        class_="product-total-number-wrap",
                    ),
                    class_="product-total-cell",
                    **{
                        "data-channel": channel_dom_key(channel),
                        "data-channel-label": channel_header(channel) if isinstance(channel_header(channel), str) else "All Channels",
                        "data-product": f"{title} Total",
                        "data-sku": "",
                        "data-value": total_text(channel)[1],
                    },
                )
                for channel in value_channels
            ),
            class_="product-values",
        ),
        class_="product-total-row",
    )
    return ui.div(
        ui.div(header, *rows, total_row, class_="product-table-scroll"),
        export_button(export_id) if export_id else None,
        class_="product-section",
        style=section_style,
    )


def clean_question_label(col: str, question: str, segment: str = "all") -> str:
    prefix = question
    if question in {"q1", "q2", "q3"}:
        if segment == "new":
            prefix = "N" + question
        elif segment == "ret":
            prefix = "O" + question
    return col.replace(prefix + "_", "")


def short_survey_label(label: str) -> str:
    aliases = {
        "Facebook / Instagram": "Facebook / IG",
        "Google, Youtube": "Google / YouTube",
        "I saw a post about Bird Buddy on my friend's feed": "Friend's feed",
        "I saw an organic post from Bird Buddy": "Organic Bird Buddy post",
        "I will use with my family": "Use with family",
        "Yes, I did extensive research": "Extensive research",
        "Yes, but very briefly": "Brief comparison",
        "Very, I love learning about birds": "Very important",
        "It's not the main point for me, but nice": "Nice, not the main point",
        "Beginner (New to birding)": "Beginner",
        "Intermediate (Moderate understanding)": "Intermediate",
        "Advanced (In-depth knowledge)": "Advanced",
        "Yes, I am growing one": "Growing one",
        "Yes, but haven't tried": "Familiar, haven't tried",
        "No, I have no idea what this is": "Not familiar",
    }
    if label in aliases:
        return aliases[label]
    return label if len(label) <= 24 else label[:21].rstrip() + "..."


def survey_cols(question: str, segment: str = "all") -> List[str]:
    if question in {"q1", "q2", "q3"}:
        prefix = question if segment == "all" else ("N" + question if segment == "new" else "O" + question)
    else:
        prefix = question
    cols = [col for col in survey_data.columns if col.startswith(prefix + "_")]
    if not cols and question in {"q1", "q2", "q3"}:
        cols = [col for col in survey_data.columns if col.startswith(question + "_")]
    return cols


def pie_from_columns(df: pd.DataFrame, question: str, segment: str = "all", height: int = 360) -> go.Figure:
    cols = survey_cols(question, segment)
    if not cols or df.empty:
        return empty_fig("No survey data for this range.", height)
    totals = df[cols].fillna(0).sum().reset_index()
    totals.columns = ["label", "count"]
    totals["label"] = totals["label"].map(lambda value: clean_question_label(value, question, segment))
    totals["display_label"] = totals["label"].map(short_survey_label)
    totals = totals[totals["count"] > 0]
    if totals.empty:
        return empty_fig("No survey data for this range.", height)
    many_slices = len(totals) > 4
    compact = height <= 380
    fig = go.Figure(
        go.Pie(
            labels=totals["display_label"],
            values=totals["count"],
            customdata=totals["label"],
            textinfo="none",
            texttemplate="%{percent:.1%}" if many_slices and compact else "%{label}<br>%{percent:.1%}",
            textposition="inside",
            insidetextorientation="horizontal",
            hovertemplate="%{customdata}: %{value:,.0f} responses (%{percent:.1%})<extra></extra>",
            marker={"colors": SET2, "line": {"color": "#ffffff", "width": 2}},
            sort=False,
            direction="clockwise",
            domain={"x": [0.0, 1.0], "y": [0.0, 1.0] if compact else [0.02, 0.82]},
        )
    )
    fig.update_layout(
        autosize=not compact,
        width=360 if compact else None,
        height=height,
        template="plotly_white",
        margin={"l": 0, "r": 0, "t": 0 if compact else 64, "b": 0 if compact else 8},
        paper_bgcolor="#ffffff",
        plot_bgcolor="#ffffff",
        font={"family": "Montserrat", "size": 12, "color": "#34495e"},
        showlegend=not compact,
        legend={
            "orientation": "h",
            "x": 0.5,
            "y": 1.06,
            "xanchor": "center",
            "yanchor": "top",
            "font": {"family": "Montserrat", "size": 11},
            "itemwidth": 30,
            "tracegroupgap": 2,
        },
        uniformtext={"minsize": 10, "mode": "hide"},
    )
    return fig


def stacked_survey(
    df: pd.DataFrame,
    question: str,
    segment: str,
    by_month: bool,
    line_view: bool = False,
) -> go.Figure:
    cols = survey_cols(question, segment)
    if not cols or df.empty:
        return empty_fig("No survey data for this range.", 700)
    long = df[["Date"] + cols].copy()
    if by_month:
        long = monthly_date(long).groupby("Date", as_index=False)[cols].sum()
    else:
        long = long.groupby("Date", as_index=False)[cols].sum()
    # Drop empty periods so All Time does not open a blank stretch before a question began.
    long = long.loc[long[cols].fillna(0).sum(axis=1) > 0].copy()
    if long.empty:
        return empty_fig("No survey data for this range.", 700)
    long = long.melt(id_vars="Date", var_name="Category", value_name="Count")
    long["Category"] = long["Category"].map(lambda value: clean_question_label(value, question, segment))
    totals = long.groupby("Date")["Count"].transform("sum")
    long["Share"] = np.where(totals > 0, long["Count"] / totals, 0)
    if long["Count"].sum() == 0:
        return empty_fig("No survey data for this range.", 700)
    fig = go.Figure()
    categories = sorted(long["Category"].dropna().unique())
    overall = long.groupby("Category")["Count"].sum()
    grand = overall.sum()
    hover_x = "%{x|%b %Y}" if by_month else "%{x|%b %d, %Y}"
    for idx, category in enumerate(categories):
        sub = long[long["Category"] == category]
        pct = safe_div(overall.get(category, 0), grand)
        name = f"{category} ({pct * 100:.1f}%)" if not pd.isna(pct) else category
        trace_args = {
            "x": sub["Date"],
            "y": sub["Share"],
            "name": name,
            "customdata": np.stack([sub["Count"]], axis=-1),
            "hovertemplate": f"{hover_x}<br>%{{fullData.name}}<br>%{{y:.1%}} (%{{customdata[0]:,.0f}})<extra></extra>",
        }
        if line_view:
            fig.add_scatter(
                **trace_args,
                mode="lines",
                line={"color": SET2[idx % len(SET2)], "width": 2.25},
            )
        else:
            fig.add_bar(**trace_args, marker_color=SET2[idx % len(SET2)])
    if not line_view:
        fig.update_layout(barmode="stack")
    return finish_fig(fig, height=700, percent_y=True)


CSS = """
@import url('https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap');
:root {
  --green: #2ecc71;
  --red: #A52A2A;
  --blue: #3498db;
  --yellow: #f1c40f;
  --purple: #9b59b6;
  --gray: #7b868c;
  --ink: #222;
  --line: #ddd;
  --panel: #ffffff;
  --page: #ecf0f5;
  --sidebar: #f5f5f5;
  --sidebar-active: #e0e0e0;
}
html,
body {
  background: var(--page);
  font-family: 'Montserrat', sans-serif;
  color: var(--ink);
  min-height: 100%;
}
body > .container-fluid {
  max-width: none;
  width: 100%;
  padding: 0;
}
.app-title {
  display: none;
}
.app-topbar {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-left: 250px;
  padding: 15px 24px 0;
  min-height: 145px;
  background: var(--page);
}
.top-left-tools {
  display: flex;
  align-items: flex-start;
  justify-content: flex-start;
  gap: 14px;
  width: 460px;
  min-width: 0;
}
.top-left-tools .shiny-input-container,
.dtc-view-control,
.amazon-view-control,
.dtc-view-control > .shiny-input-container,
.amazon-view-control > .shiny-input-container {
  width: 100% !important;
}
.top-left-tools label {
  color: #6b7280;
  font-family: 'Montserrat', sans-serif;
  font-weight: 700;
  font-size: 13px;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  margin-bottom: 6px;
}
.top-left-tools .form-select,
.top-left-tools select {
  width: 100% !important;
  min-height: 42px;
  height: 42px;
  padding: 10px 40px 10px 14px;
  border: 1px solid #dfe4ea;
  border-radius: 12px;
  background-color: #fff;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%236b7280' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><polyline points='6 9 12 15 18 9'/></svg>");
  background-repeat: no-repeat;
  background-position: right 14px center;
  background-size: 14px 14px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
  color: #1f2937;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.1px;
  appearance: none;
  -webkit-appearance: none;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease, background-color 0.15s ease;
}
.top-left-tools .form-select:hover,
.top-left-tools select:hover {
  border-color: #b0b8c0;
}
.top-left-tools .form-select:focus,
.top-left-tools select:focus {
  outline: none;
  border-color: rgba(46, 204, 113, 0.55);
  box-shadow: 0 0 0 3px rgba(46, 204, 113, 0.12);
}
.date-tools {
  display: flex;
  flex-direction: column;
  gap: 10px;
  align-items: stretch;
  justify-content: flex-start;
  width: 380px;
  min-width: 0;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
}
.date-tools .form-group,
.date-tools .checkbox {
  margin-bottom: 0;
}
#selected_date_range,
.date-toggles,
.date-toggle,
.date-toggle > .shiny-input-container {
  width: auto !important;
}
.date-picker-wrap {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.date-picker-label {
  color: #6b7280;
  font-family: 'Montserrat', sans-serif;
  font-weight: 700;
  font-size: 13px;
  letter-spacing: 0.4px;
  text-transform: uppercase;
}
.date-iso-hidden { display: none !important; }
.date-range-trigger {
  width: 100%;
  min-height: 42px;
  padding: 10px 40px 10px 42px;
  border: 1px solid #dfe4ea;
  border-radius: 12px;
  background: #fff url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="%236b7280" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>') no-repeat 14px center;
  background-size: 16px 16px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
  color: #1f2937;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.1px;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease, background-color 0.15s ease;
  appearance: none;
}
.date-range-trigger:hover {
  border-color: #b0b8c0;
}
.date-range-trigger:focus {
  outline: none;
  border-color: rgba(46, 204, 113, 0.55);
  box-shadow: 0 0 0 3px rgba(46, 204, 113, 0.12);
}
.daterangepicker {
  border: 1px solid #e5e9ef !important;
  border-radius: 12px !important;
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.14) !important;
  font-family: 'Montserrat', sans-serif !important;
  font-size: 11px !important;
  padding: 6px !important;
  min-width: 0 !important;
  width: auto !important;
}
.daterangepicker::before,
.daterangepicker::after { display: none !important; }
.daterangepicker .ranges { padding: 6px 4px !important; }
.daterangepicker .ranges ul { width: 130px !important; margin: 0 !important; }
.daterangepicker .ranges li {
  padding: 5px 10px !important;
  border-radius: 7px !important;
  color: #374151 !important;
  font-size: 11px !important;
  font-weight: 600 !important;
  line-height: 1.3 !important;
  transition: background 0.12s ease, color 0.12s ease;
}
.daterangepicker .ranges li:hover {
  background: rgba(46, 204, 113, 0.08) !important;
  color: #111 !important;
}
.daterangepicker .ranges li.active {
  background: rgba(46, 204, 113, 0.12) !important;
  color: var(--green) !important;
}
.daterangepicker .drp-calendar {
  padding: 4px !important;
  max-width: 220px !important;
  min-width: 0 !important;
}
.daterangepicker.show-calendar { min-width: 560px !important; width: max-content !important; }
.daterangepicker.show-calendar .ranges { float: left !important; }
.daterangepicker.show-calendar .drp-calendar { float: left !important; clear: none !important; display: block !important; }
.daterangepicker.show-calendar .drp-buttons { clear: both !important; }
.daterangepicker .drp-calendar.left .calendar-table,
.daterangepicker .drp-calendar.right .calendar-table {
  border: none !important;
  padding: 0 !important;
}
.daterangepicker .calendar-table {
  padding: 4px !important;
  border: none !important;
}
.daterangepicker .calendar-table th,
.daterangepicker .calendar-table td {
  min-width: 24px !important;
  width: 24px !important;
  height: 24px !important;
  font-size: 11px !important;
  padding: 0 !important;
  line-height: 24px !important;
}
.daterangepicker .month {
  font-size: 11px !important;
  font-weight: 600 !important;
}
.daterangepicker td.available:hover,
.daterangepicker th.available:hover {
  background: rgba(46, 204, 113, 0.08) !important;
}
.daterangepicker td.active,
.daterangepicker td.active:hover {
  background: var(--green) !important;
  color: #fff !important;
}
.daterangepicker td.in-range {
  background: rgba(46, 204, 113, 0.15) !important;
  color: #1f2937 !important;
}
.daterangepicker td.start-date,
.daterangepicker td.end-date {
  background: var(--green) !important;
  color: #fff !important;
}
.daterangepicker td.start-date.in-range { border-radius: 999px 0 0 999px !important; }
.daterangepicker td.end-date.in-range { border-radius: 0 999px 999px 0 !important; }
.daterangepicker .drp-buttons { padding: 8px !important; border-top-color: #eef1f4 !important; }
.daterangepicker .drp-buttons .btn {
  border-radius: 7px !important;
  padding: 5px 12px !important;
  font-family: 'Montserrat', sans-serif !important;
  font-size: 11px !important;
  font-weight: 600 !important;
}
.daterangepicker .drp-selected {
  font-size: 11px !important;
}
.daterangepicker .drp-buttons .applyBtn {
  background: var(--green) !important;
  border-color: var(--green) !important;
}
.daterangepicker .drp-buttons .cancelBtn {
  background: #f4f5f7 !important;
  border-color: #e0e3e8 !important;
  color: #4b5563 !important;
}
.daterangepicker select {
  border-radius: 6px !important;
  border-color: #dfe4ea !important;
  padding: 2px 4px !important;
  font-family: 'Montserrat', sans-serif !important;
  font-size: 11px !important;
}
.date-toggles {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
}
.date-toggle {
  display: inline-flex;
}
.date-toggle > .shiny-input-container,
.date-toggle .form-group {
  margin: 0 !important;
}
.date-toggle .checkbox,
.date-toggle .form-check {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  padding: 6px 12px 6px 10px;
  border: 1px solid #dfe4ea;
  border-radius: 999px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
  transition: border-color 0.15s ease, box-shadow 0.15s ease, background 0.15s ease;
  cursor: pointer;
}
.date-toggle .checkbox:hover,
.date-toggle .form-check:hover {
  border-color: #b0b8c0;
}
.date-toggle .checkbox label,
.date-toggle .form-check {
  min-height: 22px;
}
.date-toggle .checkbox label {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  padding: 0;
  cursor: pointer;
}
.date-toggle .checkbox input[type="checkbox"],
.date-toggle .form-check-input {
  position: static;
  float: none;
  width: 15px;
  height: 15px;
  margin: 0;
  border-color: #b8bfc7;
  cursor: pointer;
}
.date-toggle .checkbox input[type="checkbox"]:checked,
.date-toggle .form-check-input:checked {
  background-color: var(--green);
  border-color: var(--green);
}
.date-toggle .checkbox:has(input[type="checkbox"]:checked),
.date-toggle .form-check:has(input[type="checkbox"]:checked) {
  border-color: rgba(46, 204, 113, 0.55);
  background: rgba(46, 204, 113, 0.08);
  box-shadow: 0 1px 3px rgba(46, 204, 113, 0.15);
}
.date-toggle .checkbox span,
.date-toggle .form-check-label {
  color: #333;
  font-family: 'Montserrat', sans-serif;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.1px;
  line-height: 1;
}
.date-toggle {
  align-items: center;
  gap: 5px;
}
.date-toggle[data-toggle-tip] {
  position: relative;
}
/* Anchored to the right edge because this toggle sits at the end of the top bar. */
.date-toggle[data-toggle-tip]::after {
  content: attr(data-toggle-tip);
  position: absolute;
  right: 0;
  top: calc(100% + 8px);
  width: 268px;
  background: #1f2937;
  color: #fff;
  padding: 9px 11px;
  border-radius: 8px;
  font-family: 'Montserrat', sans-serif;
  font-size: 11px;
  font-weight: 500;
  line-height: 1.5;
  letter-spacing: 0.01em;
  text-align: left;
  text-transform: none;
  white-space: normal;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.18);
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s ease;
  z-index: 300;
}
.date-toggle[data-toggle-tip]::before {
  content: "";
  position: absolute;
  right: 26px;
  top: 100%;
  border: 5px solid transparent;
  border-bottom-color: #1f2937;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s ease;
  z-index: 300;
}
.date-toggle[data-toggle-tip]:hover::after,
.date-toggle[data-toggle-tip]:hover::before {
  opacity: 1;
}
.date-tools label {
  font-family: 'Montserrat', sans-serif;
  font-weight: 700;
  font-size: 13px;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  color: #6b7280;
  margin-bottom: 6px;
}
.date-tools .shiny-date-range-input {
  width: 380px !important;
}
.date-tools .input-group,
.date-tools .input-daterange {
  display: flex !important;
  flex-wrap: nowrap;
  align-items: stretch;
  width: 100%;
  border: 1px solid #dfe4ea;
  border-radius: 10px;
  background: #fff;
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.date-tools .input-group:focus-within,
.date-tools .input-daterange:focus-within {
  border-color: rgba(46, 204, 113, 0.55);
  box-shadow: 0 0 0 3px rgba(46, 204, 113, 0.12);
}
.date-tools .form-control,
.control-row .form-control,
.control-row select,
.control-row .selectize-input {
  border: 1px solid #ccc;
  border-radius: 10px;
  box-shadow: none;
  font-family: 'Montserrat', sans-serif;
  font-size: 16px;
  min-height: 42px;
  padding: 10px 12px;
}
.date-tools .form-control {
  flex: 1 1 0;
  width: auto;
  min-width: 0;
  min-height: 40px;
  height: 40px;
  padding: 8px 12px;
  border: 0 !important;
  border-radius: 0 !important;
  background: transparent;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 500;
  color: #1f2937;
  text-align: center;
}
.date-tools .form-select,
.date-tools select {
  width: 100% !important;
  min-height: 38px;
  height: 38px;
  border: 1px solid #cbd2d9;
  border-radius: 4px;
  background-color: #fff;
  color: #333;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  padding: 8px 36px 8px 10px;
}
.date-tools .input-group-text,
.date-tools .input-group-addon {
  display: flex;
  flex: 0 0 34px;
  align-items: center;
  justify-content: center;
  height: 40px;
  min-height: 40px;
  width: 34px;
  padding: 0;
  border: 0;
  background: transparent;
  color: #9aa3aa;
  font-family: 'Montserrat', sans-serif;
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 0.4px;
  text-transform: lowercase;
}
.date-tools .input-group > :first-child,
.date-tools .input-group > :last-child {
  border-radius: 0;
}
.date-tools .form-control:focus,
.top-left-tools select:focus,
.top-left-tools .form-select:focus,
.control-row .form-control:focus,
.control-row select:focus,
.control-row .selectize-input.focus {
  border-color: var(--green);
  box-shadow: 0 0 0 3px rgba(46, 204, 113, 0.12);
}
.date-tools .form-control:focus {
  outline: none;
  box-shadow: none;
}
.control-row .selectize-control {
  margin-bottom: 0;
}
.control-row .selectize-dropdown {
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
}
.nav-tabs,
ul.nav.nav-tabs {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 0;
  z-index: 1000;
  display: flex !important;
  flex-direction: column !important;
  justify-content: flex-start !important;
  align-content: stretch !important;
  gap: 0 !important;
  width: 250px;
  margin: 0;
  padding: 34px 0 0;
  overflow-y: auto;
  background: var(--sidebar) !important;
  border: 0;
  border-right: 1px solid var(--line);
}
.nav-tabs > li,
.nav-tabs .nav-item {
  display: block;
  float: none;
  flex: 0 0 auto !important;
  width: 100%;
  margin: 0;
}
.nav-tabs > li > a,
.nav-tabs .nav-link {
  display: block;
  width: 100%;
  height: auto !important;
  margin: 0;
  padding: 13px 16px;
  border: 0 !important;
  border-radius: 0 !important;
  background: transparent !important;
  color: #333 !important;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 700;
  line-height: 20px;
}
.nav-tabs > li > a:hover,
.nav-tabs .nav-link:hover,
.nav-tabs > li.active > a,
.nav-tabs .nav-link.active {
  background: var(--sidebar-active) !important;
  color: #333 !important;
  border-left: 4px solid #3c8dbc !important;
  padding-left: 12px;
}
.menu-title {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 20px;
}
.menu-icon {
  display: inline-flex;
  width: 18px;
  min-width: 18px;
  height: 18px;
  align-items: center;
  justify-content: center;
}
.menu-icon svg {
  width: 16px;
  height: 16px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.tab-content {
  min-height: calc(100vh - 88px);
  margin-left: 250px;
  padding: 0 15px 40px;
  background: var(--page);
}
.app-section {
  padding: 18px 20px 22px;
  min-width: 0;
}
.section-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 18px;
  margin-bottom: 12px;
}
.section-title {
  color: #333;
  font-family: 'Montserrat', sans-serif;
  font-size: 23px;
  font-weight: 700;
  line-height: 40px;
  margin: 0;
}
.control-row {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
  justify-content: flex-end;
  min-height: 40px;
}
.control-row .form-group,
.control-row .checkbox,
.control-row .shiny-input-container {
  margin: 0;
}
.control-row .shiny-input-container {
  width: auto !important;
  min-width: 112px;
}
.control-row .control-label,
.control-row .shiny-label-null {
  display: none;
}
.control-row label {
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 500;
}
.control-row select,
.control-row .form-select,
.control-row .form-control,
.control-row .selectize-input {
  width: 100% !important;
  height: 40px;
  min-height: 40px;
  border: 1px solid #cfd6dd;
  border-radius: 8px;
  background-color: #fff;
  color: #333;
  box-shadow: 0 1px 2px rgba(22, 34, 44, 0.04);
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 500;
  line-height: 20px;
}
.control-row select,
.control-row .form-select {
  padding: 8px 32px 8px 12px;
}
.control-row select:hover,
.control-row .form-select:hover,
.control-row .form-control:hover,
.control-row .selectize-input:hover {
  border-color: #b5c0c9;
  box-shadow: 0 2px 6px rgba(22, 34, 44, 0.07);
}
.control-row .form-check {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  margin: 0;
  padding-left: 0;
}
.control-row .checkbox label {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  margin: 0;
  padding: 0 12px;
  border: 1px solid #cfd6dd;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 2px rgba(22, 34, 44, 0.04);
}
.control-row .form-check-input {
  float: none;
  margin: 0;
}
.control-row .checkbox input[type="checkbox"] {
  position: static;
  width: 15px;
  height: 15px;
  margin: 0;
}
.inline-conditional {
  display: flex;
  align-items: center;
  margin: 0;
}
.chart-card,
.metric-card,
.product-section,
.survey-card {
  background: var(--panel);
  border: 0;
  border-radius: 20px;
  box-shadow: 0 0 10px rgba(0,0,0,0.05);
}
.chart-card {
  position: relative;
  width: 100%;
  min-width: 0;
  padding: 14px 16px 10px;
  overflow: hidden;
}
.chart-export {
  position: absolute !important;
  right: 14px;
  bottom: 12px;
  z-index: 8;
  display: inline-flex !important;
  align-items: center;
  justify-content: center;
  min-width: 42px;
  height: 26px;
  padding: 0 9px !important;
  border: 1px solid rgba(123, 134, 140, 0.22) !important;
  border-radius: 7px !important;
  background: rgba(255, 255, 255, 0.82) !important;
  color: #657178 !important;
  box-shadow: 0 2px 7px rgba(22, 34, 44, 0.08) !important;
  font-family: 'Montserrat', sans-serif;
  font-size: 11px !important;
  font-weight: 700 !important;
  line-height: 1 !important;
  opacity: 0.45;
  text-decoration: none !important;
  transition: opacity 120ms ease, border-color 120ms ease, box-shadow 120ms ease;
}
/* Where a card exports twice, both pills ride in one bar rather than being placed
   individually: they stay auto-width side by side, so neither the label text nor the
   card's own fill rules can stretch one across the other. */
.chart-export-bar {
  position: absolute;
  right: 14px;
  bottom: 12px;
  z-index: 8;
  display: flex;
  align-items: center;
  gap: 6px;
}
/* Outweighs the card's fill rules below, which would otherwise stretch a bound link. */
.chart-card .chart-export-bar a.chart-export {
  position: static !important;
  right: auto;
  bottom: auto;
  flex: 0 0 auto;
  width: auto !important;
  max-width: none !important;
}
.chart-export:hover,
.chart-export:focus {
  opacity: 1;
  border-color: rgba(123, 134, 140, 0.45) !important;
  box-shadow: 0 3px 10px rgba(22, 34, 44, 0.12) !important;
}
.chart-card .html-fill-container,
.chart-card .html-fill-item,
/* Shiny tags the export links shiny-bound-output once it binds them, and filling the
   card would stretch them across it instead of leaving them as corner pills. */
.chart-card .shiny-bound-output:not(.chart-export),
.chart-card .shiny-ipywidget-output {
  display: block;
  width: 100% !important;
  max-width: 100% !important;
  min-width: 0 !important;
}
.chart-card .jupyter-widgets,
.chart-card .widget-output,
.chart-card .widget-subarea,
.chart-card .output,
.chart-card .output_area,
.chart-card .output_html,
.chart-card .plotly,
.chart-card .js-plotly-plot,
.chart-card .plot-container,
.chart-card .svg-container,
.chart-card .main-svg {
  width: 100% !important;
  max-width: 100% !important;
}
.metric-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 20px;
  margin: 0 20px 40px;
}
.metric-card {
  padding: 20px;
  min-height: 118px;
  text-align: center;
}
.metric-label {
  color: #333;
  font-size: 15px;
  font-weight: 600;
  margin-bottom: 8px;
}
.metric-value {
  font-size: 34px;
  font-weight: 700;
  line-height: 1.1;
}
.metric-subtitle {
  color: #777;
  font-size: 12px;
  min-height: 18px;
  margin-top: 8px;
}
.notes-box {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 6px 14px;
  max-height: 260px;
  overflow-y: auto;
  margin: 0 20px 20px;
  padding: 10px 12px;
  background: #f4f4f4;
  border: 0;
  border-radius: 10px;
  font-size: 12px;
  line-height: 1.4;
  scrollbar-width: thin;
  scrollbar-color: rgba(0, 0, 0, 0.18) transparent;
}
.notes-box::-webkit-scrollbar {
  width: 6px;
}
.notes-box::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.18);
  border-radius: 3px;
}
.notes-item {
  display: grid;
  grid-template-columns: 78px 1fr;
  gap: 10px;
  align-items: baseline;
  padding: 4px 0;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}
.notes-item:last-child {
  border-bottom: 0;
}
.notes-date {
  color: #6b6b6b;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.4px;
  text-transform: uppercase;
  white-space: nowrap;
}
.notes-text {
  color: #333;
}
.notes-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 0 20px 12px;
  padding: 4px 12px;
  border: 1px solid rgba(0, 0, 0, 0.12);
  border-radius: 999px;
  background: transparent;
  color: #6b6b6b;
  box-shadow: none;
  font-family: 'Montserrat', sans-serif;
  font-size: 11.5px;
  font-weight: 600;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  line-height: 1.6;
  transition: background-color 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}
.notes-toggle:hover {
  background: rgba(0, 0, 0, 0.04);
  border-color: rgba(0, 0, 0, 0.2);
  color: #333;
}
.notes-caret {
  position: relative;
  display: inline-block;
  width: 9px;
  height: 9px;
  flex: 0 0 9px;
  transform: translateY(-1px);
}
.notes-caret::before {
  content: "";
  position: absolute;
  left: 50%;
  top: 50%;
  width: 5px;
  height: 5px;
  border-right: 1.5px solid currentColor;
  border-bottom: 1.5px solid currentColor;
  transform-origin: center;
  transition: transform 0.2s ease;
}
.notes-caret.down::before {
  transform: translate(-50%, -60%) rotate(45deg);
}
.notes-caret.up::before {
  transform: translate(-50%, -40%) rotate(225deg);
}
.summary-page {
  padding: 0 5px 40px;
}
.summary-export-area {
  position: relative;
  padding-bottom: 72px;
}
.summary-export-area .chart-export {
  right: 22px;
  bottom: 22px;
}
.summary-total-band {
  margin: 0 20px 60px;
  padding: 20px;
  border-radius: 15px;
  text-align: center;
  color: #fff;
  position: relative;
  overflow: visible;
  isolation: isolate;
  box-shadow:
    0 8px 18px rgba(31, 44, 54, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.16);
}
.summary-total-band::before {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: inherit;
  pointer-events: none;
  z-index: 0;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.08) 0%, rgba(255, 255, 255, 0) 52%, rgba(0, 0, 0, 0.035) 100%);
}
.summary-total-band > * {
  position: relative;
  z-index: 1;
}
.summary-total-band.revenue {
  background: linear-gradient(180deg, #35d176 0%, #2ecc71 100%);
  box-shadow:
    0 10px 20px rgba(39, 181, 102, 0.13),
    inset 0 1px 0 rgba(255, 255, 255, 0.16);
}
.summary-total-band.spend {
  background: linear-gradient(180deg, #b83232 0%, #ad2929 100%);
  margin-top: 70px;
  box-shadow:
    0 10px 20px rgba(158, 35, 35, 0.13),
    inset 0 1px 0 rgba(255, 255, 255, 0.14);
}
.summary-band-label {
  color: #fff;
  font-size: 22px;
  font-weight: 700;
}
.summary-band-title {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 12px;
}
.summary-info {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: #fff;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  font-weight: 700;
  line-height: 22px;
}
.summary-info.green {
  color: var(--green);
}
.summary-info.red {
  color: var(--red);
}
.summary-tooltip-container {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
.summary-tooltip-text {
  position: absolute;
  z-index: 2000;
  bottom: 135%;
  left: 50%;
  width: 280px;
  padding: 10px 12px;
  border-radius: 10px;
  background: #fff;
  color: #333;
  box-shadow: 0 2px 10px rgba(0,0,0,0.2);
  font-family: 'Montserrat', sans-serif;
  font-size: 13px;
  font-weight: 400;
  line-height: 1.35;
  text-align: center;
  transform: translateX(-50%);
  visibility: hidden;
  opacity: 0;
  transition: opacity 0.18s ease;
  pointer-events: none;
}
.summary-tooltip-container:hover .summary-tooltip-text {
  visibility: visible;
  opacity: 1;
}
.summary-band-value {
  margin-top: 14px;
  color: #fff;
  font-size: 46px;
  font-weight: 700;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  line-height: 1;
}
.summary-band-value-text {
  line-height: 1;
}
.summary-band-value .yoy-delta {
  color: rgba(255,255,255,0.95);
  background: rgba(255,255,255,0.18);
}
.yoy-delta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  margin-top: 4px;
  padding: 2px 7px;
  border-radius: 999px;
  background: rgba(0,0,0,0.05);
  color: #7f8c8d;
  font-family: 'Montserrat', sans-serif;
  font-size: 11px;
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: 0;
  cursor: default;
}
.yoy-good { color: #27ae60; background: rgba(39, 174, 96, 0.10); }
.yoy-bad  { color: #c0392b; background: rgba(192, 57, 43, 0.10); }
.yoy-flat { color: #7f8c8d; background: rgba(127, 140, 141, 0.10); }
.yoy-delta[data-yoy-tip] { position: relative; cursor: help; }
.yoy-delta[data-yoy-tip]::after {
  content: attr(data-yoy-tip);
  position: absolute;
  left: 50%;
  top: calc(100% + 6px);
  transform: translateX(-50%);
  background: #1f2937;
  color: #fff;
  padding: 5px 9px;
  border-radius: 6px;
  font-family: 'Montserrat', sans-serif;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  white-space: nowrap;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.18);
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s ease;
  /* Above the cursor-following product card, which sits at 3000. */
  z-index: 3200;
}
.yoy-delta[data-yoy-tip]::before {
  content: "";
  position: absolute;
  left: 50%;
  top: 100%;
  transform: translateX(-50%);
  border: 5px solid transparent;
  border-bottom-color: #1f2937;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s ease;
  z-index: 3200;
}
.yoy-delta[data-yoy-tip]:hover::after,
.yoy-delta[data-yoy-tip]:hover::before {
  opacity: 1;
}
.summary-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 24px;
  margin: 0 20px 55px;
}
.summary-row.centered {
  justify-content: center;
}
.summary-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  min-width: 0;
  text-align: center;
}
.summary-sub-label {
  color: #333;
  font-family: 'Montserrat', sans-serif;
  font-size: 18px;
  font-weight: 700;
}
.summary-title-green,
.summary-title-red {
  font-family: 'Montserrat', sans-serif;
  font-size: 20px;
  font-weight: 700;
}
.summary-title-green {
  color: var(--green);
}
.summary-title-red {
  color: var(--red);
}
.summary-value,
.summary-click-value {
  display: block;
  border: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  padding: 4px 0 0 !important;
  font-family: 'Montserrat', sans-serif;
  line-height: 1.15;
  cursor: pointer;
}
.summary-green {
  color: var(--green) !important;
  font-size: 28px;
  font-weight: 400;
}
.summary-red {
  color: var(--red) !important;
  font-size: 28px;
  font-weight: 400;
}
.summary-black {
  color: #000 !important;
  font-size: 36px;
  font-weight: 400;
}
/* Takes the width its column offers, up to a limit, so the pills that sit beside
   each amount are not fighting the labels for room. */
.summary-detail {
  display: block;
  width: 100%;
  margin: 14px auto 0;
  padding: 14px 18px;
  min-width: 248px;
  max-width: 384px;
  border-radius: 14px;
  background: #ffffff;
  color: #4a4a4a;
  font-size: 12.5px;
  letter-spacing: 0.1px;
  line-height: 1.5;
  text-align: left;
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08), inset 0 0 0 1px rgba(0, 0, 0, 0.04);
}
.summary-detail-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 18px;
  padding: 7px 0;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}
.summary-detail-row:last-child {
  border-bottom: 0;
}
.summary-detail-memo {
  margin-top: 4px;
  padding-top: 8px;
  border-top: 1px dashed rgba(0, 0, 0, 0.16);
}
.summary-detail-memo .summary-detail-key,
.summary-detail-memo .summary-detail-val {
  color: #9aa0a6;
  font-style: italic;
  font-weight: 600;
}
/* Sets the subscription lines apart without implying they are outside the sum. */
.summary-detail-split {
  margin-top: 7px;
  padding-top: 9px;
  border-top: 1px solid rgba(0, 0, 0, 0.14);
}
.summary-detail-key {
  color: #6b6b6b;
  font-size: 12px;
  font-weight: 500;
}
.summary-detail-val {
  color: #222;
  font-size: 12.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
/* Keeps the amounts in their own column with the pill to their left. */
.summary-detail-figure {
  display: inline-flex;
  align-items: baseline;
  gap: 10px;
}
/* On a card the pill hangs below its value; in a row it sits alongside one.
   The shared width lines the pills up in a column instead of ragged. */
.summary-detail-row .yoy-delta {
  margin-top: 0;
  justify-content: center;
  min-width: 64px;
  padding: 2px 8px;
  font-size: 10px;
  letter-spacing: 0;
}
/* An "i" on a breakdown row, for lines whose basis needs a sentence of explanation. */
.summary-detail-note {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 13px;
  height: 13px;
  margin-left: 5px;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.10);
  color: #6b6b6b;
  font-size: 9px;
  font-weight: 700;
  font-style: normal;
  line-height: 1;
  cursor: help;
  vertical-align: middle;
}
.summary-detail-note::after {
  content: attr(data-note);
  position: absolute;
  left: 50%;
  top: calc(100% + 7px);
  transform: translateX(-50%);
  width: 240px;
  padding: 8px 10px;
  border-radius: 8px;
  background: #1f2937;
  color: #fff;
  font-family: 'Montserrat', sans-serif;
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.01em;
  line-height: 1.45;
  text-align: left;
  white-space: normal;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.18);
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s ease;
  z-index: 3200;
}
.summary-detail-note:hover::after {
  opacity: 1;
}
/* Opened toward the middle of the card, since these pills sit near its edge. */
.summary-detail-row .yoy-delta[data-yoy-tip]::after {
  left: auto;
  right: 0;
  transform: none;
}
.summary-detail-row .yoy-delta[data-yoy-tip]::before {
  left: auto;
  right: 14px;
  transform: none;
}
/* The KPI strip is five columns wide, so a bigger floor here would push the
   whole strip past the viewport on narrower windows. */
.summary-kpi .summary-detail {
  min-width: 236px;
}
.summary-kpi-strip {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 0;
  margin: 60px 20px 45px;
  padding: 30px 28px;
  border-radius: 16px;
  background: linear-gradient(180deg, #828d94 0%, #737e84 100%);
  color: #fff;
  text-align: center;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.08);
  align-items: start;
}
.summary-kpi {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 4px 20px;
  border-right: 1px solid rgba(255, 255, 255, 0.14);
}
.summary-kpi:last-child {
  border-right: 0;
}
.summary-kpi-label {
  margin-bottom: 8px;
  color: rgba(255, 255, 255, 0.82);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 1.4px;
  line-height: 1.35;
  text-transform: uppercase;
}
.summary-kpi-value,
.summary-kpi-click {
  border: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  padding: 0 !important;
  color: #ffffff !important;
  font-family: 'Montserrat', sans-serif;
  font-size: 30px;
  font-weight: 700;
  line-height: 1.05;
  letter-spacing: -0.4px;
  transition: opacity 0.15s ease;
}
.summary-kpi-click:hover {
  opacity: 0.82;
}
.summary-orders {
  margin: 30px 20px 0;
  padding: 45px 20px 35px;
  border-radius: 15px;
  background: #f0f0f0;
}
.summary-orders-row {
  display: grid;
  gap: 36px;
  margin-bottom: 60px;
}
.summary-orders-row.three {
  grid-template-columns: repeat(3, 1fr);
}
.summary-orders-row:last-child {
  margin-bottom: 0;
}
.summary-order {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  text-align: center;
}
.summary-order-value {
  border: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  padding: 0 !important;
  color: #333 !important;
  font-family: 'Montserrat', sans-serif;
  font-size: 50px;
  font-weight: 400;
  line-height: 1.05;
  text-align: center;
}
.summary-order-label {
  margin-top: 10px;
  color: #7b868c;
  font-size: 17px;
  font-weight: 700;
}
.pnl-page {
  width: 100%;
  max-width: none;
  padding: 0 0 28px;
}
.pnl-control-row {
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  align-items: stretch;
  gap: 10px;
  margin: 4px 0 16px;
  padding: 14px 16px;
  border: 1px solid rgba(76, 86, 92, 0.08);
  border-radius: 18px;
  background: rgba(255,255,255,0.32);
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.55);
}
.pnl-control-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
}
.pnl-control-row .date-toggle .checkbox,
.pnl-control-row .date-toggle .form-check {
  min-height: 36px;
  border-radius: 999px;
  background: #fff;
}
.pnl-preset-control {
  flex: 1 1 auto;
  min-width: 0;
}
.pnl-preset-control label,
.pnl-channel-picker > .shiny-input-container > label {
  display: block;
  margin: 0 0 8px;
  color: #6b7280;
  font-family: 'Montserrat', sans-serif;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.45px;
  line-height: 1;
  text-transform: uppercase;
}
.pnl-preset-control > .shiny-input-container {
  margin: 0;
}
.pnl-preset-control .shiny-options-group {
  display: inline-flex;
  gap: 3px;
  padding: 3px;
  border: 1px solid rgba(76, 86, 92, 0.10);
  border-radius: 999px;
  background: rgba(255,255,255,0.72);
  box-shadow: 0 6px 16px rgba(15, 23, 42, 0.05);
}
.pnl-preset-control .radio-inline,
.pnl-preset-control .form-check-inline,
.pnl-preset-control .radio,
.pnl-preset-control .form-check {
  position: relative;
  display: inline-flex;
  align-items: center;
  min-height: 30px;
  margin: 0;
  padding: 0 11px;
  border-radius: 999px;
  color: #51575c;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  white-space: nowrap;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}
.pnl-preset-control input[type="radio"],
.pnl-preset-control .form-check-input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}
.pnl-preset-control .form-check-label,
.pnl-preset-control .radio label,
.pnl-channel-picker .form-check-label,
.pnl-channel-picker .checkbox label {
  display: inline-flex;
  align-items: center;
  margin: 0;
  padding-left: 0 !important;
  line-height: 1;
  cursor: pointer;
}
.pnl-preset-control .radio-inline:has(input[type="radio"]:checked),
.pnl-preset-control .form-check-inline:has(.form-check-input:checked),
.pnl-preset-control .radio:has(input[type="radio"]:checked),
.pnl-preset-control .form-check:has(.form-check-input:checked) {
  background: #2f3840;
  color: #fff;
  box-shadow: 0 5px 12px rgba(15, 23, 42, 0.16);
}
.pnl-channel-picker {
  width: 100%;
  min-width: 0;
  padding: 10px 0 0;
  border-top: 1px solid rgba(76, 86, 92, 0.07);
  background: transparent;
}
.pnl-channel-picker > .shiny-input-container {
  margin: 0;
}
.pnl-channel-picker .shiny-options-group {
  display: flex;
  gap: 7px;
  flex-wrap: wrap;
}
.pnl-channel-picker .checkbox-inline,
.pnl-channel-picker .form-check-inline,
.pnl-channel-picker .checkbox,
.pnl-channel-picker .form-check {
  position: relative;
  display: inline-flex;
  align-items: center;
  min-height: 30px;
  margin: 0;
  padding: 7px 13px !important;
  border: 1px solid rgba(76, 86, 92, 0.10);
  border-radius: 999px;
  background: rgba(255,255,255,0.62);
  box-shadow: 0 3px 10px rgba(15, 23, 42, 0.035);
  color: #60676d;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  white-space: nowrap;
  transition: border-color 0.15s ease, background 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}
.pnl-channel-picker .checkbox-inline:hover,
.pnl-channel-picker .form-check-inline:hover,
.pnl-channel-picker .checkbox:hover,
.pnl-channel-picker .form-check:hover {
  border-color: rgba(52, 152, 219, 0.35);
  background: rgba(255,255,255,0.9);
}
.pnl-channel-picker input[type="checkbox"],
.pnl-channel-picker .form-check-input {
  position: absolute;
  left: 13px !important;
  top: 50%;
  width: 14px;
  height: 14px;
  margin: 0;
  transform: translateY(-50%);
  opacity: 0;
  pointer-events: none;
}
.pnl-channel-picker .checkbox-inline::before,
.pnl-channel-picker .form-check-inline::before,
.pnl-channel-picker .checkbox::before,
.pnl-channel-picker .form-check::before {
  display: none;
}
.pnl-channel-picker .checkbox-inline::after,
.pnl-channel-picker .form-check-inline::after,
.pnl-channel-picker .checkbox::after,
.pnl-channel-picker .form-check::after {
  display: none;
}
.pnl-channel-picker .checkbox-inline:has(input[type="checkbox"]:checked),
.pnl-channel-picker .form-check-inline:has(.form-check-input:checked),
.pnl-channel-picker .checkbox:has(input[type="checkbox"]:checked),
.pnl-channel-picker .form-check:has(.form-check-input:checked) {
  border-color: rgba(52, 152, 219, 0.28);
  background: rgba(52, 152, 219, 0.10);
  color: #2b6f9f;
  box-shadow: 0 5px 12px rgba(52, 152, 219, 0.08);
}
.pnl-channel-picker .checkbox-inline:has(input[type="checkbox"]:checked)::before,
.pnl-channel-picker .form-check-inline:has(.form-check-input:checked)::before,
.pnl-channel-picker .checkbox:has(input[type="checkbox"]:checked)::before,
.pnl-channel-picker .form-check:has(.form-check-input:checked)::before {
  border-color: #1f7fba;
  background: #1f7fba;
}
.pnl-channel-picker .checkbox-inline:has(input[type="checkbox"]:checked)::after,
.pnl-channel-picker .form-check-inline:has(.form-check-input:checked)::after,
.pnl-channel-picker .checkbox:has(input[type="checkbox"]:checked)::after,
.pnl-channel-picker .form-check:has(.form-check-input:checked)::after {
  opacity: 1;
}
.pnl-merge-toggle {
  align-self: flex-end;
  margin: 0;
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 10px;
}
.pnl-merge-toggle > .date-toggle {
  margin: 0;
}
.product-section {
  position: relative;
  margin: 20px 0;
  padding: 30px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.2);
  box-shadow: none;
}
.product-table-scroll {
  overflow-x: auto;
  overflow-y: visible;
  padding: 0 0 10px;
  scrollbar-width: thin;
  scrollbar-color: rgba(85, 98, 105, 0.35) rgba(255,255,255,0.35);
}
.product-table-scroll::-webkit-scrollbar {
  height: 8px;
}
.product-table-scroll::-webkit-scrollbar-track {
  border-radius: 999px;
  background: rgba(255,255,255,0.5);
}
.product-table-scroll::-webkit-scrollbar-thumb {
  border-radius: 999px;
  background: rgba(85, 98, 105, 0.28);
}
.product-header,
.product-row,
.product-total-row {
  display: grid;
  grid-template-columns: 132px minmax(230px, 1fr) var(--values-width);
  gap: 20px;
  align-items: center;
  min-width: calc(132px + 230px + var(--values-width) + 40px);
}
.product-header {
  grid-template-columns: minmax(330px, 1fr) var(--values-width);
  padding: 15px;
  min-width: calc(330px + var(--values-width) + 20px);
}
.product-title {
  font-size: 24px;
  font-weight: 700;
  line-height: 1.15;
}
.product-row {
  margin-top: 20px;
  padding: 15px;
  min-height: 110px;
  border: 0;
  border-radius: 15px;
  background: #fff;
  box-shadow: 0 0 10px rgba(0,0,0,0.05);
  transition: background 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}
.product-row.alt {
  background: #f3f3f3;
}
.product-image-cell {
  display: flex;
  width: 132px;
  height: 80px;
  align-items: center;
  justify-content: flex-start;
}
.product-image-wrap {
  position: relative;
  display: flex;
  width: 132px;
  height: 80px;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
}
.product-image-wrap.is-pro {
  border: 1px solid rgba(52, 152, 219, 0.22);
  background: linear-gradient(135deg, #ffffff 0%, #eef7ff 100%);
  box-shadow: 0 8px 18px rgba(52, 152, 219, 0.14);
}
.product-image-wrap.is-pro::after {
  position: absolute;
  inset: 0;
  border-radius: 12px;
  background: linear-gradient(120deg, rgba(255,255,255,0.55), rgba(255,255,255,0) 45%);
  content: "";
  pointer-events: none;
}
.product-img {
  width: auto;
  max-width: 132px;
  height: 80px;
  object-fit: contain;
  border-radius: 10px;
}
.product-image-wrap.is-pro .product-img {
  max-width: 118px;
  height: 72px;
}
.product-image-wrap.is-nature-cam .product-img {
  max-width: 122px;
  height: 76px;
}
.product-badge {
  position: absolute;
  top: 5px;
  right: 5px;
  z-index: 1;
  padding: 2px 6px;
  border-radius: 999px;
  background: #111;
  color: #fff;
  box-shadow: 0 2px 6px rgba(0,0,0,0.18);
  font-size: 9px;
  font-weight: 800;
  line-height: 1.2;
  letter-spacing: 0;
}
.product-name {
  color: #111;
  font-size: 16px;
  font-weight: 700;
  line-height: 1.15;
}
.product-sku {
  color: #888;
  font-size: 10px;
  line-height: 1.2;
  margin-top: 4px;
}
.product-values {
  display: grid;
  grid-template-columns: var(--values-columns);
  width: var(--values-width);
  align-items: center;
  text-align: center;
  gap: 0;
}
.product-channel {
  color: #555;
  font-size: 14px;
  font-weight: 700;
  line-height: 1.15;
}
.product-channel.all-channel {
  font-size: 10px;
  font-weight: 500;
}
.product-number {
  font-size: 16px;
  font-weight: 400;
  line-height: 1.2;
}
.product-number-wrap,
.product-total-number-wrap {
  display: inline-flex;
  min-width: 0;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
}
.product-value-cell,
.product-total-cell,
.product-channel {
  position: relative;
  border-radius: 9px;
  transition: color 0.15s ease;
}
.product-value-cell:hover,
.product-total-cell:hover {
  color: #216b9b;
}
.pnl-hover-tip {
  position: fixed;
  z-index: 3000;
  display: none;
  min-width: 190px;
  max-width: 300px;
  padding: 10px 12px;
  border: 1px solid rgba(76, 86, 92, 0.12);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.94);
  box-shadow: 0 12px 26px rgba(15, 23, 42, 0.13);
  backdrop-filter: blur(10px);
  color: #2f3438;
  font-family: 'Montserrat', sans-serif;
  pointer-events: none;
}
.pnl-hover-tip.is-visible {
  display: block;
}
.pnl-hover-tip-title {
  margin-bottom: 6px;
  color: #111;
  font-size: 12px;
  font-weight: 800;
  line-height: 1.25;
}
.pnl-hover-tip-meta {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 4px 9px;
  font-size: 11px;
  line-height: 1.3;
}
.pnl-hover-tip-label {
  color: #7b868c;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.35px;
}
.pnl-hover-tip-value {
  color: #2f3438;
  font-weight: 700;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.product-number-wrap .yoy-delta,
.product-total-number-wrap .yoy-delta {
  margin-top: 0;
  padding: 2px 6px;
  border: 1px solid rgba(0,0,0,0.04);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
  font-size: 9px;
  line-height: 1;
  transform: translateY(1px);
}
.product-number-wrap .yoy-good,
.product-total-number-wrap .yoy-good {
  background: rgba(46, 204, 113, 0.10);
  color: #1f9d59;
}
.product-number-wrap .yoy-bad,
.product-total-number-wrap .yoy-bad {
  background: rgba(165, 42, 42, 0.09);
  color: #a52a2a;
}
.product-number-wrap .yoy-flat,
.product-total-number-wrap .yoy-flat {
  background: rgba(127, 140, 141, 0.10);
  color: #7b868c;
}
.product-number.all-channel {
  color: #727272;
  font-size: 18px;
  font-weight: 700;
}
.product-total-row {
  grid-template-columns: minmax(330px, 1fr) var(--values-width);
  margin-top: 0;
  padding: 15px;
  border: 0;
  min-width: calc(330px + var(--values-width) + 20px);
}
.product-total-cell {
  text-align: center;
}
.product-total-label {
  color: #555;
  font-size: 10px;
  font-weight: 500;
  line-height: 1.2;
}
.product-total-number {
  font-weight: 700;
  color: #555;
  font-size: 18px;
  line-height: 1.2;
  margin-top: 2px;
}
.product-total-number.all-channel {
  color: #000;
}
.survey-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(360px, 1fr));
  gap: 18px;
  margin: 0 0 22px;
  align-items: stretch;
}
.survey-card {
  display: flex;
  flex-direction: column;
  min-height: 430px;
  padding: 18px 20px 14px;
  overflow: hidden;
}
.survey-card h3,
.survey-wide-card h3 {
  font-family: 'Montserrat', sans-serif;
  font-size: 16px;
  font-weight: 700;
  margin: 0;
  color: var(--gray);
  line-height: 1.25;
}
.survey-card-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  min-height: 42px;
  margin-bottom: 2px;
}
.survey-chart-frame {
  position: relative;
  display: flex;
  flex: 1 1 auto;
  width: 100%;
  min-height: 360px;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}
.survey-chart-frame.wide {
  min-height: 520px;
}
.survey-chart-frame .chart-export {
  right: 8px;
  bottom: 8px;
}
.survey-action {
  border: 0 !important;
  background: transparent !important;
  color: #333 !important;
  box-shadow: none !important;
  padding: 2px 0 !important;
  font-family: 'Montserrat', sans-serif;
  font-size: 14px;
  line-height: 1.2;
  white-space: nowrap;
}
.survey-card .shiny-ipywidget-output,
.survey-wide-card .shiny-ipywidget-output {
  display: block;
  width: 100% !important;
  max-width: 100% !important;
  min-width: 0 !important;
}
.survey-card .shiny-ipywidget-output {
  flex: 0 0 auto;
  width: 360px !important;
  height: 360px !important;
}
.survey-card .jupyter-widgets,
.survey-card .widget-output,
.survey-card .widget-subarea,
.survey-card .output,
.survey-card .output_area,
.survey-card .output_html,
.survey-card .plotly,
.survey-card .js-plotly-plot,
.survey-card .plot-container,
.survey-card .svg-container,
.survey-card .main-svg,
.survey-card .modebar-container,
.survey-wide-card .jupyter-widgets,
.survey-wide-card .widget-output,
.survey-wide-card .widget-subarea,
.survey-wide-card .output,
.survey-wide-card .output_area,
.survey-wide-card .output_html,
.survey-wide-card .plotly,
.survey-wide-card .js-plotly-plot,
.survey-wide-card .plot-container,
.survey-wide-card .svg-container,
.survey-wide-card .main-svg,
.survey-wide-card .modebar-container {
  width: 100% !important;
  max-width: 100% !important;
}
.survey-card .modebar,
.survey-wide-card .modebar {
  display: none !important;
}
.survey-wide-card {
  margin: 0 0 22px;
  padding: 20px;
  background: #fff;
  border-radius: 20px;
  box-shadow: 0 0 10px rgba(0,0,0,.05);
}
.survey-empty-state {
  margin: 0 0 22px;
  padding: 24px 28px;
  background: #fff;
  border-radius: 20px;
  box-shadow: 0 0 10px rgba(0,0,0,.05);
  color: #69747a;
  font-size: 16px;
}
.survey-empty-copy {
  padding: 24px 0 8px;
  text-align: center;
}
@media (max-width: 1100px) {
  .survey-grid {
    grid-template-columns: repeat(2, minmax(340px, 1fr));
  }
}
@media (max-width: 760px) {
  .survey-grid {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 900px) {
  .app-topbar {
    margin-left: 0;
    min-height: auto;
  }
  .nav-tabs,
  ul.nav.nav-tabs {
    position: static;
    width: 100%;
    padding: 0;
  }
  .tab-content {
    margin-left: 0;
  }
  .section-head {
    align-items: stretch;
    flex-direction: column;
  }
  .date-tools,
  .control-row {
    justify-content: flex-start;
  }
  .pnl-control-row {
    padding: 10px;
  }
  .pnl-channel-picker {
    flex-basis: 100%;
    min-width: 0;
  }
  .pnl-preset-control .shiny-options-group {
    flex-wrap: wrap;
    border-radius: 14px;
  }
  .product-header,
  .product-row,
  .product-total-row {
    grid-template-columns: 56px 1fr;
  }
  .product-values {
    grid-column: 1 / -1;
    grid-auto-flow: row;
    grid-template-columns: repeat(3, 1fr);
    width: 100%;
  }
  .product-header,
  .product-total-row {
    grid-template-columns: 1fr;
  }
}
"""


PLOT_RESIZE_JS = """
(function() {
  let pending = false;
  function resizeCharts() {
    document.querySelectorAll(".chart-card .js-plotly-plot").forEach(function(plot) {
      if (window.Plotly && window.Plotly.Plots) {
        window.Plotly.Plots.resize(plot);
      }
    });
  }
  function scheduleResize() {
    if (pending) return;
    pending = true;
    window.requestAnimationFrame(function() {
      pending = false;
      resizeCharts();
      window.setTimeout(resizeCharts, 120);
    });
  }
  window.addEventListener("resize", scheduleResize);
  document.addEventListener("shown.bs.tab", scheduleResize);
  document.addEventListener("shiny:bound", scheduleResize);
  document.addEventListener("shiny:value", scheduleResize);
  document.addEventListener("DOMContentLoaded", function() {
    scheduleResize();
    new MutationObserver(scheduleResize).observe(document.body, { childList: true, subtree: true });
  });
})();
"""


PNL_HOVER_JS = """
(function() {
  function ensureTip() {
    var tip = document.querySelector(".pnl-hover-tip");
    if (tip) return tip;
    tip = document.createElement("div");
    tip.className = "pnl-hover-tip";
    document.body.appendChild(tip);
    return tip;
  }

  function escapeText(value) {
    return String(value || "").replace(/[&<>"']/g, function(ch) {
      if (ch === "&") return "&amp;";
      if (ch === "<") return "&lt;";
      if (ch === ">") return "&gt;";
      if (ch === '"') return "&quot;";
      return "&#39;";
    });
  }

  function positionTip(tip, event) {
    var gap = 14;
    var left = event.clientX + gap;
    var top = event.clientY + gap;
    var rect = tip.getBoundingClientRect();
    if (left + rect.width > window.innerWidth - 10) left = event.clientX - rect.width - gap;
    if (top + rect.height > window.innerHeight - 10) top = event.clientY - rect.height - gap;
    tip.style.left = Math.max(10, left) + "px";
    tip.style.top = Math.max(10, top) + "px";
  }

  function showTip(cell, event) {
    var product = cell.getAttribute("data-product") || "";
    var channel = cell.getAttribute("data-channel-label") || "";
    var value = cell.getAttribute("data-value") || "";
    var tip = ensureTip();
    tip.innerHTML =
      '<div class="pnl-hover-tip-title">' + escapeText(product) + '</div>' +
      '<div class="pnl-hover-tip-meta">' +
        '<span class="pnl-hover-tip-label">Channel</span><span class="pnl-hover-tip-value">' + escapeText(channel) + '</span>' +
        '<span class="pnl-hover-tip-label">Value</span><span class="pnl-hover-tip-value">' + escapeText(value) + '</span>' +
      '</div>';
    tip.classList.add("is-visible");
    positionTip(tip, event);
  }

  function hideTip() {
    var tip = document.querySelector(".pnl-hover-tip");
    if (tip) tip.classList.remove("is-visible");
  }

  // The change pills carry their own tooltip, so stand down rather than stack
  // two popups on top of each other.
  function onOwnTooltip(event) {
    var target = event.target;
    return !!(target && target.closest && target.closest("[data-yoy-tip]"));
  }

  document.addEventListener("mouseover", function(event) {
    var cell = event.target.closest(".product-value-cell, .product-total-cell");
    if (!cell) return;
    if (onOwnTooltip(event)) {
      hideTip();
      return;
    }
    showTip(cell, event);
  });

  document.addEventListener("mousemove", function(event) {
    var cell = event.target.closest(".product-value-cell, .product-total-cell");
    if (!cell) return;
    if (onOwnTooltip(event)) {
      hideTip();
      return;
    }
    var tip = ensureTip();
    if (tip.classList.contains("is-visible")) positionTip(tip, event);
  });

  document.addEventListener("mouseout", function(event) {
    var next = event.relatedTarget;
    if (next && next.closest(".product-value-cell, .product-total-cell")) return;
    hideTip();
  });
})();
"""


DATE_PICKER_JS = f"""
(function() {{
  var DATA_MIN = "{DATE_MIN.isoformat()}";
  var DATA_MAX = "{DATE_MAX.isoformat()}";
  var initialized = false;

  function fmt(m) {{ return m.format("MMM D, YYYY"); }}
  function iso(m) {{ return m.format("YYYY-MM-DD"); }}
  function clampedRange(start, end, min, max) {{
    return [moment.max(start, min), moment.min(end, max)];
  }}

  function init() {{
    if (initialized) return;
    if (typeof jQuery === "undefined" || typeof jQuery.fn.daterangepicker === "undefined") return;
    var $ = jQuery;
    var $trigger = $("#date_range_trigger");
    if (!$trigger.length) return;
    initialized = true;

    var dataMin = moment(DATA_MIN);
    var dataMax = moment(DATA_MAX);
    // Presets use the calendar, not the last recorded day. When the file lags,
    // "Today" is omitted and "Yesterday" is the prior calendar day if it is in range.
    var today = moment().startOf("day");
    var yesterday = today.clone().subtract(1, "days");
    var y = today.year();

    var ranges = {{}};
    if (!today.isBefore(dataMin) && !today.isAfter(dataMax)) {{
      ranges["Today"] = [today, today];
    }}
    if (!yesterday.isBefore(dataMin) && !yesterday.isAfter(dataMax)) {{
      ranges["Yesterday"] = [yesterday, yesterday];
    }}
    ranges["Last 7 Days"] = clampedRange(today.clone().subtract(6,"days"), today, dataMin, dataMax);
    ranges["Last 30 Days"] = clampedRange(today.clone().subtract(29,"days"), today, dataMin, dataMax);
    ranges["Last 90 Days"] = clampedRange(today.clone().subtract(89,"days"), today, dataMin, dataMax);
    ranges["This Month"] = clampedRange(today.clone().startOf("month"), today, dataMin, dataMax);
    ranges["Last Month"] = clampedRange(
      today.clone().subtract(1,"month").startOf("month"),
      today.clone().subtract(1,"month").endOf("month"),
      dataMin, dataMax
    );
    ranges["Year to Date"] = clampedRange(moment(y+"-01-01"), today, dataMin, dataMax);
    ranges["This Year (" + y + ")"] = clampedRange(moment(y+"-01-01"), moment(y+"-12-31"), dataMin, dataMax);
    ranges["Last Year (" + (y-1) + ")"] = clampedRange(moment((y-1)+"-01-01"), moment((y-1)+"-12-31"), dataMin, dataMax);
    ranges["H1 2025"] = clampedRange(moment("2025-01-01"), moment("2025-06-30"), dataMin, dataMax);
    ranges["H1 2026"] = clampedRange(moment("2026-01-01"), moment("2026-06-30"), dataMin, dataMax);
    ranges["Last 12 Months"] = clampedRange(today.clone().subtract(1,"year").add(1,"day"), today, dataMin, dataMax);
    ranges["All Time"] = [dataMin, dataMax];

    // Read initial value from the hidden input
    var $hidden = $("#selected_date_range_iso");
    var raw = ($hidden.val() || "").split("/");
    var startInit = raw.length === 2 ? moment(raw[0]) : dataMin;
    var endInit = raw.length === 2 ? moment(raw[1]) : dataMax;
    if (!startInit.isValid()) startInit = dataMin;
    if (!endInit.isValid()) endInit = dataMax;

    $trigger.val(fmt(startInit) + " – " + fmt(endInit));

    $trigger.daterangepicker({{
      startDate: startInit,
      endDate: endInit,
      minDate: dataMin,
      maxDate: dataMax,
      ranges: ranges,
      showDropdowns: true,
      linkedCalendars: false,
      alwaysShowCalendars: true,
      opens: "left",
      autoUpdateInput: false,
      locale: {{
        format: "MMM D, YYYY",
        firstDay: 1,
        applyLabel: "Apply",
        cancelLabel: "Cancel",
        customRangeLabel: "Custom Range"
      }}
    }});

    $trigger.on("apply.daterangepicker", function(ev, picker) {{
      $trigger.val(fmt(picker.startDate) + " – " + fmt(picker.endDate));
      if (window.Shiny && Shiny.setInputValue) {{
        Shiny.setInputValue("selected_date_range_iso", iso(picker.startDate) + "/" + iso(picker.endDate), {{priority: "event"}});
      }}
    }});

    function clampPopup() {{
      var $c = $(".daterangepicker").filter(":visible").last();
      if (!$c.length) return;
      var margin = 12;
      var vw = window.innerWidth;
      var vh = window.innerHeight;
      var r = $c[0].getBoundingClientRect();
      var curLeft = parseFloat($c.css("left")) || 0;
      var curTop = parseFloat($c.css("top")) || 0;
      var newLeft = curLeft;
      var newTop = curTop;
      if (r.right > vw - margin) newLeft = curLeft - (r.right - (vw - margin));
      if (newLeft < margin) newLeft = margin;
      if (r.bottom > vh - margin) newTop = curTop - (r.bottom - (vh - margin));
      if (newTop < margin) newTop = margin;
      $c.css({{left: newLeft + "px", top: newTop + "px", right: "auto"}});
    }}

    $trigger.on("show.daterangepicker showCalendar.daterangepicker", function() {{
      setTimeout(clampPopup, 0);
      setTimeout(clampPopup, 30);
    }});
    $(window).on("resize.daterangepickerClamp", function() {{ clampPopup(); }});
  }}

  function tryInit() {{
    if (initialized) return;
    init();
    if (!initialized) setTimeout(tryInit, 60);
  }}

  document.addEventListener("DOMContentLoaded", tryInit);
  document.addEventListener("shiny:sessioninitialized", tryInit);
  tryInit();
}})();
"""


app_ui = ui.page_fluid(
    ui.tags.head(
        ui.tags.link(rel="stylesheet", href="https://cdn.jsdelivr.net/npm/daterangepicker/daterangepicker.css"),
        ui.tags.script(src="https://cdn.jsdelivr.net/momentjs/latest/moment.min.js"),
        ui.tags.script(src="https://cdn.jsdelivr.net/npm/daterangepicker/daterangepicker.min.js"),
        ui.tags.style(CSS),
        ui.tags.script(PLOT_RESIZE_JS),
        ui.tags.script(PNL_HOVER_JS),
        ui.tags.script(DATE_PICKER_JS),
    ),
    ui.div(
        ui.div("Bird Buddy Dashboard", class_="app-title"),
        ui.div(
            ui.div(clean_select("dtc_region", "DTC view:", DTC_REGION_CHOICES, selected="all", width="100%"), class_="dtc-view-control"),
            ui.div(clean_select("amazon_region", "Amazon view:", AMAZON_REGION_CHOICES, selected="all", width="100%"), class_="amazon-view-control"),
            class_="top-left-tools",
        ),
        ui.div(
            ui.div(
                ui.div("Select date range", class_="date-picker-label"),
                ui.tags.input(
                    type="text",
                    id="date_range_trigger",
                    class_="date-range-trigger",
                    readonly=True,
                    autocomplete="off",
                ),
                ui.tags.div(
                    ui.input_text("selected_date_range_iso", None, value=f"{DEFAULT_DATE_START}/{DEFAULT_DATE_END}"),
                    class_="date-iso-hidden",
                ),
                class_="date-picker-wrap",
            ),
            ui.div(
                ui.div(
                    ui.input_checkbox("viz_by_month", "By month", spans_more_than_two_months((DEFAULT_DATE_START, DEFAULT_DATE_END))),
                    class_="date-toggle",
                ),
                ui.div(
                    ui.input_checkbox("comparison_mode", "Compare vs prior year", True),
                    class_="date-toggle",
                ),
                ui.div(
                    ui.input_checkbox("exclude_renewals", "Excl. renewals", False),
                    class_="date-toggle",
                    **{"data-toggle-tip": RENEWALS_HINT},
                ),
                class_="date-toggles",
            ),
            class_="date-tools",
        ),
        class_="app-topbar",
    ),
    ui.navset_tab(
        ui.nav_panel(
            menu_title(ICON_CHART_LINE, "Summary"),
            ui.output_ui("campaign_notes"),
            ui.output_ui("summary_cards"),
        ),
        ui.nav_panel(
            menu_title(ICON_CHART_BAR, "Visualization"),
            section(
                '<span style="color:#2ecc71;">Revenue</span> vs <span style="color:#A52A2A;">Spend</span> Over Time',
                "revenue_vs_spend_plot",
                clean_select("selected_view_mode", None, ["Absolute", "Relative"], selected="Absolute", width="150px"),
                clean_select(
                    "selected_revenue_spend_type",
                    None,
                    REVENUE_SPEND_CHOICES,
                    selected="Total",
                    width="220px",
                ),
            ),
            section(
                '<span style="color:#2ecc71;">ROAS</span> per Day',
                "blended_roas_bar_chart",
                clean_select(
                    "selected_roas_type",
                    None,
                    {
                        "Blended_ROAS": "Blended ROAS",
                        "wROAS": "DTC ROAS",
                        "aROAS": "Amazon ROAS",
                        "appROAS": "App ROAS",
                    },
                    selected="Blended_ROAS",
                    width="230px",
                ),
            ),
            section(
                '<span style="color:#A52A2A;">Spend per Unit</span> per Day',
                "blended_SPU_bar_chart",
                clean_select(
                    "selected_SPU_type",
                    None,
                    {
                        "Blended_SPU": "Blended SPU",
                        "wSPU": "DTC SPU",
                        "aSPU": "Amazon SPU",
                        "appSPU": "App SPU",
                    },
                    selected="Blended_SPU",
                    width="230px",
                ),
            ),
            section('<span style="color:#7b868c;">Conversion Rate</span> per Day', "cr_bar_chart"),
            section(
                '<span style="color:#3498db;">AOV</span> per Day',
                "aov_bar_chart",
                clean_select(
                    "selected_aov_type",
                    None,
                    {"Web_AOV": "Web AOV", "Segmented_AOV": "Customer Segments AOV"},
                    selected="Web_AOV",
                    width="260px",
                ),
            ),
            section(
                '<span style="color:#2ecc71;">Returning</span> vs <span style="color:#3498db;">First-Time</span> Customers',
                "customer_split_chart",
            ),
            section(
                "Revenue Composition Over Time",
                "revenue_share_chart",
                ui.input_checkbox("revenue_share_include_retail", "Include Retail", False),
                ui.input_checkbox("revenue_share_include_app", "Include App", False),
                clean_select("selected_revenue_view_mode", None, ["Relative", "Absolute"], selected="Relative", width="200px"),
            ),
            section(
                "Spend Composition Over Time",
                "spend_composition_chart",
                ui.input_checkbox("spend_composition_include_retail", "Include Retail", True),
                ui.input_checkbox("spend_composition_include_app", "Include App", True),
                clean_select("selected_spend_view_mode", None, ["Relative", "Absolute"], selected="Relative", width="200px"),
                clean_select(
                    "selected_spend_composition",
                    None,
                    {"Total": "Total Spend", "DTC": "DTC Spend"},
                    selected="Total",
                    width="250px",
                ),
            ),
        ),
        ui.nav_panel(menu_title(ICON_DOLLAR, "P&L"), merged_control(), ui.output_ui("pnl_view")),
        ui.nav_panel(
            menu_title(ICON_PIE, "P&L Visualizations"),
            section(
                '<span style="color:#2ecc71;">Units</span>, <span style="color:#3498db;">Add-ons</span> and <span style="color:#f39c12;">Seeds</span> by Channel',
                "units_ua_plot",
                ui.panel_conditional(
                    "input.units_ua_view == 'Absolute'",
                    ui.input_checkbox("units_line_view", "Line chart view", False),
                    class_="inline-conditional",
                ),
                ui.input_checkbox("units_include_seeds", "Include Seeds", True),
                clean_select(
                    "units_ua_channel",
                    None,
                    PNL_VIS_CHANNEL_CHOICES,
                    selected="All",
                    width="220px",
                ),
                clean_select("units_ua_view", None, ["Absolute", "Relative"], selected="Absolute", width="150px"),
                height=800,
            ),
            section(
                "Unit Count by Channel",
                "sku_plot",
                ui.panel_conditional(
                    "input.sku_view == 'Absolute'",
                    ui.input_checkbox("sku_line_view", "Line chart view", False),
                    class_="inline-conditional",
                ),
                ui.input_checkbox("by_type", "By Type", True),
                ui.input_checkbox("by_type_colour", "By Type and Colour", False),
                clean_select(
                    "sku_channel",
                    None,
                    PNL_VIS_CHANNEL_CHOICES,
                    selected="All",
                    width="220px",
                ),
                clean_select("sku_view", None, ["Absolute", "Relative"], selected="Absolute", width="120px"),
                height=800,
                sku_export=True,
            ),
            section(
                "Add-on Count by Channel",
                "addon_plot",
                ui.panel_conditional(
                    "input.addon_view == 'Absolute'",
                    ui.input_checkbox("addon_line_view", "Line chart view", False),
                    class_="inline-conditional",
                ),
                ui.input_checkbox("by_colour_addon", "By Colour", False),
                clean_select(
                    "addon_channel",
                    None,
                    PNL_ADDON_VIS_CHANNEL_CHOICES,
                    selected="All",
                    width="220px",
                ),
                clean_select("addon_view", None, ["Absolute", "Relative"], selected="Absolute", width="120px"),
                height=800,
                sku_export=True,
            ),
            section(
                "Seed Count by Type",
                "seed_plot",
                ui.input_checkbox("seed_by_weight", "By Weight", False),
                ui.panel_conditional(
                    "input.seed_view_mode == 'Absolute'",
                    ui.input_checkbox("seed_line_view", "Line chart view", False),
                    class_="inline-conditional",
                ),
                clean_select("seed_view_mode", None, ["Absolute", "Relative"], selected="Absolute", width="120px"),
                height=700,
                sku_export=True,
            ),
            section(
                "App Subscription by Channel",
                "app_subs_by_channel_plot",
                ui.panel_conditional(
                    "input.appsubs_view == 'Absolute'",
                    ui.input_checkbox("appsubs_line_view", "Line chart view", False),
                    class_="inline-conditional",
                ),
                clean_select(
                    "appsubs_channel",
                    None,
                    {"All": "All", "DTC": "DTC", "Apple": "Apple", "Google": "Google"},
                    selected="All",
                    width="180px",
                ),
                clean_select("appsubs_view", None, ["Absolute", "Relative"], selected="Absolute", width="150px"),
                height=520,
            ),
        ),
        ui.nav_panel(
            menu_title(ICON_CLIPBOARD, "Post Purchase Survey"),
            ui.div(
                ui.div(
                    ui.h2(ui.output_text("overview_title"), class_="section-title"),
                    ui.div(
                        ui.input_checkbox("survey_line_view", "Line chart view", False),
                        clean_select(
                            "survey_segment",
                            None,
                            {"all": "All Customers", "new": "New Customers", "ret": "Returning Customers"},
                            selected="all",
                            width="240px",
                        ),
                        class_="control-row",
                    ),
                    class_="section-head",
                ),
                ui.output_ui("survey_layout"),
                ui.output_ui("survey_timeline_sections"),
                class_="app-section",
            ),
        ),
        id="tabs",
    ),
)


def server(input: Inputs, output: Outputs, session: Session):
    survey_view_state = reactive.Value("All")
    notes_visible = reactive.Value(False)
    summary_expanded = reactive.Value(frozenset())

    def toggle_summary(key: str):
        current = set(summary_expanded.get())
        if key in current:
            current.remove(key)
        else:
            current.add(key)
        summary_expanded.set(frozenset(current))

    def pnl_mode() -> str:
        """Which product line-up the P&L is showing."""
        if bool(input.pnl_merge_families()):
            return "families"
        if bool(input.pnl_merge_products()):
            return "merged"
        return "raw"

    # The two merges are different groupings of the same units, so ticking one releases
    # the other rather than leaving the page to guess which was meant.
    @reactive.effect
    @reactive.event(input.pnl_merge_products, ignore_init=True)
    def _merge_products_wins():
        if bool(input.pnl_merge_products()) and bool(input.pnl_merge_families()):
            ui.update_checkbox("pnl_merge_families", value=False)

    @reactive.effect
    @reactive.event(input.pnl_merge_families, ignore_init=True)
    def _merge_families_wins():
        if bool(input.pnl_merge_families()) and bool(input.pnl_merge_products()):
            ui.update_checkbox("pnl_merge_products", value=False)

    @reactive.effect
    @reactive.event(input.toggle_notes, ignore_init=True)
    def _toggle_notes():
        notes_visible.set(not notes_visible.get())

    @reactive.effect
    @reactive.event(input.toggle_dtc_revenue, ignore_init=True)
    def _toggle_dtc_revenue():
        toggle_summary("dtc_revenue")

    @reactive.effect
    @reactive.event(input.toggle_amazon_revenue, ignore_init=True)
    def _toggle_amazon_revenue():
        toggle_summary("amazon_revenue")

    @reactive.effect
    @reactive.event(input.toggle_indiegogo_revenue, ignore_init=True)
    def _toggle_indiegogo_revenue():
        toggle_summary("indiegogo_revenue")

    @reactive.effect
    @reactive.event(input.toggle_digital_marketplaces, ignore_init=True)
    def _toggle_digital_marketplaces():
        toggle_summary("digital_marketplaces")

    @reactive.effect
    @reactive.event(input.toggle_b2b_revenue, ignore_init=True)
    def _toggle_b2b_revenue():
        toggle_summary("b2b_revenue")

    @reactive.effect
    @reactive.event(input.toggle_app_revenue, ignore_init=True)
    def _toggle_app_revenue():
        toggle_summary("app_revenue")

    @reactive.effect
    @reactive.event(input.toggle_dtc_spend, ignore_init=True)
    def _toggle_dtc_spend():
        toggle_summary("dtc_spend")

    @reactive.effect
    @reactive.event(input.toggle_amazon_spend, ignore_init=True)
    def _toggle_amazon_spend():
        toggle_summary("amazon_spend")

    @reactive.effect
    @reactive.event(input.toggle_fees, ignore_init=True)
    def _toggle_fees():
        toggle_summary("fees")

    @reactive.effect
    @reactive.event(input.toggle_retail_spend, ignore_init=True)
    def _toggle_retail_spend():
        toggle_summary("retail_spend")

    @reactive.effect
    @reactive.event(input.toggle_app_spend, ignore_init=True)
    def _toggle_app_spend():
        toggle_summary("app_spend")

    @reactive.effect
    @reactive.event(input.toggle_blended_roas, ignore_init=True)
    def _toggle_blended_roas():
        toggle_summary("blended_roas")

    @reactive.effect
    @reactive.event(input.toggle_blended_spu, ignore_init=True)
    def _toggle_blended_spu():
        toggle_summary("blended_spu")

    @reactive.effect
    @reactive.event(input.toggle_web_aov, ignore_init=True)
    def _toggle_web_aov():
        toggle_summary("web_aov")

    @reactive.effect
    @reactive.event(input.toggle_returning_customers, ignore_init=True)
    def _toggle_returning_customers():
        toggle_summary("returning_customers")

    @reactive.effect
    @reactive.event(input.toggle_dtc_orders, ignore_init=True)
    def _toggle_dtc_orders():
        toggle_summary("dtc_orders")

    @reactive.effect
    @reactive.event(input.toggle_amazon_orders, ignore_init=True)
    def _toggle_amazon_orders():
        toggle_summary("amazon_orders")

    @reactive.effect
    @reactive.event(input.toggle_digital_marketplaces_orders, ignore_init=True)
    def _toggle_digital_marketplaces_orders():
        toggle_summary("digital_marketplaces_orders")

    @reactive.effect
    @reactive.event(input.toggle_b2b_orders, ignore_init=True)
    def _toggle_b2b_orders():
        toggle_summary("b2b_orders")

    @reactive.effect
    @reactive.event(input.toggle_app_orders, ignore_init=True)
    def _toggle_app_orders():
        toggle_summary("app_orders")

    @reactive.effect
    @reactive.event(input.expand_q1, ignore_init=True)
    def _expand_q1():
        survey_view_state.set("Q1")

    @reactive.effect
    @reactive.event(input.expand_q2, ignore_init=True)
    def _expand_q2():
        survey_view_state.set("Q2")

    @reactive.effect
    @reactive.event(input.expand_q3, ignore_init=True)
    def _expand_q3():
        survey_view_state.set("Q3")

    @reactive.effect
    @reactive.event(input.expand_q4, ignore_init=True)
    def _expand_q4():
        survey_view_state.set("Q4")

    @reactive.effect
    @reactive.event(input.expand_q5, ignore_init=True)
    def _expand_q5():
        survey_view_state.set("Q5")

    @reactive.effect
    @reactive.event(input.expand_q6, ignore_init=True)
    def _expand_q6():
        survey_view_state.set("Q6")

    @reactive.effect
    @reactive.event(input.expand_q7, ignore_init=True)
    def _expand_q7():
        survey_view_state.set("Q7")

    @reactive.effect
    @reactive.event(input.expand_q8, ignore_init=True)
    def _expand_q8():
        survey_view_state.set("Q8")

    @reactive.effect
    @reactive.event(input.expand_q9, ignore_init=True)
    def _expand_q9():
        survey_view_state.set("Q9")

    @reactive.effect
    @reactive.event(input.expand_q10, ignore_init=True)
    def _expand_q10():
        survey_view_state.set("Q10")

    @reactive.effect
    @reactive.event(input.expand_q11, ignore_init=True)
    def _expand_q11():
        survey_view_state.set("Q11")

    @reactive.effect
    @reactive.event(input.expand_q12, ignore_init=True)
    def _expand_q12():
        survey_view_state.set("Q12")

    @reactive.effect
    @reactive.event(input.expand_q13, ignore_init=True)
    def _expand_q13():
        survey_view_state.set("Q13")

    @reactive.effect
    @reactive.event(input.expand_q14, ignore_init=True)
    def _expand_q14():
        survey_view_state.set("Q14")

    @reactive.effect
    @reactive.event(input.expand_q15, ignore_init=True)
    def _expand_q15():
        survey_view_state.set("Q15")

    @reactive.effect
    @reactive.event(input.back_all, ignore_init=True)
    def _back_all():
        survey_view_state.set("All")

    @reactive.effect
    @reactive.event(input.selected_date_range_iso, ignore_init=True)
    def _default_monthly_for_long_ranges():
        ui.update_checkbox("viz_by_month", value=spans_more_than_two_months(selected_range()), session=session)

    @reactive.effect
    @reactive.event(input.pnl_channel_preset, ignore_init=True)
    def _apply_pnl_channel_preset():
        preset = input.pnl_channel_preset()
        if preset == "custom":
            return
        selected = PNL_CHANNEL_PRESETS.get(preset, PNL_CHANNEL_PRESETS["all"])[1]
        ui.update_checkbox_group("pnl_channels", selected=selected, session=session)

    @reactive.effect
    @reactive.event(input.pnl_channels, ignore_init=True)
    def _sync_pnl_channel_preset():
        selected = input.pnl_channels() or []
        if isinstance(selected, str):
            selected = [selected]
        selected_set = set(selected)
        preset = "custom"
        for key, (_, channels) in PNL_CHANNEL_PRESETS.items():
            if key != "custom" and set(channels) == selected_set:
                preset = key
                break
        if input.pnl_channel_preset() != preset:
            ui.update_radio_buttons("pnl_channel_preset", selected=preset, session=session)

    @reactive.effect
    @reactive.event(input.by_type, ignore_init=True)
    def _by_type_only():
        if input.by_type():
            ui.update_checkbox("by_type_colour", value=False, session=session)

    @reactive.effect
    @reactive.event(input.by_type_colour, ignore_init=True)
    def _by_type_colour_only():
        if input.by_type_colour():
            ui.update_checkbox("by_type", value=False, session=session)

    @reactive.calc
    def selected_range() -> Tuple[pd.Timestamp, pd.Timestamp]:
        raw = (input.selected_date_range_iso() or "").strip()
        parts = raw.split("/") if raw else []
        if len(parts) == 2:
            try:
                start = pd.Timestamp(parts[0])
                end = pd.Timestamp(parts[1])
                if pd.notna(start) and pd.notna(end):
                    if start > end:
                        start, end = end, start
                    return start, end
            except Exception:
                pass
        return pd.Timestamp(DEFAULT_DATE_START), pd.Timestamp(DEFAULT_DATE_END)

    @reactive.calc
    def revenue_filtered() -> pd.DataFrame:
        start, end = selected_range()
        return revenue_data[(revenue_data["Date"] >= start) & (revenue_data["Date"] <= end)].copy()

    @reactive.calc
    def revenue_view_filtered() -> pd.DataFrame:
        df = apply_renewals_exclusion(revenue_filtered(), bool(input.exclude_renewals()))
        return apply_amazon_region(apply_dtc_region(df, input.dtc_region()), input.amazon_region())

    @reactive.calc
    def revenue_prev_year_view() -> pd.DataFrame:
        start, end = selected_range()
        prev_start, prev_end = prev_year_window(start, end)
        df = revenue_data[(revenue_data["Date"] >= prev_start) & (revenue_data["Date"] <= prev_end)].copy()
        df = apply_renewals_exclusion(df, bool(input.exclude_renewals()))
        return apply_amazon_region(apply_dtc_region(df, input.dtc_region()), input.amazon_region())

    @reactive.calc
    def prev_summary() -> Dict[str, float]:
        return metric_summary(revenue_prev_year_view())

    @reactive.calc
    def survey_filtered() -> pd.DataFrame:
        start, end = selected_range()
        return survey_data[(survey_data["Date"] >= start) & (survey_data["Date"] <= end)].copy()

    def survey_question_has_data(key: str) -> bool:
        question = key.lower()
        segment = input.survey_segment() if question in {"q1", "q2", "q3"} else "all"
        cols = survey_cols(question, segment)
        df = survey_filtered()
        if not cols or df.empty:
            return False
        return bool(df[cols].apply(pd.to_numeric, errors="coerce").fillna(0).to_numpy().sum() > 0)

    def survey_engagement_has_data() -> bool:
        df = survey_filtered()
        return bool(not df.empty and survey_participants(df).sum() > 0)

    @reactive.calc
    def summary() -> Dict[str, float]:
        return metric_summary(revenue_view_filtered())

    def csv_filename(slug: str) -> str:
        start, end = selected_range()
        return f"{slug}_{start.date()}_{end.date()}.csv"

    def csv_text(df: pd.DataFrame) -> str:
        out = df.copy()
        for col in out.columns:
            if pd.api.types.is_datetime64_any_dtype(out[col]):
                out[col] = out[col].dt.strftime("%Y-%m-%d")
        return out.to_csv(index=False)

    def visible_or_relative(df: pd.DataFrame, cats: Sequence[str], view: str) -> pd.DataFrame:
        cats = [cat for cat in cats if cat in df.columns]
        if view != "Relative" or not cats:
            return df[["Date"] + cats].copy() if "Date" in df.columns else df[cats].copy()
        out = df[["Date"]].copy()
        total = df[cats].sum(axis=1)
        for cat in cats:
            out[f"{cat} Share"] = np.where(total > 0, df[cat] / total, 0)
        return out

    def revenue_vs_spend_export() -> pd.DataFrame:
        df = revenue_view_filtered()
        if df.empty:
            return pd.DataFrame(columns=["Date", "Revenue", "Spend"])
        rev_col, spend_col = REVENUE_SPEND_SOURCES[input.selected_revenue_spend_type()]
        work = df[["Date", rev_col]].copy()
        work["Revenue"] = work[rev_col]
        work["Spend"] = df[spend_col] if spend_col else 0
        work = work[["Date", "Revenue", "Spend"]]
        if input.viz_by_month():
            work = monthly_date(work).groupby("Date", as_index=False)[["Revenue", "Spend"]].sum()
        return visible_or_relative(work, ["Revenue", "Spend"], input.selected_view_mode())

    def roas_export() -> pd.DataFrame:
        metric = input.selected_roas_type()
        mapping = {
            "Blended_ROAS": ("Total_Revenue", "Total_Spend"),
            "wROAS": ("DTC_Revenue", "Total_DTC_Spend"),
            "aROAS": ("Amazon_Revenue", "Amazon_Spend"),
            "appROAS": ("App_Revenue", "Total_App_Spend"),
        }
        num_col, den_col = mapping[metric]
        df = aggregate_sum(revenue_view_filtered(), [num_col, den_col], input.viz_by_month())
        df["Value"] = np.where(df[den_col] > 0, df[num_col] / df[den_col], np.nan) if not df.empty else np.nan
        return df[["Date", num_col, den_col, "Value"]]

    def spu_export() -> pd.DataFrame:
        df = revenue_view_filtered().copy()
        if df.empty:
            return pd.DataFrame(columns=["Date", input.selected_SPU_type()])
        df["DTC_HW"] = df.get("DTC_Hardware_Units", 0)
        df["DTC_TOTAL_HW"] = df.get("DTC_Total_Hardware_Units", df["DTC_HW"])
        df["Amazon_HW"] = df.get("Amazon_Hardware_Units", 0)
        df["Blended_HW"] = df["DTC_TOTAL_HW"].fillna(0) + df["Amazon_HW"].fillna(0)
        cols = ["Total_Spend", "Total_DTC_Spend", "Amazon_Spend", "Total_App_Spend", "Blended_HW", "DTC_HW", "Amazon_HW", "App_Orders"]
        if input.viz_by_month():
            df = monthly_date(df[["Date"] + cols]).groupby("Date", as_index=False)[cols].sum()
        df["Blended_SPU"] = np.where(df["Blended_HW"] > 0, df["Total_Spend"] / df["Blended_HW"], np.nan)
        df["wSPU"] = np.where(df["DTC_HW"] > 0, df["Total_DTC_Spend"] / df["DTC_HW"], np.nan)
        df["aSPU"] = np.where(df["Amazon_HW"] > 0, df["Amazon_Spend"] / df["Amazon_HW"], np.nan)
        df["appSPU"] = np.where(df["App_Orders"] > 0, df["Total_App_Spend"] / df["App_Orders"], np.nan)
        metric = input.selected_SPU_type()
        return df[["Date", metric]]

    def cr_export() -> pd.DataFrame:
        df = revenue_view_filtered()
        if df.empty or "Web_CR" not in df.columns:
            return pd.DataFrame(columns=["Date", "CR"])
        if input.viz_by_month():
            rows = []
            for date, group in monthly_date(df).groupby("Date"):
                rows.append({"Date": date, "CR": weighted_mean(group["Web_CR"], group.get("DTC_Orders", pd.Series(1, index=group.index)))})
            return pd.DataFrame(rows)
        return df[["Date", "Web_CR"]].rename(columns={"Web_CR": "CR"})

    def aov_export() -> pd.DataFrame:
        df = revenue_view_filtered()
        if df.empty:
            return pd.DataFrame(columns=["Date", "AOV"])
        if input.selected_aov_type() == "Segmented_AOV":
            if input.viz_by_month():
                rows = []
                for date, group in monthly_date(df).groupby("Date"):
                    weights = group.get("DTC_Orders", pd.Series(1, index=group.index))
                    rows.append({"Date": date, "First-Time": weighted_mean(group["fAOV"], weights), "Returning": weighted_mean(group["rAOV"], weights)})
                return pd.DataFrame(rows)
            return df[["Date", "fAOV", "rAOV"]].rename(columns={"fAOV": "First-Time", "rAOV": "Returning"})
        metric = input.selected_aov_type()
        if input.viz_by_month():
            rows = []
            for date, group in monthly_date(df).groupby("Date"):
                weights = group.get("DTC_Orders", pd.Series(1, index=group.index))
                rows.append({"Date": date, "AOV": weighted_mean(group[metric], weights)})
            return pd.DataFrame(rows)
        return df[["Date", metric]].rename(columns={metric: "AOV"})

    def customer_split_export() -> pd.DataFrame:
        df = revenue_view_filtered()
        if df.empty or "Returning_Customers" not in df.columns or "First_Time_Customers" not in df.columns:
            return pd.DataFrame(columns=["Date", "Returning", "First-Time"])
        if input.viz_by_month():
            rows = []
            for date, group in monthly_date(df).groupby("Date"):
                weights = group.get("DTC_Orders", pd.Series(1, index=group.index))
                rows.append(
                    {
                        "Date": date,
                        "Returning": weighted_mean(group["Returning_Customers"], weights),
                        "First-Time": weighted_mean(group["First_Time_Customers"], weights),
                    }
                )
            return pd.DataFrame(rows)
        return df[["Date", "Returning_Customers", "First_Time_Customers"]].rename(
            columns={"Returning_Customers": "Returning", "First_Time_Customers": "First-Time"}
        )

    def revenue_share_export() -> pd.DataFrame:
        sources = composition_bands(
            REVENUE_SHARE_COLS,
            bool(input.revenue_share_include_retail()),
            bool(input.revenue_share_include_app()),
        )
        cols = list(sources)
        df = aggregate_sum(revenue_view_filtered(), cols, input.viz_by_month())
        labels = {
            "DTC_Revenue": f"DTC ({dtc_region_label(input.dtc_region())})",
            "Amazon_Revenue": f"Amazon ({amazon_region_label(input.amazon_region())})",
            "IndieGoGo_Revenue": "IndieGoGo",
            "Digital_Marketplaces_Revenue": "Digital Marketplaces",
            "Retail_Revenue": "Retail",
            "App_Revenue": "App",
        }
        labels = {col: labels[col] for col in cols}
        df = df.rename(columns=labels)
        return visible_or_relative(df, list(labels.values()), input.selected_revenue_view_mode())

    def spend_composition_export() -> pd.DataFrame:
        sources = composition_bands(
            DTC_SPEND_COLS if input.selected_spend_composition() == "DTC" else TOTAL_SPEND_COLS,
            bool(input.spend_composition_include_retail()),
            bool(input.spend_composition_include_app()),
        )
        cols = list(sources)
        df = aggregate_sum(revenue_view_filtered(), cols, input.viz_by_month())
        labels = {col: col.replace("_", " ") for col in cols}
        df = df.rename(columns=labels)
        return visible_or_relative(df, list(labels.values()), input.selected_spend_view_mode())

    def units_ua_export() -> pd.DataFrame:
        df = units_bucket(revenue_view_filtered(), input.viz_by_month())
        if df.empty:
            return pd.DataFrame(columns=["Date"])
        channel = input.units_ua_channel()
        cats = ["Units", "Addons"] + (["Seeds"] if input.units_include_seeds() and channel in ["All", "DTC"] else [])
        plot = pd.DataFrame({"Date": df["Date"]})
        for cat in cats:
            if channel == "All":
                total = pd.Series(0, index=df.index, dtype="float64")
                for group in PNL_ROLLUP_CHANNELS:
                    total = total + df.get(f"{cat}_{group}", 0)
                plot[cat] = total
            else:
                plot[cat] = df.get(f"{cat}_{channel}", 0)
        return visible_or_relative(plot, cats, input.units_ua_view())

    def sku_group_mode() -> str:
        if bool(input.by_type_colour()):
            return "type_colour"
        if bool(input.by_type()):
            return "type"
        return "family"

    def sku_export(by_sku: bool = False) -> pd.DataFrame:
        mode = sku_group_mode()
        df = product_time_series(SKU_PRODUCTS, input.sku_channel(), input.viz_by_month(), mode=mode)
        cats = [c for c in df.columns if c != "Date"]
        out = visible_or_relative(df, cats, input.sku_view())
        if not by_sku:
            return out
        if mode == "type_colour":
            return rename_to_sku(out, product_sku_map(SKU_PRODUCTS))
        return rename_to_sku(out, bucket_sku_map(SKU_FAMILY_BUCKETS if mode == "family" else SKU_TYPE_BUCKETS, SKU_PRODUCTS))

    def addon_export(by_sku: bool = False) -> pd.DataFrame:
        by_colour = bool(input.by_colour_addon())
        channel = input.addon_channel()
        df = revenue_view_filtered()
        out = df[["Date"]].copy()
        if by_colour:
            products = ADDON_PRODUCTS
        else:
            products = ADDON_SUMMARY_PRODUCTS
        for product in products:
            cols = product_cols_for_channel(product, channel)
            out[product["name"]] = sum_cols(df, cols)
        if input.viz_by_month():
            value_cols = [c for c in out.columns if c != "Date"]
            out = monthly_date(out).groupby("Date", as_index=False)[value_cols].sum()
        cats = [c for c in out.columns if c != "Date"]
        res = visible_or_relative(out, cats, input.addon_view())
        return rename_to_sku(res, addon_sku_map(by_colour)) if by_sku else res

    def seed_export(by_sku: bool = False) -> pd.DataFrame:
        df = revenue_view_filtered()
        out = df[["Date"]].copy()
        by_weight = bool(input.seed_by_weight())
        if by_weight:
            for name, _, _, cols in SEED_PRODUCTS:
                out[name] = sum_cols(df, cols)
        else:
            for name, cols in SEED_TYPE_BUCKETS.items():
                out[name] = sum_cols(df, cols)
        if input.viz_by_month():
            value_cols = [c for c in out.columns if c != "Date"]
            out = monthly_date(out).groupby("Date", as_index=False)[value_cols].sum()
        cats = [c for c in out.columns if c != "Date"]
        res = visible_or_relative(out, cats, input.seed_view_mode())
        return rename_to_sku(res, seed_sku_map(by_weight)) if by_sku else res

    def app_subs_export() -> pd.DataFrame:
        df = revenue_view_filtered()
        out = df[["Date"]].copy()
        channel = input.appsubs_channel()
        monthly = pd.Series(0, index=df.index, dtype="float64")
        yearly = pd.Series(0, index=df.index, dtype="float64")
        if channel in ["All", "Apple"]:
            monthly = monthly + sum_cols(df, ["apple_monthly_sub"])
            yearly = yearly + sum_cols(df, ["apple_yearly_sub"])
        if channel in ["All", "Google"]:
            monthly = monthly + sum_cols(df, ["google_monthly_sub"])
            yearly = yearly + sum_cols(df, ["google_yearly_sub"])
        if channel in ["All", "DTC"]:
            yearly = yearly + sum_cols(df, ["DTC_Subscription_Units"])
        out["Monthly"] = monthly
        out["Yearly"] = yearly
        if input.viz_by_month():
            out = monthly_date(out).groupby("Date", as_index=False)[["Monthly", "Yearly"]].sum()
        return visible_or_relative(out, ["Monthly", "Yearly"], input.appsubs_view())

    def survey_pie_export(question: str, segment: str) -> pd.DataFrame:
        cols = survey_cols(question, segment)
        if not cols or survey_filtered().empty:
            return pd.DataFrame(columns=["Category", "Count", "Percent"])
        totals = survey_filtered()[cols].fillna(0).sum().reset_index()
        totals.columns = ["Category", "Count"]
        totals["Category"] = totals["Category"].map(lambda value: clean_question_label(value, question, segment))
        totals = totals[totals["Count"] > 0]
        total = totals["Count"].sum()
        totals["Percent"] = np.where(total > 0, totals["Count"] / total, 0)
        return totals

    def survey_stack_export(question: str, segment: str) -> pd.DataFrame:
        cols = survey_cols(question, segment)
        df = survey_filtered()
        if not cols or df.empty:
            return pd.DataFrame(columns=["Date", "Category", "Count", "Share"])
        long = df[["Date"] + cols].copy()
        if input.viz_by_month():
            long = monthly_date(long).groupby("Date", as_index=False)[cols].sum()
        else:
            long = long.groupby("Date", as_index=False)[cols].sum()
        long = long.melt(id_vars="Date", var_name="Category", value_name="Count")
        long["Category"] = long["Category"].map(lambda value: clean_question_label(value, question, segment))
        totals = long.groupby("Date")["Count"].transform("sum")
        long["Share"] = np.where(totals > 0, long["Count"] / totals, 0)
        return long

    def summary_export() -> pd.DataFrame:
        start, end = selected_range()
        s = summary()
        dtc_region = input.dtc_region()
        dtc_label = dtc_region_label(dtc_region)
        dtc_title_suffix = "" if dtc_region == "all" else f" ({dtc_label})"
        amazon_region = input.amazon_region()
        amazon_label = amazon_region_label(amazon_region)
        amazon_title_suffix = "" if amazon_region == "all" else f" ({amazon_label})"
        rows = []

        def add(section: str, metric: str, value, note: str = "", start_date: object = "", end_date: object = ""):
            rows.append(
                {
                    "Section": section,
                    "Metric": metric,
                    "Value": value,
                    "Start": start_date,
                    "End": end_date,
                    "Note": note,
                }
            )

        add("Context", "Date Start", start.date())
        add("Context", "Date End", end.date())
        add("Context", "DTC View", dtc_label)
        add("Context", "Amazon View", amazon_label)
        add("Revenue", "Total Revenue", s.get("Total_Revenue", 0))
        add("Revenue", f"DTC Revenue{dtc_title_suffix}", s.get("DTC_Revenue", 0))
        for label, key in [
            ("Hardware", "DTC_Hardware"),
            ("Add-ons", "DTC_Addons"),
            ("Merch", "DTC_Merch"),
            ("Seeds", "DTC_Seeds"),
            ("Subscription", "DTC_Subscription"),
            ("Taxes", "DTC_Taxes"),
            ("Shipping", "DTC_Shipping"),
            ("Gift cards", "DTC_Gift_Cards"),
            ("Unallocated", "DTC_Unallocated"),
        ]:
            add("DTC Revenue Breakdown", label, s.get(key, 0))
        add("Revenue", f"Amazon Revenue{amazon_title_suffix}", s.get("Amazon_Revenue", 0))
        for label, key in [
            ("US", "Amazon_US_Revenue"),
            ("EU", "Amazon_EU_Revenue"),
            ("UK", "Amazon_UK_Revenue"),
            ("FR", "Amazon_FR_Revenue"),
            ("GER", "Amazon_GER_Revenue"),
        ]:
            add("Amazon Regional Revenue", label, s.get(key, 0))
        for label, key in [
            ("Hardware", "Amazon_Hardware"),
            ("Add-ons", "Amazon_Addons"),
            ("Tax", "Amazon_Tax"),
            ("Shipping", "Amazon_Shipping"),
            ("Gift Wrap", "Amazon_GiftWrap"),
        ]:
            add("Amazon Revenue Breakdown", label, s.get(key, 0))
        add("Revenue", "IndieGoGo Revenue", s.get("IndieGoGo_Revenue", 0))
        for label, key in [
            ("Hardware", "IndieGoGo_Hardware"),
            ("Add-ons", "IndieGoGo_Addons"),
            ("Taxes", "IndieGoGo_Tax"),
            ("Shipping", "IndieGoGo_Shipping"),
        ]:
            add("IndieGoGo Revenue Breakdown", label, s.get(key, 0))
        add("Revenue", "Digital Marketplaces", s.get("Digital_Marketplaces_Revenue", 0))
        for label, key in [
            ("Rachio", "Rachio_Revenue"),
            ("Weatherflow", "Weatherflow_Revenue"),
            ("Huckberry", "Huckberry_Revenue"),
        ]:
            add("Digital Marketplaces Breakdown", label, s.get(key, 0))
        add("Revenue", "Retail Revenue", s.get("B2B_Revenue", 0))
        for label, key in [
            ("BestBuy", "BestBuy_Revenue"),
            ("Target", "Target_Revenue"),
            ("Walmart", "Walmart_Revenue"),
            ("Walmart Retail", "Walmart_Retail_Revenue"),
            ("Costco", "Costco_Revenue"),
            ("Chewy", "Chewy_Revenue"),
            ("Ace Hardware", "Ace_Hardware_Revenue"),
        ]:
            add("Retail Revenue Breakdown", label, s.get(key, 0))
        add("Revenue", "App Revenue", s.get("App_Revenue", 0))
        add("Spend", "Total Spend", s.get("Total_Spend", 0))
        add("Spend", f"DTC Spend{dtc_title_suffix}", s.get("Total_DTC_Spend", 0))
        for label, key in [
            ("Meta", "Meta_Spend"),
            ("Google", "Google_Spend"),
            ("Bing", "Bing_Spend"),
            ("TikTok", "TikTok_Spend"),
            ("Snapchat", "Snapchat_Spend"),
            ("Nextdoor", "Nextdoor_Spend"),
        ]:
            add("DTC Spend Breakdown", label, s.get(key, 0))
        add("Spend", f"Amazon Spend{amazon_title_suffix}", s.get("Amazon_Spend", 0))
        for label, key in [
            ("US", "Amazon_Spend_US"),
            ("EU", "Amazon_Spend_EU"),
            ("UK", "Amazon_Spend_UK"),
            ("FR", "Amazon_Spend_FR"),
            ("GER", "Amazon_Spend_GER"),
        ]:
            add("Amazon Regional Spend", label, s.get(key, 0))
        add("Spend", "Retail Spend", s.get("Retail_Spend", 0))
        for label, key in [
            ("BestBuy", "BestBuy_Spend"),
            ("Target", "Target_Spend"),
            ("Walmart", "Walmart_Spend"),
            ("Chewy", "Chewy_Spend"),
        ]:
            add("Retail Spend Breakdown", label, s.get(key, 0))
        add("Spend", "IndieGoGo Spend", s.get("IndieGoGo_Spend", 0))
        add("Spend", "Fees", s.get("Fees", 0))
        for label, key in [
            ("Affiliate Fees", "Affiliate_Fees"),
            ("Rachio Fees", "Rachio_Fees"),
            ("Weatherflow Fees", "Weatherflow_Fees"),
            ("Costco Fees", "Costco_Fees"),
        ]:
            add("Fees Breakdown", label, s.get(key, 0))
        add("Spend", "Total App Spend", s.get("Total_App_Spend", 0))
        for label, key in [
            ("Meta", "App_Spend_Meta"),
            ("Apple", "App_Spend_Apple"),
            ("Google", "App_Spend_Google"),
        ]:
            add("App Spend Breakdown", label, s.get(key, 0))
        add("KPI", "Blended ROAS", s.get("Blended_ROAS_calc"))
        add("KPI", "Blended ROAS w/o renewals", s.get("Blended_ROAS_WO_Renewals_calc"))
        add("KPI", "Blended ROAS w/o renewals + retail", s.get("Blended_ROAS_WO_Renewals_Retail_calc"))
        add("KPI", "Blended ROAS w/o renewals + retail (sheets)", s.get("Blended_ROAS_WO_Renewals_Retail_weighted", s.get("Blended_ROAS_WO_Renewals_Retail", np.nan)))
        add("KPI", f"DTC ROAS ({dtc_label})", s.get("wROAS_calc"))
        add("KPI", "DTC ROAS w/o renewals", s.get("wROAS_WO_Renewals_weighted", s.get("wROAS_WO_Renewals", np.nan)))
        add("KPI", f"Amazon ROAS ({amazon_label})", s.get("aROAS_calc"))
        add("KPI", "App ROAS", s.get("appROAS_calc"))
        add("KPI", "Blended Spend per Unit", s.get("Blended_SPU_calc"))
        add("KPI", f"DTC SPU ({dtc_label})", s.get("wSPU_calc"))
        add("KPI", "DTC SPU US", s.get("wSPU_US_calc"))
        add("KPI", "DTC SPU EU", s.get("wSPU_EU_calc"))
        add("KPI", f"Amazon SPU ({amazon_label})", s.get("aSPU_calc"))
        add("KPI", "Amazon SPU US", s.get("aSPU_US_calc"))
        add("KPI", "Amazon SPU EU", s.get("aSPU_EU_calc"))
        add("KPI", "App SPU", s.get("appSPU_calc"))
        add("KPI", "Web CR", s.get("Web_CR_weighted"))
        add("KPI", "Web AOV", s.get("Web_AOV_weighted"))
        add("KPI", "Web AOV w/o renewals", s.get("Web_AOV_WO_Renewals_weighted", s.get("Web_AOV_WO_Renewals", np.nan)))
        add("KPI", "First-Time AOV", s.get("fAOV_weighted"))
        add("KPI", "Returning AOV", s.get("rAOV_weighted"))
        add("KPI", "Web Revenue per Unit", s.get("Web_RPU_weighted", s.get("Web_RPU", np.nan)))
        add("KPI", "Web Revenue per Unit w/o renewals", s.get("Web_RPU_WO_Renewals_weighted", s.get("Web_RPU_WO_Renewals", np.nan)))
        add("KPI", "First-Time Revenue per Unit", s.get("fRPU_weighted", s.get("fRPU", np.nan)))
        add("KPI", "Returning Revenue per Unit", s.get("rRPU_weighted", s.get("rRPU", np.nan)))
        add("KPI", "Amazon Revenue per Unit", s.get("Amazon_RPU_weighted", s.get("Amazon_RPU", np.nan)))
        add("KPI", "Returning Customers", s.get("Returning_Customers_weighted"))
        add("KPI", "First-Time Customers", s.get("First_Time_Customers_weighted"))
        add("Customers", "Customers", s.get("Customers", 0))
        add("Customers", "Customers US", s.get("Customers_US", 0))
        add("Customers", "Customers EU", s.get("Customers_EU", 0))
        add("Customers", "Returning US Orders", s.get("Returning_US_Orders", 0))
        add("Customers", "Returning EU Orders", s.get("Returning_EU_Orders", 0))
        for label, key in [
            (f"DTC Orders{dtc_title_suffix}", "DTC_Orders"),
            ("DTC Hardware Units", "DTC_Hardware_Units"),
            ("DTC Add-on Units", "DTC_Addons_Units"),
            ("DTC Subscription Units", "DTC_Subscription_Units"),
            (f"Amazon Orders{amazon_title_suffix}", "Amazon_Orders"),
            ("Amazon US Orders", "Amazon_US_Orders"),
            ("Amazon EU Orders", "Amazon_EU_Orders"),
            ("Amazon UK Orders", "Amazon_UK_Orders"),
            ("Amazon FR Orders", "Amazon_FR_Orders"),
            ("Amazon GER Orders", "Amazon_GER_Orders"),
            ("Amazon Hardware Units", "Amazon_Hardware_Units"),
            ("Amazon Add-on Units", "Amazon_Addons_Units"),
            ("Amazon US Hardware Units", "Amazon_US_Hardware_Units"),
            ("Amazon EU Hardware Units", "Amazon_EU_Hardware_Units"),
            ("Amazon US Add-on Units", "Amazon_US_Addons_Units"),
            ("Amazon EU Add-on Units", "Amazon_EU_Addons_Units"),
            ("IndieGoGo Orders", "IndieGoGo_Orders"),
            ("Digital Marketplaces Orders", "Digital_Marketplaces_Orders"),
            ("Rachio Orders", "Rachio_Orders"),
            ("Weatherflow Orders", "Weatherflow_Orders"),
            ("Huckberry Orders", "Huckberry_Orders"),
            ("Retail Orders", "B2B_Orders"),
            ("BestBuy Orders", "BestBuy_Orders"),
            ("Target Orders", "Target_Orders"),
            ("Walmart Orders", "Walmart_Orders"),
            ("Walmart Retail Orders", "Walmart_Retail_Orders"),
            ("Costco Orders", "Costco_Orders"),
            ("Chewy Orders", "Chewy_Orders"),
            ("Ace Hardware Orders", "Ace_Hardware_Orders"),
            ("App Orders", "App_Orders"),
            ("Apple Store Orders", "Apple_Store_Orders"),
            ("Google Store Orders", "Google_Store_Orders"),
        ]:
            add("Orders", label, s.get(key, 0))

        if not campaign_notes_df.empty and {"start", "end", "note"}.issubset(campaign_notes_df.columns):
            notes = campaign_notes_df[(campaign_notes_df["start"] <= end) & (campaign_notes_df["end"] >= start)]
            for _, row in notes.iterrows():
                add("Notes", "Campaign Note", "", str(row["note"]), row["start"].date(), row["end"].date())
        return pd.DataFrame(rows)

    def pnl_product_export(products: Sequence[dict], channels: Sequence[str], *, show_all: bool = True) -> pd.DataFrame:
        df = revenue_view_filtered()
        counts = product_counts(df, products, channels)
        value_channels = [*channels, "All"] if show_all else list(channels)
        # The export follows the SKU mix toggle, so a downloaded table reads the same
        # way as the one on screen.
        unit_products = pnl_product_sets(pnl_mode())[0]
        base = hardware_base(product_counts(df, unit_products, channels)) if bool(input.pnl_sku_mix()) else None
        rows = []
        totals = {channel: 0.0 for channel in value_channels}
        for product in products:
            row_counts = counts[product["name"]]
            row = {
                "Product": product.get("display_name", product["name"]),
                "SKU": product.get("sku", ""),
            }
            for channel in value_channels:
                value = row_counts.get(channel, 0.0)
                totals[channel] += value
                if channel != "All" and not product["cols"].get(channel):
                    row[channel] = ""
                elif base is None:
                    row[channel] = value
                else:
                    share = mix_share(value, base.get(channel, 0.0))
                    row[channel] = "" if share is None else round(share, 6)
            rows.append(row)
        total_row = {"Product": "TOTAL", "SKU": ""}
        for channel in value_channels:
            if base is None:
                total_row[channel] = totals[channel]
            else:
                share = mix_share(totals[channel], base.get(channel, 0.0))
                total_row[channel] = "" if share is None else round(share, 6)
        rows.append(total_row)
        return pd.DataFrame(rows)

    def export_data(output_id: str, by_sku: bool = False) -> pd.DataFrame:
        if output_id == "summary_cards":
            return summary_export()
        export_skus, export_addons, export_seeds = pnl_product_sets(pnl_mode())
        if output_id == "pnl_units":
            return pnl_product_export(export_skus, PNL_UNIT_CHANNELS)
        if output_id == "pnl_addons":
            return pnl_product_export(export_addons, PNL_ADDON_CHANNELS)
        if output_id == "pnl_app_subscriptions":
            return pnl_product_export(APP_SUB_PRODUCTS, ["DTC", "Apple", "Google"])
        if output_id == "pnl_seeds":
            return pnl_product_export(export_seeds, ["DTC"], show_all=False)
        if output_id == "revenue_vs_spend_plot":
            return revenue_vs_spend_export()
        if output_id == "blended_roas_bar_chart":
            return roas_export()
        if output_id == "blended_SPU_bar_chart":
            return spu_export()
        if output_id == "cr_bar_chart":
            return cr_export()
        if output_id == "aov_bar_chart":
            return aov_export()
        if output_id == "customer_split_chart":
            return customer_split_export()
        if output_id == "revenue_share_chart":
            return revenue_share_export()
        if output_id == "spend_composition_chart":
            return spend_composition_export()
        if output_id == "units_ua_plot":
            return units_ua_export()
        if output_id == "sku_plot":
            return sku_export(by_sku)
        if output_id == "addon_plot":
            return addon_export(by_sku)
        if output_id == "seed_plot":
            return seed_export(by_sku)
        if output_id == "app_subs_by_channel_plot":
            return app_subs_export()
        pie_match = re.fullmatch(r"(q\d+)_pie_chart", output_id)
        if pie_match:
            question = pie_match.group(1)
            segment = input.survey_segment() if question in {"q1", "q2", "q3"} else "all"
            return survey_pie_export(question, segment)
        if output_id == "q1_engagement_bar":
            return engagement_frame(survey_filtered(), revenue_view_filtered(), input.viz_by_month())
        stack_match = re.fullmatch(r"(q\d+)_daily_stack", output_id)
        if stack_match:
            question = stack_match.group(1)
            segment = input.survey_segment() if question in {"q1", "q2", "q3"} else "all"
            return survey_stack_export(question, segment)
        return pd.DataFrame()

    @render.ui
    def campaign_notes():
        if campaign_notes_df.empty or not {"start", "end", "note"}.issubset(campaign_notes_df.columns):
            return None
        start, end = selected_range()
        notes = campaign_notes_df[(campaign_notes_df["start"] <= end) & (campaign_notes_df["end"] >= start)]
        if notes.empty:
            return None
        visible = notes_visible.get()

        def _fmt_range(s, e) -> str:
            s = pd.Timestamp(s)
            e = pd.Timestamp(e)
            same_year = s.year == e.year
            same_month = same_year and s.month == e.month
            same_day = same_month and s.day == e.day
            if same_day:
                return s.strftime("%b %-d")
            if same_month:
                return f"{s.strftime('%b %-d')}\u2013{e.day}"
            if same_year:
                return f"{s.strftime('%b %-d')} \u2013 {e.strftime('%b %-d')}"
            return f"{s.strftime('%b %-d, %y')} \u2013 {e.strftime('%b %-d, %y')}"

        lines = []
        for _, row in notes.iterrows():
            note_html = str(row["note"]).replace(chr(10), "<br>")
            lines.append(
                ui.div(
                    ui.div(_fmt_range(row["start"], row["end"]), class_="notes-date"),
                    ui.div(ui.HTML(note_html), class_="notes-text"),
                    class_="notes-item",
                )
            )
        return ui.div(
            ui.input_action_button(
                "toggle_notes",
                ui.TagList(
                    ui.span("", class_=f"notes-caret {'up' if visible else 'down'}"),
                    ui.span("Notes"),
                ),
                class_="notes-toggle",
            ),
            ui.div(*lines, class_="notes-box") if visible else None,
            class_="summary-page",
        )

    @render.ui
    def summary_cards():
        s = summary()
        expanded = summary_expanded.get()
        comp_on = bool(input.comparison_mode())
        p = prev_summary() if comp_on else {}

        def yoy(key: str, current_val: object = None, prev_formatter=None, lower_is_better: bool = False) -> Optional[str]:
            if not comp_on:
                return None
            cv = current_val if current_val is not None else s.get(key)
            pv = p.get(key)
            return yoy_pct_html(cv, pv, prev_formatter=prev_formatter, lower_is_better=lower_is_better)

        def part(label: str, key: str, default: float = 0.0) -> Tuple[str, float, str]:
            """A breakdown row that remembers its metric, so it can carry its own YoY."""
            return label, s.get(key, default), key

        def shown(label: str, key: str, formatter, default: float = np.nan, note: Optional[str] = None) -> Tuple[str, str, Optional[str]]:
            """A breakdown row formatted here, for panels that mix rates and counts."""
            return with_note(label, note), formatter(s.get(key, default)), yoy(key, prev_formatter=formatter)

        def with_note(label: str, note: Optional[str]) -> str:
            if not note:
                return label
            return f'{label}<i class="summary-detail-note" data-note="{html.escape(note, quote=True)}">i</i>'

        def detail_row(label: str, value_html: str, cls: str = "", pill: Optional[str] = None) -> str:
            figure = f'<span class="summary-detail-val">{value_html}</span>'
            # Wrapped whenever the comparison is on, pill or not, so the amounts stay
            # in one column even where a prior-year figure is missing.
            if comp_on:
                figure = f'<span class="summary-detail-figure">{pill or ""}{figure}</span>'
            return (
                f'<div class="summary-detail-row{cls}">'
                f'<span class="summary-detail-key">{label}</span>'
                f'{figure}'
                f'</div>'
            )

        def detail(
            key: str,
            rows: Sequence[Sequence[object]],
            money: bool = True,
            memo_from: Optional[str] = None,
            split_from: Optional[str] = None,
            lower_is_better: bool = False,
        ) -> Optional[str]:
            if key not in expanded:
                return None
            formatter = (lambda v: fmt_money_r(v, 2)) if money else fmt_num
            out = []
            for row in rows:
                label, value = str(row[0]), row[1]
                metric = str(row[2]) if len(row) > 2 else None
                # A memo row sits outside the headline total, so it is set apart
                # rather than reading as part of the sum. A split row still counts
                # towards it and only marks where a new group starts.
                cls = ""
                if label == memo_from:
                    cls = " summary-detail-memo"
                elif label == split_from:
                    cls = " summary-detail-split"
                pill = None
                if metric:
                    pill = yoy(metric, prev_formatter=formatter, lower_is_better=lower_is_better)
                out.append(detail_row(label, formatter(value), cls, pill))
            return "".join(out)

        def dtc_revenue_rows() -> List[Tuple[str, float, str]]:
            """Components of the DTC revenue headline.

            The product side always lists in full, including zeroes, so the shape of
            the card stays the same from one date range to the next. The subscription
            side is appended only when it is on the headline, which is the whole of
            the difference the renewals toggle makes.
            """
            rows = [
                part("Hardware", "DTC_Hardware"),
                part("Add-ons", "DTC_Addons"),
                part("Merch", "DTC_Merch"),
                part("Seeds", "DTC_Seeds"),
                part("Gift Bag", "DTC_Gift_Bag"),
                part("Taxes (w/o subscriptions)", "DTC_Taxes"),
                part("Shipping", "DTC_Shipping"),
            ]
            # Gift cards and the residual only exist in the Shopify era, so each row
            # appears when it has a figure rather than sitting at zero under every
            # other date range.
            if abs(float(s.get("DTC_Gift_Cards", 0.0) or 0.0)) >= 0.005:
                rows.append(part(with_note("Gift cards", DTC_GIFT_CARDS_NOTE), "DTC_Gift_Cards"))
            if abs(float(s.get("DTC_Unallocated", 0.0) or 0.0)) >= 0.005:
                rows.append(part(with_note("Unallocated", DTC_UNALLOCATED_NOTE), "DTC_Unallocated"))
            if not excl_renewals:
                rows += [
                    part(DTC_SUBSCRIPTION_LABEL, "DTC_Subscription"),
                    part("Taxes (subscriptions)", "DTC_Subscription_Taxes"),
                ]
            return rows

        def mixed_detail(key: str, rows: Sequence[Sequence[object]]) -> Optional[str]:
            """Rows whose values are already formatted, so each brings its own pill."""
            if key not in expanded:
                return None
            return "".join(
                detail_row(str(row[0]), str(row[1]), pill=str(row[2]) if len(row) > 2 and row[2] else None)
                for row in rows
            )

        def formatted_detail(key: str, rows: Sequence[Tuple[str, str]]) -> Optional[str]:
            return mixed_detail(key, rows)

        total_revenue = s.get("Total_Revenue", 0)
        total_spend = s.get("Total_Spend", 0)
        blended_roas = s.get("Blended_ROAS_calc")
        blended_spu = s.get("Blended_SPU_calc")
        web_cr = s.get("Web_CR_weighted")
        web_aov = s.get("Web_AOV_weighted")
        returning = s.get("Returning_Customers_weighted")
        dtc_region = input.dtc_region()
        dtc_label = dtc_region_label(dtc_region)
        dtc_title_suffix = "" if dtc_region == "all" else f" ({dtc_label})"
        amazon_region = input.amazon_region()
        amazon_label = amazon_region_label(amazon_region)
        amazon_title_suffix = "" if amazon_region == "all" else f" ({amazon_label})"
        excl_renewals = bool(input.exclude_renewals())
        # The platform note is only worth the space when the range actually reaches back
        # into the Shopify months.
        shows_shopify_era = pd.Timestamp(selected_range()[0]) < WOOCOMMERCE_FROM
        shows_first_campaign = pd.Timestamp(selected_range()[0]) < INDIEGOGO_CAMPAIGN_ENDED
        roas_detail_rows = [
            shown(f"DTC ROAS ({dtc_label})", "wROAS_calc", fmt_detail_rate),
            shown(f"Amazon ROAS ({amazon_label})", "aROAS_calc", fmt_detail_rate),
            shown("App ROAS", "appROAS_calc", fmt_detail_rate),
        ]
        # The headline figures already exclude renewals under the toggle, so these
        # parallel w/o-renewals rows would just repeat them.
        if not excl_renewals:
            roas_detail_rows += [
                shown(
                    "Blended w/o renewals",
                    "Blended_ROAS_WO_Renewals_calc",
                    fmt_detail_rate,
                    note=BLENDED_WO_RENEWALS_NOTE,
                ),
                shown(
                    "Blended w/o renewals + retail",
                    "Blended_ROAS_WO_Renewals_Retail_calc",
                    fmt_detail_rate,
                    note=BLENDED_WO_RENEWALS_RETAIL_NOTE,
                ),
                shown(
                    "Blended w/o renewals + retail (sheets)",
                    "Blended_ROAS_WO_Renewals_Retail_weighted",
                    fmt_detail_rate,
                    note=BLENDED_SHEETS_NOTE,
                ),
            ]

        return ui.TagList(
            ui.div(
                summary_band(
                    "Total Revenue",
                    fmt_money_r(total_revenue),
                    "revenue",
                    "Includes DTC Revenue, Amazon Revenue, IndieGoGo Revenue and Digital Marketplaces",
                    yoy=yoy("Total_Revenue", prev_formatter=fmt_money_r),
                ),
                ui.div(
                    summary_click_metric(
                        f"DTC Revenue{dtc_title_suffix}",
                        fmt_money_r(s.get("DTC_Revenue", 0)),
                        color_class="summary-green",
                        input_id="toggle_dtc_revenue",
                        yoy=yoy("DTC_Revenue", prev_formatter=fmt_money_r),
                        note=DTC_PLATFORM_NOTE if shows_shopify_era else None,
                        detail=detail("dtc_revenue", dtc_revenue_rows(), split_from=DTC_SUBSCRIPTION_LABEL),
                    ),
                    summary_click_metric(
                        f"Amazon Revenue{amazon_title_suffix}",
                        fmt_money_r(s.get("Amazon_Revenue", 0)),
                        color_class="summary-green",
                        input_id="toggle_amazon_revenue",
                        yoy=yoy("Amazon_Revenue", prev_formatter=fmt_money_r),
                        detail=detail(
                            "amazon_revenue",
                            [
                                part("Hardware", "Amazon_Hardware"),
                                part("Add-ons", "Amazon_Addons"),
                                part("Tax", "Amazon_Tax"),
                                part("Shipping", "Amazon_Shipping"),
                                part("Gift Wrap", "Amazon_GiftWrap"),
                            ],
                        ),
                    ),
                    summary_click_metric(
                        "IndieGoGo Revenue",
                        fmt_money_r(s.get("IndieGoGo_Revenue", 0)),
                        color_class="summary-green",
                        input_id="toggle_indiegogo_revenue",
                        yoy=yoy("IndieGoGo_Revenue", prev_formatter=fmt_money_r),
                        note=INDIEGOGO_CAMPAIGN_NOTE if shows_first_campaign else None,
                        detail=detail(
                            "indiegogo_revenue",
                            [
                                part("Hardware", "IndieGoGo_Hardware"),
                                part("Add-ons", "IndieGoGo_Addons"),
                                part("Taxes", "IndieGoGo_Tax"),
                                part("Shipping", "IndieGoGo_Shipping"),
                            ],
                        ),
                    ),
                    summary_click_metric(
                        "Digital Marketplaces",
                        fmt_money_r(s.get("Digital_Marketplaces_Revenue", 0)),
                        color_class="summary-green",
                        input_id="toggle_digital_marketplaces",
                        yoy=yoy("Digital_Marketplaces_Revenue", prev_formatter=fmt_money_r),
                        detail=detail(
                            "digital_marketplaces",
                            [
                                part("Rachio", "Rachio_Revenue"),
                                part("Weatherflow", "Weatherflow_Revenue"),
                                part("Huckberry", "Huckberry_Revenue"),
                            ],
                        ),
                    ),
                    class_="summary-row",
                ),
                ui.div(
                    summary_plain_metric(
                        "Retail Revenue",
                        fmt_money_r(s.get("B2B_Revenue", 0)),
                        title_class="summary-title-green",
                        input_id="toggle_b2b_revenue",
                        yoy=yoy("B2B_Revenue", prev_formatter=fmt_money_r),
                        detail=detail(
                            "b2b_revenue",
                            [
                                part("BestBuy", "BestBuy_Revenue"),
                                part("Target", "Target_Revenue"),
                                part("Walmart", "Walmart_Revenue"),
                                part("Walmart Retail", "Walmart_Retail_Revenue"),
                                part("Costco", "Costco_Revenue"),
                                part("Chewy", "Chewy_Revenue"),
                                part("Ace Hardware", "Ace_Hardware_Revenue"),
                            ],
                        ),
                    ),
                    summary_plain_metric(
                        "App Revenue",
                        fmt_money_r(s.get("App_Revenue", 0)),
                        title_class="summary-title-green",
                        input_id="toggle_app_revenue",
                        yoy=yoy("App_Revenue", prev_formatter=fmt_money_r),
                        detail=detail(
                            "app_revenue",
                            [
                                part("Apple Store", "Apple_Store"),
                                part("Google Store", "Google_Store"),
                            ],
                        ),
                    ),
                    class_="summary-row",
                ),
                summary_band(
                    "Total Spend",
                    fmt_money_r(total_spend),
                    "spend",
                    "Includes DTC Spend, Amazon Spend, Retail Spend, IndieGoGo Spend and Fees",
                    yoy=yoy("Total_Spend", prev_formatter=fmt_money_r, lower_is_better=True),
                ),
                ui.div(
                    summary_click_metric(
                        f"DTC Spend{dtc_title_suffix}",
                        fmt_money_r(s.get("Total_DTC_Spend", 0)),
                        color_class="summary-red",
                        input_id="toggle_dtc_spend",
                        yoy=yoy("Total_DTC_Spend", prev_formatter=fmt_money_r, lower_is_better=True),
                        detail=detail(
                            "dtc_spend",
                            [
                                part("Meta", "Meta_Spend"),
                                part("Google", "Google_Spend"),
                                part("Bing", "Bing_Spend"),
                                part("TikTok", "TikTok_Spend"),
                                part("Snapchat", "Snapchat_Spend"),
                                part("Nextdoor", "Nextdoor_Spend"),
                            ],
                            lower_is_better=True,
                        ),
                    ),
	                    summary_click_metric(
	                        f"Amazon Spend{amazon_title_suffix}",
	                        fmt_money_r(s.get("Amazon_Spend", 0)),
	                        color_class="summary-red",
	                        input_id="toggle_amazon_spend",
	                        yoy=yoy("Amazon_Spend", prev_formatter=fmt_money_r, lower_is_better=True),
	                        detail=detail(
	                            "amazon_spend",
	                            [
	                                part("Amazon Spend", "Amazon_Spend"),
	                            ],
	                            lower_is_better=True,
	                        ),
	                    ),
                    summary_click_metric(
                        "IndieGoGo Spend",
                        fmt_money_r(s.get("IndieGoGo_Spend", 0)),
                        color_class="summary-red",
                        yoy=yoy("IndieGoGo_Spend", prev_formatter=fmt_money_r, lower_is_better=True),
                    ),
                    summary_click_metric(
                        "Fees",
                        fmt_money_r(s.get("Fees", 0)),
                        color_class="summary-red",
                        input_id="toggle_fees",
                        yoy=yoy("Fees", prev_formatter=fmt_money_r, lower_is_better=True),
                        detail=detail(
                            "fees",
                            [
                                part("Affiliate Fees", "Affiliate_Fees"),
                                part("Rachio Fees", "Rachio_Fees"),
                                part("Weatherflow Fees", "Weatherflow_Fees"),
                                part("Costco Fees", "Costco_Fees"),
                            ],
                            lower_is_better=True,
                        ),
                    ),
                    class_="summary-row",
                ),
                ui.div(
                    summary_plain_metric(
                        "Retail Spend",
                        fmt_money_r(s.get("Retail_Spend", 0)),
                        title_class="summary-title-red",
                        input_id="toggle_retail_spend",
                        yoy=yoy("Retail_Spend", prev_formatter=fmt_money_r, lower_is_better=True),
                        detail=detail(
                            "retail_spend",
                            [
                                part("Best Buy", "BestBuy_Spend"),
                                part("Target", "Target_Spend"),
                                part("Walmart", "Walmart_Spend"),
                                part("Chewy", "Chewy_Spend"),
                            ],
                            lower_is_better=True,
                        ),
                    ),
                    summary_plain_metric(
                        "Total App Spend",
                        fmt_money_r(s.get("Total_App_Spend", 0)),
                        title_class="summary-title-red",
                        input_id="toggle_app_spend",
                        yoy=yoy("Total_App_Spend", prev_formatter=fmt_money_r, lower_is_better=True),
                        detail=detail(
                            "app_spend",
                            [
                                part("Meta", "App_Spend_Meta"),
                                part("Apple", "App_Spend_Apple"),
                                part("Google", "App_Spend_Google"),
                            ],
                            lower_is_better=True,
                        ),
                    ),
                    class_="summary-row centered",
                ),
                ui.div(
                    summary_kpi(
                        "Blended ROAS:",
                        fmt_rate(blended_roas, 2),
                        "toggle_blended_roas",
                        formatted_detail("blended_roas", roas_detail_rows),
                        yoy=yoy("Blended_ROAS_calc", prev_formatter=lambda v: fmt_rate(v, 2)),
                    ),
                    summary_kpi(
                        "Blended Spend per<br>Unit:",
                        fmt_money_r(blended_spu, 2),
                        "toggle_blended_spu",
                        detail=detail(
                            "blended_spu",
                            [
                                part(f"DTC SPU ({dtc_label})", "wSPU_calc", np.nan),
                                part("DTC SPU US", "wSPU_US_calc", np.nan),
                                part("DTC SPU EU", "wSPU_EU_calc", np.nan),
                                part(f"Amazon SPU ({amazon_label})", "aSPU_calc", np.nan),
                                part("Amazon SPU US", "aSPU_US_calc", np.nan),
                                part("Amazon SPU EU", "aSPU_EU_calc", np.nan),
                                part("App SPU", "appSPU_calc", np.nan),
                            ],
                            lower_is_better=True,
                        ),
                        yoy=yoy("Blended_SPU_calc", prev_formatter=lambda v: fmt_money_r(v, 2), lower_is_better=True),
                    ),
                    summary_kpi(
                        "Web CR:",
                        fmt_pct(web_cr, 2),
                        yoy=yoy("Web_CR_weighted", prev_formatter=lambda v: fmt_pct(v, 2)),
                    ),
                    summary_kpi(
                        "Web AOV:",
                        fmt_money_r(web_aov, 2),
                        "toggle_web_aov",
                        detail=detail(
                            "web_aov",
                            [
                                row
                                for row in [
                                    part("Web AOV w/o renewals", "Web_AOV_WO_Renewals_weighted", np.nan),
                                    part("First-Time AOV", "fAOV_weighted", np.nan),
                                    part("Returning AOV", "rAOV_weighted", np.nan),
                                    part("Web Revenue per Unit", "Web_RPU_weighted", np.nan),
                                    part("Web RPU w/o renewals", "Web_RPU_WO_Renewals_weighted", np.nan),
                                    part("First-Time RPU", "fRPU_weighted", np.nan),
                                    part("Returning RPU", "rRPU_weighted", np.nan),
                                    part("Amazon RPU", "Amazon_RPU_weighted", np.nan),
                                ]
                                if not (excl_renewals and "w/o renewals" in row[0])
                            ],
                        ),
                        yoy=yoy("Web_AOV_weighted", prev_formatter=lambda v: fmt_money_r(v, 2)),
                    ),
                    summary_kpi(
                        "Returning<br>Customers:",
                        fmt_pct(returning, 2),
                        "toggle_returning_customers",
                        detail=mixed_detail(
                            "returning_customers",
                            [
                                shown("First-Time Customers", "First_Time_Customers_weighted", lambda v: fmt_pct(v, 2)),
                                shown("Customers", "Customers", fmt_num, 0),
                                shown("Customers US", "Customers_US", fmt_num, 0),
                                shown("Customers EU", "Customers_EU", fmt_num, 0),
                                shown("Returning US Orders", "Returning_US_Orders", fmt_num, 0),
                                shown("Returning EU Orders", "Returning_EU_Orders", fmt_num, 0),
                            ],
                        ),
                        yoy=yoy("Returning_Customers_weighted", prev_formatter=lambda v: fmt_pct(v, 2)),
                    ),
                    class_="summary-kpi-strip",
                ),
                ui.div(
                    ui.div(
                        summary_order(
                            f"DTC Orders{dtc_title_suffix}",
                            fmt_num(s.get("DTC_Orders", 0)),
                            "toggle_dtc_orders",
                            detail=detail(
                                "dtc_orders",
                                [
                                    part("Hardware Units", "DTC_Hardware_Units"),
                                    part("Add-on Units", "DTC_Addons_Units"),
                                    part("Subscription Units", "DTC_Subscription_Units"),
                                ],
                                money=False,
                            ),
                            yoy=yoy("DTC_Orders", prev_formatter=fmt_num),
                        ),
                        summary_order(
                            f"Amazon Orders{amazon_title_suffix}",
                            fmt_num(s.get("Amazon_Orders", 0)),
                            "toggle_amazon_orders",
                            detail=detail(
                                "amazon_orders",
                                [
                                    part("Hardware Units", "Amazon_Hardware_Units"),
                                    part("Add-on Units", "Amazon_Addons_Units"),
                                ],
                                money=False,
                            ),
                            yoy=yoy("Amazon_Orders", prev_formatter=fmt_num),
                        ),
                        # No unit columns exist behind IndieGoGo, so this one has nothing
                        # to open into, unlike its neighbours.
                        summary_order(
                            "IndieGoGo Orders",
                            fmt_num(s.get("IndieGoGo_Orders", 0)),
                            "toggle_indiegogo_orders",
                            yoy=yoy("IndieGoGo_Orders", prev_formatter=fmt_num),
                        ),
                        class_="summary-orders-row three",
                    ),
                    ui.div(
                        summary_order(
                            "Digital Marketplaces Orders",
                            fmt_num(s.get("Digital_Marketplaces_Orders", 0)),
                            "toggle_digital_marketplaces_orders",
                            detail=detail(
                                "digital_marketplaces_orders",
                                [
                                    part("Rachio Orders", "Rachio_Orders"),
                                    part("Weatherflow Orders", "Weatherflow_Orders"),
                                ],
                                money=False,
                            ),
                            yoy=yoy("Digital_Marketplaces_Orders", prev_formatter=fmt_num),
                        ),
                        summary_order(
                            "Retail Orders",
                            fmt_num(s.get("B2B_Orders", 0)),
                            "toggle_b2b_orders",
                            detail=detail(
                                "b2b_orders",
                                [
                                    part("BestBuy Orders", "BestBuy_Orders"),
                                    part("Target Orders", "Target_Orders"),
                                    part("Walmart Orders", "Walmart_Orders"),
                                    part("Walmart Retail Orders", "Walmart_Retail_Orders"),
                                    part("Costco Orders", "Costco_Orders"),
                                    part("Chewy Orders", "Chewy_Orders"),
                                    part("Ace Hardware Orders", "Ace_Hardware_Orders"),
                                ],
                                money=False,
                            ),
                            yoy=yoy("B2B_Orders", prev_formatter=fmt_num),
                        ),
                        summary_order(
                            "App Orders",
                            fmt_num(s.get("App_Orders", 0)),
                            "toggle_app_orders",
                            detail=detail(
                                "app_orders",
                                [
                                    part("Apple Store Orders", "Apple_Store_Orders"),
                                    part("Google Store Orders", "Google_Store_Orders"),
                                ],
                                money=False,
                            ),
                            yoy=yoy("App_Orders", prev_formatter=fmt_num),
                        ),
                        class_="summary-orders-row three",
                    ),
                    class_="summary-orders",
                ),
                export_button("summary_cards"),
                class_="summary-page summary-export-area",
            ),
        )

    @render.ui
    def survey_layout():
        view = survey_view_state.get()
        available = [key for key in SURVEY_TITLES if survey_question_has_data(key)]
        if view == "All":
            if not available:
                return ui.div("No survey data for this date range.", class_="survey-empty-state")
            return ui.div(*(survey_card(key) for key in available), class_="survey-grid")
        if view not in available:
            return ui.div(
                ui.div(
                    ui.h3(SURVEY_TITLES[view]),
                    ui.input_action_button("back_all", "Back", class_="survey-action"),
                    class_="survey-card-head",
                ),
                ui.div("No survey data for this date range.", class_="survey-empty-copy"),
                class_="survey-wide-card",
            )
        return survey_wide_card(view)

    @render.ui
    def survey_timeline_sections():
        sections = []
        if survey_engagement_has_data():
            sections.append(section("Engagement Rate by Day", "q1_engagement_bar", height=400))
        sections.extend(
            section(SURVEY_TITLES[key], f"{key.lower()}_daily_stack", height=700)
            for key in SURVEY_TITLES
            if survey_question_has_data(key)
        )
        return ui.TagList(*sections)

    @render_widget
    def revenue_vs_spend_plot():
        df = revenue_view_filtered()
        if df.empty:
            return empty_fig("No revenue data for this range.")
        selected = input.selected_revenue_spend_type()
        mode = input.selected_view_mode()
        rev_col, spend_col = REVENUE_SPEND_SOURCES[selected]
        comp_on = bool(input.comparison_mode())

        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            w = source[["Date", rev_col]].copy()
            w["Revenue"] = w[rev_col]
            w["Spend"] = source[spend_col] if spend_col else 0
            w = w[["Date", "Revenue", "Spend"]]
            if input.viz_by_month():
                w = monthly_date(w).groupby("Date", as_index=False)[["Revenue", "Spend"]].sum()
            return w

        work = _prep(df)
        prev_work = None
        if comp_on:
            prev = revenue_prev_year_view().copy()
            if not prev.empty:
                prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                prev_work = _prep(prev)

        fig = go.Figure()
        if mode == "Absolute":
            if prev_work is not None and not prev_work.empty:
                fig.add_scatter(x=prev_work["Date"], y=prev_work["Revenue"], mode="lines", name="Revenue (prior)", line={"color": to_rgba(PALETTE["green"], 0.5), "width": 2, "dash": "dot"}, hovertemplate="Prior: $%{y:,.0f}<extra></extra>")
                if spend_col:
                    fig.add_scatter(x=prev_work["Date"], y=prev_work["Spend"], mode="lines", name="Spend (prior)", line={"color": to_rgba(PALETTE["red"], 0.5), "width": 2, "dash": "dot"}, hovertemplate="Prior: $%{y:,.0f}<extra></extra>")
            fig.add_scatter(x=work["Date"], y=work["Revenue"], mode="lines+markers", name="Revenue", line={"color": PALETTE["green"], "width": 3})
            if spend_col:
                fig.add_scatter(x=work["Date"], y=work["Spend"], mode="lines+markers", name="Spend", line={"color": PALETTE["red"], "width": 3})
            fig.update_yaxes(tickprefix="$")
        elif not spend_col:
            # Nothing to split revenue against, so say so rather than draw a full bar.
            return empty_fig(f"No spend is tracked for {REVENUE_SPEND_CHOICES[selected]}, so there is no split to show.")
        else:
            total = work["Revenue"] + work["Spend"]
            work["Revenue Share"] = np.where(total > 0, work["Revenue"] / total, 0)
            work["Spend Share"] = np.where(total > 0, work["Spend"] / total, 0)
            fig.add_scatter(x=work["Date"], y=work["Revenue Share"], mode="none", name="Revenue", stackgroup="one", fillcolor="rgba(46,204,113,.35)")
            fig.add_scatter(x=work["Date"], y=work["Spend Share"], mode="none", name="Spend", stackgroup="one", fillcolor="rgba(165,42,42,.35)")
            fig = finish_fig(fig, percent_y=True)
            return fig
        return finish_fig(fig)

    @render_widget
    def blended_roas_bar_chart():
        metric = input.selected_roas_type()
        mapping = {
            "Blended_ROAS": ("Total_Revenue", "Total_Spend"),
            "wROAS": ("DTC_Revenue", "Total_DTC_Spend"),
            "aROAS": ("Amazon_Revenue", "Amazon_Spend"),
            "appROAS": ("App_Revenue", "Total_App_Spend"),
        }
        num_col, den_col = mapping[metric]
        df = aggregate_sum(revenue_view_filtered(), [num_col, den_col], input.viz_by_month())
        if df.empty:
            return empty_fig("No ROAS data for this range.")
        df["Value"] = np.where(df[den_col] > 0, df[num_col] / df[den_col], np.nan)
        fig = go.Figure()
        if bool(input.comparison_mode()):
            prev = revenue_prev_year_view().copy()
            if not prev.empty:
                prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                prev_df = aggregate_sum(prev, [num_col, den_col], input.viz_by_month())
                if not prev_df.empty:
                    prev_df["Value"] = np.where(prev_df[den_col] > 0, prev_df[num_col] / prev_df[den_col], np.nan)
                    fig.add_scatter(x=prev_df["Date"], y=prev_df["Value"], mode="lines+markers", name="Prior year", line={"color": to_rgba(PALETTE["green"], 0.55), "width": 2, "dash": "dot"}, marker={"size": 5}, hovertemplate="Prior: %{y:.2f}<extra></extra>")
        fig.add_bar(x=df["Date"], y=df["Value"], marker_color=PALETTE["green"], name=metric.replace("_", " "))
        return finish_fig(fig)

    @render_widget
    def blended_SPU_bar_chart():
        metric = input.selected_SPU_type()

        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            w = source.copy()
            if w.empty:
                return w
            w["DTC_HW"] = w.get("DTC_Hardware_Units", 0)
            w["DTC_TOTAL_HW"] = w.get("DTC_Total_Hardware_Units", w["DTC_HW"])
            w["Amazon_HW"] = w.get("Amazon_Hardware_Units", 0)
            w["Blended_HW"] = w["DTC_TOTAL_HW"].fillna(0) + w["Amazon_HW"].fillna(0)
            cols = [
                "Total_Spend",
                "Total_DTC_Spend",
                "Amazon_Spend",
                "Total_App_Spend",
                "Blended_HW",
                "DTC_HW",
                "Amazon_HW",
                "App_Orders",
            ]
            if input.viz_by_month():
                w = monthly_date(w[["Date"] + cols]).groupby("Date", as_index=False)[cols].sum()
            w["Blended_SPU"] = np.where(w["Blended_HW"] > 0, w["Total_Spend"] / w["Blended_HW"], np.nan)
            w["wSPU"] = np.where(w["DTC_HW"] > 0, w["Total_DTC_Spend"] / w["DTC_HW"], np.nan)
            w["aSPU"] = np.where(w["Amazon_HW"] > 0, w["Amazon_Spend"] / w["Amazon_HW"], np.nan)
            w["appSPU"] = np.where(w["App_Orders"] > 0, w["Total_App_Spend"] / w["App_Orders"], np.nan)
            return w

        df = _prep(revenue_view_filtered())
        if df.empty:
            return empty_fig("No spend per unit data for this range.")
        fig = go.Figure()
        if bool(input.comparison_mode()):
            prev = revenue_prev_year_view().copy()
            if not prev.empty:
                prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                prev_df = _prep(prev)
                if not prev_df.empty:
                    fig.add_scatter(x=prev_df["Date"], y=prev_df[metric], mode="lines+markers", name="Prior year", line={"color": to_rgba(PALETTE["red"], 0.55), "width": 2, "dash": "dot"}, marker={"size": 5}, hovertemplate="Prior: $%{y:,.2f}<extra></extra>")
        fig.add_bar(x=df["Date"], y=df[metric], marker_color=PALETTE["red"], name=metric)
        fig.update_yaxes(tickprefix="$")
        return finish_fig(fig)

    @render_widget
    def cr_bar_chart():
        df = revenue_view_filtered()
        if df.empty or "Web_CR" not in df.columns:
            return empty_fig("No conversion rate data for this range.")

        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            if source.empty or "Web_CR" not in source.columns:
                return pd.DataFrame(columns=["Date", "CR"])
            if input.viz_by_month():
                rows = []
                for date, group in monthly_date(source).groupby("Date"):
                    rows.append({"Date": date, "CR": weighted_mean(group["Web_CR"], group.get("DTC_Orders", pd.Series(1, index=group.index)))})
                return pd.DataFrame(rows)
            return source[["Date", "Web_CR"]].rename(columns={"Web_CR": "CR"})

        plot = _prep(df)
        fig = go.Figure()
        if bool(input.comparison_mode()):
            prev = revenue_prev_year_view().copy()
            if not prev.empty:
                prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                prev_plot = _prep(prev)
                if not prev_plot.empty:
                    fig.add_scatter(x=prev_plot["Date"], y=prev_plot["CR"] * 100, mode="lines+markers", name="Prior year", line={"color": to_rgba(PALETTE["gray"], 0.6), "width": 2, "dash": "dot"}, marker={"size": 5}, hovertemplate="Prior: %{y:.2f}%<extra></extra>")
        fig.add_bar(x=plot["Date"], y=plot["CR"] * 100, marker_color=PALETTE["gray"], name="Conversion Rate")
        fig.update_yaxes(ticksuffix="%")
        return finish_fig(fig)

    @render_widget
    def aov_bar_chart():
        df = revenue_view_filtered()
        if df.empty:
            return empty_fig("No AOV data for this range.")

        segmented = input.selected_aov_type() == "Segmented_AOV"
        metric = input.selected_aov_type()

        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            if source.empty:
                return pd.DataFrame()
            if segmented:
                if input.viz_by_month():
                    rows = []
                    for date, group in monthly_date(source).groupby("Date"):
                        weights = group.get("DTC_Orders", pd.Series(1, index=group.index))
                        rows.append({"Date": date, "First-Time": weighted_mean(group["fAOV"], weights), "Returning": weighted_mean(group["rAOV"], weights)})
                    return pd.DataFrame(rows)
                return source[["Date", "fAOV", "rAOV"]].rename(columns={"fAOV": "First-Time", "rAOV": "Returning"})
            if input.viz_by_month():
                rows = []
                for date, group in monthly_date(source).groupby("Date"):
                    weights = group.get("DTC_Orders", pd.Series(1, index=group.index))
                    rows.append({"Date": date, "AOV": weighted_mean(group[metric], weights)})
                return pd.DataFrame(rows)
            return source[["Date", metric]].rename(columns={metric: "AOV"})

        plot = _prep(df)
        fig = go.Figure()
        prev_plot = None
        if bool(input.comparison_mode()):
            prev = revenue_prev_year_view().copy()
            if not prev.empty:
                prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                prev_plot = _prep(prev)

        if segmented:
            if prev_plot is not None and not prev_plot.empty:
                fig.add_scatter(x=prev_plot["Date"], y=prev_plot["First-Time"], mode="lines", name="First-Time (prior)", line={"color": to_rgba(PALETTE["blue"], 0.5), "width": 2, "dash": "dot"}, hovertemplate="Prior: $%{y:,.2f}<extra></extra>")
                fig.add_scatter(x=prev_plot["Date"], y=prev_plot["Returning"], mode="lines", name="Returning (prior)", line={"color": to_rgba(PALETTE["green"], 0.5), "width": 2, "dash": "dot"}, hovertemplate="Prior: $%{y:,.2f}<extra></extra>")
            fig.add_bar(x=plot["Date"], y=plot["First-Time"], name="First-Time", marker_color=PALETTE["blue"])
            fig.add_bar(x=plot["Date"], y=plot["Returning"], name="Returning", marker_color=PALETTE["green"])
            fig.update_layout(barmode="group")
        else:
            if prev_plot is not None and not prev_plot.empty:
                fig.add_scatter(x=prev_plot["Date"], y=prev_plot["AOV"], mode="lines+markers", name="Prior year", line={"color": to_rgba(PALETTE["blue"], 0.55), "width": 2, "dash": "dot"}, marker={"size": 5}, hovertemplate="Prior: $%{y:,.2f}<extra></extra>")
            fig.add_bar(x=plot["Date"], y=plot["AOV"], marker_color=PALETTE["blue"], name=metric.replace("_", " "))
        fig.update_yaxes(tickprefix="$")
        return finish_fig(fig)

    @render_widget
    def customer_split_chart():
        df = revenue_view_filtered()
        if df.empty or "Returning_Customers" not in df.columns or "First_Time_Customers" not in df.columns:
            return empty_fig("No customer split data for this range.")
        if input.viz_by_month():
            rows = []
            for date, group in monthly_date(df).groupby("Date"):
                weights = group.get("DTC_Orders", pd.Series(1, index=group.index))
                rows.append(
                    {
                        "Date": date,
                        "Returning": weighted_mean(group["Returning_Customers"], weights),
                        "First-Time": weighted_mean(group["First_Time_Customers"], weights),
                    }
                )
            plot = pd.DataFrame(rows)
        else:
            plot = df[["Date", "Returning_Customers", "First_Time_Customers"]].rename(
                columns={"Returning_Customers": "Returning", "First_Time_Customers": "First-Time"}
            )
        fig = go.Figure()
        fig.add_bar(x=plot["Date"], y=plot["First-Time"], name="First-Time", marker_color=PALETTE["blue"])
        fig.add_bar(x=plot["Date"], y=plot["Returning"], name="Returning", marker_color=PALETTE["green"])
        fig.update_layout(barmode="stack")
        return finish_fig(fig, percent_y=True)

    @render_widget
    def revenue_share_chart():
        sources = composition_bands(
            REVENUE_SHARE_COLS,
            bool(input.revenue_share_include_retail()),
            bool(input.revenue_share_include_app()),
        )
        cols = list(sources)
        view = revenue_view_filtered()
        df = aggregate_sum(view, cols, input.viz_by_month())
        if df.empty:
            return empty_fig("No revenue composition data for this range.")
        labels = {
            "DTC_Revenue": f"DTC ({dtc_region_label(input.dtc_region())})",
            "Amazon_Revenue": f"Amazon ({amazon_region_label(input.amazon_region())})",
            "IndieGoGo_Revenue": "IndieGoGo",
            "Digital_Marketplaces_Revenue": "Digital Marketplaces",
            "Retail_Revenue": retail_band_label(view),
            "App_Revenue": "App",
        }
        colors = list(sources.values())
        fig = go.Figure()
        if input.selected_revenue_view_mode() == "Absolute":
            if bool(input.comparison_mode()):
                prev = revenue_prev_year_view().copy()
                if not prev.empty:
                    prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                    prev_df = aggregate_sum(prev, cols, input.viz_by_month())
                    if not prev_df.empty:
                        for col, color in zip(cols, colors):
                            fig.add_scatter(x=prev_df["Date"], y=prev_df[col], mode="lines", name=f"{labels[col]} (prior)", line={"color": to_rgba(color, 0.5), "width": 2, "dash": "dot"}, hovertemplate="Prior: $%{y:,.0f}<extra></extra>")
            for col, color in zip(cols, colors):
                fig.add_scatter(x=df["Date"], y=df[col], mode="lines+markers", name=labels[col], line={"color": color, "width": 3})
            fig.update_yaxes(tickprefix="$")
        else:
            total = df[cols].sum(axis=1)
            for col, color in zip(cols, colors):
                share = np.where(total > 0, df[col] / total, 0)
                fig.add_scatter(x=df["Date"], y=share, mode="none", name=labels[col], stackgroup="one", fillcolor=color)
            return finish_fig(fig, percent_y=True)
        return finish_fig(fig)

    @render_widget
    def spend_composition_chart():
        sources = composition_bands(
            DTC_SPEND_COLS if input.selected_spend_composition() == "DTC" else TOTAL_SPEND_COLS,
            bool(input.spend_composition_include_retail()),
            bool(input.spend_composition_include_app()),
        )
        cols = list(sources)
        df = aggregate_sum(revenue_view_filtered(), cols, input.viz_by_month())
        if df.empty:
            return empty_fig("No spend composition data for this range.")
        fig = go.Figure()
        colors = list(sources.values())
        if input.selected_spend_view_mode() == "Absolute":
            if bool(input.comparison_mode()):
                prev = revenue_prev_year_view().copy()
                if not prev.empty:
                    prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
                    prev_df = aggregate_sum(prev, cols, input.viz_by_month())
                    if not prev_df.empty:
                        for idx, col in enumerate(cols):
                            fig.add_scatter(x=prev_df["Date"], y=prev_df[col], mode="lines", name=f"{col.replace('_', ' ')} (prior)", line={"color": to_rgba(colors[idx % len(colors)], 0.5), "width": 2, "dash": "dot"}, hovertemplate="Prior: $%{y:,.0f}<extra></extra>")
            for idx, col in enumerate(cols):
                fig.add_scatter(x=df["Date"], y=df[col], mode="lines+markers", name=col.replace("_", " "), line={"color": colors[idx % len(colors)], "width": 3})
            fig.update_yaxes(tickprefix="$")
        else:
            total = df[cols].sum(axis=1)
            for idx, col in enumerate(cols):
                share = np.where(total > 0, df[col] / total, 0)
                fig.add_scatter(x=df["Date"], y=share, mode="none", name=col.replace("_", " "), stackgroup="one", fillcolor=colors[idx % len(colors)])
            return finish_fig(fig, percent_y=True)
        return finish_fig(fig)

    @render.ui
    def pnl_view():
        df = revenue_view_filtered()
        comp_on = bool(input.comparison_mode())
        prev_df = revenue_prev_year_view() if comp_on else pd.DataFrame()
        unit_products, addon_products, seed_items = pnl_product_sets(pnl_mode())
        selected_channels = input.pnl_channels() or PNL_UNIT_CHANNELS
        if isinstance(selected_channels, str):
            selected_channels = [selected_channels]
        unit_display_channels = [channel for channel in PNL_UNIT_CHANNELS if channel in selected_channels] or PNL_UNIT_CHANNELS
        addon_display_channels = [channel for channel in PNL_ADDON_CHANNELS if channel in unit_display_channels] or PNL_ADDON_CHANNELS
        sku_counts = product_counts(df, unit_products, unit_display_channels)
        addon_counts = product_counts(df, addon_products, addon_display_channels)
        sub_counts = product_counts(df, APP_SUB_PRODUCTS, ["DTC", "Apple", "Google"])
        prev_sku_counts = product_counts(prev_df, unit_products, unit_display_channels) if comp_on else None
        prev_addon_counts = product_counts(prev_df, addon_products, addon_display_channels) if comp_on else None
        prev_sub_counts = product_counts(prev_df, APP_SUB_PRODUCTS, ["DTC", "Apple", "Google"]) if comp_on else None

        # Every section is measured against the same denominator: the feeder units that
        # channel sold, taken from the hardware counts already on screen so the hardware
        # mix adds to exactly the 100% its own total row shows.
        sku_mix = bool(input.pnl_sku_mix())
        mix_base = hardware_base(sku_counts) if sku_mix else None
        prev_mix_base = hardware_base(prev_sku_counts) if sku_mix and prev_sku_counts else None

        seed_counts = product_counts(df, seed_items, ["DTC"])
        gift_bag_counts = product_counts(df, GIFT_BAG_PRODUCTS, ["DTC"])
        prev_seed_counts = product_counts(prev_df, seed_items, ["DTC"]) if comp_on else None
        prev_gift_bag_counts = product_counts(prev_df, GIFT_BAG_PRODUCTS, ["DTC"]) if comp_on else None
        return ui.div(
            build_product_section(
                "Units Sold (Gross)",
                unit_products,
                sku_counts,
                unit_display_channels,
                export_id="pnl_units",
                prev_counts=prev_sku_counts,
                mix_base=mix_base,
                prev_mix_base=prev_mix_base,
            ),
            build_product_section("Add-ons Sold (Gross)", addon_products, addon_counts, addon_display_channels, export_id="pnl_addons", prev_counts=prev_addon_counts, mix_base=mix_base, prev_mix_base=prev_mix_base),
            build_product_section("App Subscriptions", APP_SUB_PRODUCTS, sub_counts, ["DTC", "Apple", "Google"], export_id="pnl_app_subscriptions", prev_counts=prev_sub_counts, mix_base=mix_base, prev_mix_base=prev_mix_base),
            build_product_section("Seeds Sold (Gross)", seed_items, seed_counts, ["DTC"], show_all=False, values_width=150, export_id="pnl_seeds", prev_counts=prev_seed_counts, mix_base=mix_base, prev_mix_base=prev_mix_base),
            build_product_section("Gift Bags Sold (Gross)", GIFT_BAG_PRODUCTS, gift_bag_counts, ["DTC"], show_all=False, values_width=150, export_id="pnl_gift_bag", prev_counts=prev_gift_bag_counts, mix_base=mix_base, prev_mix_base=prev_mix_base),
            class_="pnl-page",
        )

    def units_bucket(df: pd.DataFrame, by_month: bool) -> pd.DataFrame:
        work = df[["Date"]].copy()
        base_channels = ["DTC", "Amazon", *PNL_DIGITAL_CHANNELS, *PNL_RETAIL_CHANNELS]
        for channel in base_channels:
            work[f"Units_{channel}"] = sum_cols(df, [col for p in SKU_PRODUCTS for col in product_cols_for_channel(p, channel)])
            work[f"Addons_{channel}"] = sum_cols(df, [col for p in ADDON_PRODUCTS for col in product_cols_for_channel(p, channel)])
        work["Units_Digital"] = sum_cols(df, [col for p in SKU_PRODUCTS for col in product_cols_for_channel(p, "Digital")])
        work["Units_Retail"] = sum_cols(df, [col for p in SKU_PRODUCTS for col in product_cols_for_channel(p, "Retail")])
        work["Addons_Digital"] = sum_cols(df, [col for p in ADDON_PRODUCTS for col in product_cols_for_channel(p, "Digital")])
        work["Addons_Retail"] = sum_cols(df, [col for p in ADDON_PRODUCTS for col in product_cols_for_channel(p, "Retail")])
        work["Seeds_DTC"] = sum_cols(df, [col for _, _, _, cols in SEED_PRODUCTS for col in cols])
        for channel in ["Amazon", *PNL_DIGITAL_CHANNELS, *PNL_RETAIL_CHANNELS, "Digital", "Retail"]:
            work[f"Seeds_{channel}"] = 0
        if by_month:
            value_cols = [c for c in work.columns if c != "Date"]
            work = monthly_date(work).groupby("Date", as_index=False)[value_cols].sum()
        return work

    def aligned_prior_year() -> pd.DataFrame:
        """Return the selected prior-year window on the current chart's x-axis."""
        prev = revenue_prev_year_view().copy()
        if not prev.empty:
            prev["Date"] = prev["Date"] + pd.DateOffset(years=1)
        return prev

    @render_widget
    def units_ua_plot():
        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            df = units_bucket(source, input.viz_by_month())
            channel = input.units_ua_channel()
            cats = ["Units", "Addons"] + (["Seeds"] if input.units_include_seeds() and channel in ["All", "DTC"] else [])
            plot = pd.DataFrame({"Date": df["Date"]})
            for cat in cats:
                if channel == "All":
                    total = pd.Series(0, index=df.index, dtype="float64")
                    for group in PNL_ROLLUP_CHANNELS:
                        total = total + df.get(f"{cat}_{group}", 0)
                    plot[cat] = total
                else:
                    plot[cat] = df.get(f"{cat}_{channel}", 0)
            return plot

        df = _prep(revenue_view_filtered())
        if df.empty:
            return empty_fig("No unit data for this range.", 760)
        channel = input.units_ua_channel()
        cats = ["Units", "Addons"] + (["Seeds"] if input.units_include_seeds() and channel in ["All", "DTC"] else [])
        prev = _prep(aligned_prior_year()) if input.comparison_mode() else None
        return grouped_or_relative(df, cats, input.units_ua_view(), input.units_line_view(), 800, ["#2ecc71", "#3498db", "#f39c12"], prev)

    def product_time_series(
        products: Sequence[dict],
        channel: str,
        by_month: bool,
        mode: str = "type",
        source: Optional[pd.DataFrame] = None,
    ) -> pd.DataFrame:
        df = revenue_view_filtered() if source is None else source
        out = df[["Date"]].copy()
        if mode in {"family", "type"}:
            buckets = SKU_FAMILY_BUCKETS if mode == "family" else SKU_TYPE_BUCKETS
            product_map = {p["name"]: p for p in products}
            for label, names in buckets.items():
                cols: List[str] = []
                for name in names:
                    product = product_map[name]
                    cols.extend(product_cols_for_channel(product, channel))
                out[label] = sum_cols(df, cols)
        else:
            for product in products:
                cols = product_cols_for_channel(product, channel)
                out[product["name"]] = sum_cols(df, cols)
        if by_month:
            value_cols = [c for c in out.columns if c != "Date"]
            out = monthly_date(out).groupby("Date", as_index=False)[value_cols].sum()
        return out

    def grouped_or_relative(
        df: pd.DataFrame,
        cats: Sequence[str],
        view: str,
        line: bool,
        height: int,
        colors: Sequence[str],
        prior: Optional[pd.DataFrame] = None,
    ) -> go.Figure:
        if df.empty:
            return empty_fig("No data for this range.", height)
        fig = go.Figure()
        cats = [cat for cat in cats if cat in df.columns]
        if not cats:
            return empty_fig("No columns found for this view.", height)
        if view == "Relative":
            total = df[cats].sum(axis=1)
            for idx, cat in enumerate(cats):
                fig.add_bar(x=df["Date"], y=np.where(total > 0, df[cat] / total, 0), name=cat, marker_color=colors[idx % len(colors)])
            if prior is not None and not prior.empty:
                prior_cats = [cat for cat in cats if cat in prior.columns]
                prior_total = prior[prior_cats].sum(axis=1)
                for idx, cat in enumerate(cats):
                    if cat not in prior_cats:
                        continue
                    fig.add_scatter(
                        x=prior["Date"],
                        y=np.where(prior_total > 0, prior[cat] / prior_total, 0),
                        mode="lines",
                        name=f"{cat} (prior year)",
                        line={"color": to_rgba(colors[idx % len(colors)], 0.7), "width": 2, "dash": "dot"},
                        hovertemplate="Prior year: %{y:.1%}<extra></extra>",
                    )
            fig.update_layout(barmode="stack")
            return finish_fig(fig, height=height, percent_y=True)
        for idx, cat in enumerate(cats):
            if line:
                fig.add_scatter(x=df["Date"], y=df[cat], mode="lines+markers", name=cat, line={"color": colors[idx % len(colors)], "width": 3})
            else:
                fig.add_bar(x=df["Date"], y=df[cat], name=cat, marker_color=colors[idx % len(colors)])
        if prior is not None and not prior.empty:
            for idx, cat in enumerate(cats):
                if cat not in prior.columns:
                    continue
                fig.add_scatter(
                    x=prior["Date"],
                    y=prior[cat],
                    mode="lines",
                    name=f"{cat} (prior year)",
                    line={"color": to_rgba(colors[idx % len(colors)], 0.7), "width": 2, "dash": "dot"},
                    hovertemplate="Prior year: %{y:,.0f}<extra></extra>",
                )
        if not line:
            fig.update_layout(barmode="group")
        return finish_fig(fig, height=height)

    @render_widget
    def sku_plot():
        df = product_time_series(SKU_PRODUCTS, input.sku_channel(), input.viz_by_month(), mode=sku_group_mode())
        cats = [c for c in df.columns if c != "Date"]
        colors = [PALETTE["green"], PALETTE["blue"], PALETTE["yellow"], PALETTE["red"], PALETTE["purple"], PALETTE["gray"]]
        prev = product_time_series(SKU_PRODUCTS, input.sku_channel(), input.viz_by_month(), mode=sku_group_mode(), source=aligned_prior_year()) if input.comparison_mode() else None
        return grouped_or_relative(df, cats, input.sku_view(), input.sku_line_view(), 800, colors, prev)

    @render_widget
    def addon_plot():
        by_colour = bool(input.by_colour_addon())
        channel = input.addon_channel()
        if by_colour:
            products = ADDON_PRODUCTS
        else:
            products = ADDON_SUMMARY_PRODUCTS

        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            out = source[["Date"]].copy()
            for product in products:
                cols = product_cols_for_channel(product, channel)
                out[product["name"]] = sum_cols(source, cols)
            if input.viz_by_month():
                value_cols = [c for c in out.columns if c != "Date"]
                out = monthly_date(out).groupby("Date", as_index=False)[value_cols].sum()
            return out

        out = _prep(revenue_view_filtered())
        cats = [c for c in out.columns if c != "Date"]
        prev = _prep(aligned_prior_year()) if input.comparison_mode() else None
        return grouped_or_relative(out, cats, input.addon_view(), input.addon_line_view(), 800, SET2, prev)

    @render_widget
    def seed_plot():
        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            out = source[["Date"]].copy()
            if input.seed_by_weight():
                for name, _, _, cols in SEED_PRODUCTS:
                    out[name] = sum_cols(source, cols)
            else:
                buckets = {
                    "Seasonal Curation": ["dtc_Seasonal Curation - 8lb", "dtc_Seasonal Curation - 20lb"],
                    "Buddy Bites": ["dtc_Buddy Bites - 8lb", "dtc_Buddy Bites - 20lb"],
                    "Snack n' Soar": ["dtc_Snack n' Soar - 8lb", "dtc_Snack n' Soar - 20lb"],
                    "Avian Choice": ["dtc_Avian Choice - 8lb", "dtc_Avian Choice - 20lb"],
                }
                for name, cols in buckets.items():
                    out[name] = sum_cols(source, cols)
            if input.viz_by_month():
                value_cols = [c for c in out.columns if c != "Date"]
                out = monthly_date(out).groupby("Date", as_index=False)[value_cols].sum()
            return out

        out = _prep(revenue_view_filtered())
        cats = [c for c in out.columns if c != "Date"]
        prev = _prep(aligned_prior_year()) if input.comparison_mode() else None
        return grouped_or_relative(out, cats, input.seed_view_mode(), input.seed_line_view(), 700, SET2, prev)

    @render_widget
    def app_subs_by_channel_plot():
        channel = input.appsubs_channel()

        def _prep(source: pd.DataFrame) -> pd.DataFrame:
            out = source[["Date"]].copy()
            monthly = pd.Series(0, index=source.index, dtype="float64")
            yearly = pd.Series(0, index=source.index, dtype="float64")
            if channel in ["All", "Apple"]:
                monthly = monthly + sum_cols(source, ["apple_monthly_sub"])
                yearly = yearly + sum_cols(source, ["apple_yearly_sub"])
            if channel in ["All", "Google"]:
                monthly = monthly + sum_cols(source, ["google_monthly_sub"])
                yearly = yearly + sum_cols(source, ["google_yearly_sub"])
            if channel in ["All", "DTC"]:
                yearly = yearly + sum_cols(source, ["DTC_Subscription_Units"])
            out["Monthly"] = monthly
            out["Yearly"] = yearly
            if input.viz_by_month():
                out = monthly_date(out).groupby("Date", as_index=False)[["Monthly", "Yearly"]].sum()
            return out

        out = _prep(revenue_view_filtered())
        prev = _prep(aligned_prior_year()) if input.comparison_mode() else None
        return grouped_or_relative(out, ["Monthly", "Yearly"], input.appsubs_view(), input.appsubs_line_view(), 520, ["#C8A2C8", PALETTE["yellow"]], prev)

    @render.text
    def overview_title():
        df = survey_filtered()
        rev = revenue_view_filtered()
        engagement = engagement_frame(df, rev, input.viz_by_month())
        participants = engagement["Participants"].sum() if not engagement.empty else 0.0
        denominator = engagement["Denominator"].sum() if not engagement.empty else 0.0
        rate = safe_div(participants, denominator)
        rate_text = f"{rate * 100:.1f}%" if not pd.isna(rate) else "0.0%"
        return f"Overview (Engagement Rate: {rate_text})"

    @render_widget
    def q1_pie_chart():
        return pie_from_columns(survey_filtered(), "q1", input.survey_segment(), height=520 if survey_view_state.get() == "Q1" else 360)

    @render_widget
    def q2_pie_chart():
        return pie_from_columns(survey_filtered(), "q2", input.survey_segment(), height=520 if survey_view_state.get() == "Q2" else 360)

    @render_widget
    def q3_pie_chart():
        return pie_from_columns(survey_filtered(), "q3", input.survey_segment(), height=520 if survey_view_state.get() == "Q3" else 360)

    @render_widget
    def q4_pie_chart():
        return pie_from_columns(survey_filtered(), "q4", "all", height=520 if survey_view_state.get() == "Q4" else 360)

    @render_widget
    def q5_pie_chart():
        return pie_from_columns(survey_filtered(), "q5", "all", height=520 if survey_view_state.get() == "Q5" else 360)

    @render_widget
    def q6_pie_chart():
        return pie_from_columns(survey_filtered(), "q6", "all", height=520 if survey_view_state.get() == "Q6" else 360)

    @render_widget
    def q7_pie_chart():
        return pie_from_columns(survey_filtered(), "q7", "all", height=520 if survey_view_state.get() == "Q7" else 360)

    @render_widget
    def q8_pie_chart():
        return pie_from_columns(survey_filtered(), "q8", "all", height=520 if survey_view_state.get() == "Q8" else 360)

    @render_widget
    def q9_pie_chart():
        return pie_from_columns(survey_filtered(), "q9", "all", height=520 if survey_view_state.get() == "Q9" else 360)

    @render_widget
    def q10_pie_chart():
        return pie_from_columns(survey_filtered(), "q10", "all", height=520 if survey_view_state.get() == "Q10" else 360)

    @render_widget
    def q11_pie_chart():
        return pie_from_columns(survey_filtered(), "q11", "all", height=520 if survey_view_state.get() == "Q11" else 360)

    @render_widget
    def q12_pie_chart():
        return pie_from_columns(survey_filtered(), "q12", "all", height=520 if survey_view_state.get() == "Q12" else 360)

    @render_widget
    def q13_pie_chart():
        return pie_from_columns(survey_filtered(), "q13", "all", height=520 if survey_view_state.get() == "Q13" else 360)

    @render_widget
    def q14_pie_chart():
        return pie_from_columns(survey_filtered(), "q14", "all", height=520 if survey_view_state.get() == "Q14" else 360)

    @render_widget
    def q15_pie_chart():
        return pie_from_columns(survey_filtered(), "q15", "all", height=520 if survey_view_state.get() == "Q15" else 360)

    @render_widget
    def q1_engagement_bar():
        df = survey_filtered()
        rev = revenue_view_filtered()
        if df.empty:
            return empty_fig("No survey engagement data for this range.", 400)
        plot = engagement_frame(df, rev, input.viz_by_month())
        if plot.empty:
            return empty_fig("No survey engagement data for this range.", 400)
        if input.survey_line_view():
            hover_x = "%{x|%b %Y}" if input.viz_by_month() else "%{x|%b %d, %Y}"
            fig = go.Figure(
                go.Scatter(
                    x=plot["Date"],
                    y=plot["Rate"],
                    mode="lines",
                    line={"color": PALETTE["green"], "width": 2.5},
                    name="Engagement Rate",
                    hovertemplate=f"{hover_x}<br>Engagement Rate: %{{y:.1%}}<extra></extra>",
                )
            )
        else:
            fig = go.Figure(go.Bar(x=plot["Date"], y=plot["Rate"], marker_color=PALETTE["green"], name="Engagement Rate"))
        return finish_fig(fig, height=400, percent_y=True)

    @render_widget
    def q1_daily_stack():
        return stacked_survey(survey_filtered(), "q1", input.survey_segment(), input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q2_daily_stack():
        return stacked_survey(survey_filtered(), "q2", input.survey_segment(), input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q3_daily_stack():
        return stacked_survey(survey_filtered(), "q3", input.survey_segment(), input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q4_daily_stack():
        return stacked_survey(survey_filtered(), "q4", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q5_daily_stack():
        return stacked_survey(survey_filtered(), "q5", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q6_daily_stack():
        return stacked_survey(survey_filtered(), "q6", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q7_daily_stack():
        return stacked_survey(survey_filtered(), "q7", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q8_daily_stack():
        return stacked_survey(survey_filtered(), "q8", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q9_daily_stack():
        return stacked_survey(survey_filtered(), "q9", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q10_daily_stack():
        return stacked_survey(survey_filtered(), "q10", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q11_daily_stack():
        return stacked_survey(survey_filtered(), "q11", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q12_daily_stack():
        return stacked_survey(survey_filtered(), "q12", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q13_daily_stack():
        return stacked_survey(survey_filtered(), "q13", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q14_daily_stack():
        return stacked_survey(survey_filtered(), "q14", "all", input.viz_by_month(), input.survey_line_view())

    @render_widget
    def q15_daily_stack():
        return stacked_survey(survey_filtered(), "q15", "all", input.viz_by_month(), input.survey_line_view())

    @render.download(filename=lambda: csv_filename("summary"), media_type="text/csv")
    def download_summary_cards():
        yield csv_text(export_data("summary_cards"))

    @render.download(filename=lambda: csv_filename("pnl_units"), media_type="text/csv")
    def download_pnl_units():
        yield csv_text(export_data("pnl_units"))

    @render.download(filename=lambda: csv_filename("pnl_addons"), media_type="text/csv")
    def download_pnl_addons():
        yield csv_text(export_data("pnl_addons"))

    @render.download(filename=lambda: csv_filename("pnl_app_subscriptions"), media_type="text/csv")
    def download_pnl_app_subscriptions():
        yield csv_text(export_data("pnl_app_subscriptions"))

    @render.download(filename=lambda: csv_filename("pnl_seeds"), media_type="text/csv")
    def download_pnl_seeds():
        yield csv_text(export_data("pnl_seeds"))

    @render.download(filename=lambda: csv_filename("revenue_vs_spend"), media_type="text/csv")
    def download_revenue_vs_spend_plot():
        yield csv_text(export_data("revenue_vs_spend_plot"))

    @render.download(filename=lambda: csv_filename("roas"), media_type="text/csv")
    def download_blended_roas_bar_chart():
        yield csv_text(export_data("blended_roas_bar_chart"))

    @render.download(filename=lambda: csv_filename("spend_per_unit"), media_type="text/csv")
    def download_blended_SPU_bar_chart():
        yield csv_text(export_data("blended_SPU_bar_chart"))

    @render.download(filename=lambda: csv_filename("conversion_rate"), media_type="text/csv")
    def download_cr_bar_chart():
        yield csv_text(export_data("cr_bar_chart"))

    @render.download(filename=lambda: csv_filename("aov"), media_type="text/csv")
    def download_aov_bar_chart():
        yield csv_text(export_data("aov_bar_chart"))

    @render.download(filename=lambda: csv_filename("customer_split"), media_type="text/csv")
    def download_customer_split_chart():
        yield csv_text(export_data("customer_split_chart"))

    @render.download(filename=lambda: csv_filename("revenue_composition"), media_type="text/csv")
    def download_revenue_share_chart():
        yield csv_text(export_data("revenue_share_chart"))

    @render.download(filename=lambda: csv_filename("spend_composition"), media_type="text/csv")
    def download_spend_composition_chart():
        yield csv_text(export_data("spend_composition_chart"))

    @render.download(filename=lambda: csv_filename("units_addons_seeds"), media_type="text/csv")
    def download_units_ua_plot():
        yield csv_text(export_data("units_ua_plot"))

    @render.download(filename=lambda: csv_filename("unit_count"), media_type="text/csv")
    def download_sku_plot():
        yield csv_text(export_data("sku_plot"))

    @render.download(filename=lambda: csv_filename("addon_count"), media_type="text/csv")
    def download_addon_plot():
        yield csv_text(export_data("addon_plot"))

    @render.download(filename=lambda: csv_filename("unit_count_sku"), media_type="text/csv")
    def download_sku_plot_sku():
        yield csv_text(export_data("sku_plot", by_sku=True))

    @render.download(filename=lambda: csv_filename("addon_count_sku"), media_type="text/csv")
    def download_addon_plot_sku():
        yield csv_text(export_data("addon_plot", by_sku=True))

    @render.download(filename=lambda: csv_filename("seed_count_sku"), media_type="text/csv")
    def download_seed_plot_sku():
        yield csv_text(export_data("seed_plot", by_sku=True))

    @render.download(filename=lambda: csv_filename("seed_count"), media_type="text/csv")
    def download_seed_plot():
        yield csv_text(export_data("seed_plot"))

    @render.download(filename=lambda: csv_filename("app_subscriptions"), media_type="text/csv")
    def download_app_subs_by_channel_plot():
        yield csv_text(export_data("app_subs_by_channel_plot"))

    @render.download(filename=lambda: csv_filename("survey_q1_pie"), media_type="text/csv")
    def download_q1_pie_chart():
        yield csv_text(export_data("q1_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q2_pie"), media_type="text/csv")
    def download_q2_pie_chart():
        yield csv_text(export_data("q2_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q3_pie"), media_type="text/csv")
    def download_q3_pie_chart():
        yield csv_text(export_data("q3_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q4_pie"), media_type="text/csv")
    def download_q4_pie_chart():
        yield csv_text(export_data("q4_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q5_pie"), media_type="text/csv")
    def download_q5_pie_chart():
        yield csv_text(export_data("q5_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q6_pie"), media_type="text/csv")
    def download_q6_pie_chart():
        yield csv_text(export_data("q6_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q7_pie"), media_type="text/csv")
    def download_q7_pie_chart():
        yield csv_text(export_data("q7_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q8_pie"), media_type="text/csv")
    def download_q8_pie_chart():
        yield csv_text(export_data("q8_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q9_pie"), media_type="text/csv")
    def download_q9_pie_chart():
        yield csv_text(export_data("q9_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q10_pie"), media_type="text/csv")
    def download_q10_pie_chart():
        yield csv_text(export_data("q10_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q11_pie"), media_type="text/csv")
    def download_q11_pie_chart():
        yield csv_text(export_data("q11_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q12_pie"), media_type="text/csv")
    def download_q12_pie_chart():
        yield csv_text(export_data("q12_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q13_pie"), media_type="text/csv")
    def download_q13_pie_chart():
        yield csv_text(export_data("q13_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q14_pie"), media_type="text/csv")
    def download_q14_pie_chart():
        yield csv_text(export_data("q14_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_q15_pie"), media_type="text/csv")
    def download_q15_pie_chart():
        yield csv_text(export_data("q15_pie_chart"))

    @render.download(filename=lambda: csv_filename("survey_engagement_rate"), media_type="text/csv")
    def download_q1_engagement_bar():
        yield csv_text(export_data("q1_engagement_bar"))

    @render.download(filename=lambda: csv_filename("survey_q1_daily"), media_type="text/csv")
    def download_q1_daily_stack():
        yield csv_text(export_data("q1_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q2_daily"), media_type="text/csv")
    def download_q2_daily_stack():
        yield csv_text(export_data("q2_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q3_daily"), media_type="text/csv")
    def download_q3_daily_stack():
        yield csv_text(export_data("q3_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q4_daily"), media_type="text/csv")
    def download_q4_daily_stack():
        yield csv_text(export_data("q4_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q5_daily"), media_type="text/csv")
    def download_q5_daily_stack():
        yield csv_text(export_data("q5_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q6_daily"), media_type="text/csv")
    def download_q6_daily_stack():
        yield csv_text(export_data("q6_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q7_daily"), media_type="text/csv")
    def download_q7_daily_stack():
        yield csv_text(export_data("q7_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q8_daily"), media_type="text/csv")
    def download_q8_daily_stack():
        yield csv_text(export_data("q8_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q9_daily"), media_type="text/csv")
    def download_q9_daily_stack():
        yield csv_text(export_data("q9_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q10_daily"), media_type="text/csv")
    def download_q10_daily_stack():
        yield csv_text(export_data("q10_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q11_daily"), media_type="text/csv")
    def download_q11_daily_stack():
        yield csv_text(export_data("q11_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q12_daily"), media_type="text/csv")
    def download_q12_daily_stack():
        yield csv_text(export_data("q12_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q13_daily"), media_type="text/csv")
    def download_q13_daily_stack():
        yield csv_text(export_data("q13_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q14_daily"), media_type="text/csv")
    def download_q14_daily_stack():
        yield csv_text(export_data("q14_daily_stack"))

    @render.download(filename=lambda: csv_filename("survey_q15_daily"), media_type="text/csv")
    def download_q15_daily_stack():
        yield csv_text(export_data("q15_daily_stack"))


class BasicAuthMiddleware:
    def __init__(self, app, username: str, password: str):
        self.app = app
        self.username = username
        self.password = password

    def _authorized(self, headers: Iterable[tuple[bytes, bytes]]) -> bool:
        auth_header = ""
        for key, value in headers:
            if key.lower() == b"authorization":
                auth_header = value.decode("latin1")
                break
        if not auth_header.startswith("Basic "):
            return False
        try:
            decoded = base64.b64decode(auth_header[6:], validate=True).decode("utf-8")
        except Exception:
            return False
        username, _, password = decoded.partition(":")
        return secrets.compare_digest(username, self.username) and secrets.compare_digest(password, self.password)

    async def __call__(self, scope, receive, send):
        if scope["type"] not in {"http", "websocket"} or self._authorized(scope.get("headers", [])):
            await self.app(scope, receive, send)
            return
        if scope["type"] == "websocket":
            await send({"type": "websocket.close", "code": 1008})
            return
        await send(
            {
                "type": "http.response.start",
                "status": 401,
                "headers": [
                    (b"www-authenticate", b'Basic realm="Bird Buddy Dashboard"'),
                    (b"content-type", b"text/plain; charset=utf-8"),
                ],
            }
        )
        await send({"type": "http.response.body", "body": b"Authentication required"})


app = App(app_ui, server, static_assets=ROOT / "www")
share_password = os.getenv("BIRD_BUDDY_APP_PASSWORD")
if share_password:
    app.starlette_app.add_middleware(
        BasicAuthMiddleware,
        username=os.getenv("BIRD_BUDDY_APP_USERNAME", "birdbuddy"),
        password=share_password,
    )

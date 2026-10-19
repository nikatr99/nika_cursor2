"""Guards against a SKU reaching the workbooks but never reaching the dashboard.

This has happened twice. The hardware-unit line stopped counting SKUs launched from
February 2025 and nothing failed, it just moved every per-unit rate. Then Target began
selling the Birdbuddy Nook and the retail sync dropped the column without a word,
because an unmapped SKU was skipped silently.

Both were invisible for the same reason: a missing product looks like an absent row,
not like an error. These tests turn that into a failure.
"""

import sys
from pathlib import Path

import pandas as pd
import pytest

import app

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

CHANNEL_PREFIXES = (
    "dtc_", "amazon_", "target_", "bestbuy_", "chewy_", "walmart_",
    "walmart_retail_", "costco_", "ace_hardware_", "huckberry_",
    "rachio_", "weatherflow_",
)
# Regional splits are derived from the base column, so checking the base covers them.
DERIVED_PREFIXES = ("dtc_us_", "dtc_eu_", "amazon_us_", "amazon_eu_")


def dashboard_columns() -> set[str]:
    """Every product column some section of the P&L actually reports."""
    cols: set[str] = set()
    groups = [app.SKU_PRODUCTS, app.ADDON_PRODUCTS, app.APP_SUB_PRODUCTS,
              app.GIFT_BAG_PRODUCTS, app.pnl_seed_items()]
    for group in groups:
        for product in group:
            for channel_cols in product["cols"].values():
                cols.update(channel_cols)
    return cols


def product_columns_with_volume() -> list[str]:
    df = app.revenue_data
    out = []
    for col in df.columns:
        if not col.startswith(CHANNEL_PREFIXES) or col.startswith(DERIVED_PREFIXES):
            continue
        if pd.to_numeric(df[col], errors="coerce").fillna(0).abs().sum() > 0:
            out.append(col)
    return out


def test_every_selling_product_column_is_on_the_dashboard():
    """The invariant: if a product has ever sold, some P&L row reports it.

    A column that exists but has never sold is fine - the sync creates those for
    products not yet launched. The moment one takes its first order, it has to be
    attached to a product or this fails.
    """
    unclaimed = sorted(set(product_columns_with_volume()) - dashboard_columns())
    assert not unclaimed, (
        "these product columns carry volume but no P&L row reports them:\n  "
        + "\n  ".join(unclaimed)
        + "\n\nAdd each to SKU_PRODUCTS, ADDON_PRODUCTS or SEED_PRODUCTS in App_py/app.py."
    )


def test_every_retail_workbook_sku_is_mapped():
    """Catches a new retail SKU in the workbook before it ever sells a unit.

    Reads the sell-through workbook directly, so a SKU added at Target or Best Buy
    fails here on the next test run rather than quietly producing no column.
    """
    from openpyxl import load_workbook

    import sync_retail_sellthrough as retail

    workbook = retail.DEFAULT_WORKBOOK
    if not workbook.exists():
        pytest.skip(f"retail workbook not present at {workbook}")

    wb = load_workbook(workbook, read_only=True, data_only=True)
    try:
        ws = wb["SKU MIX (by channel by sku)"]
        rows = list(ws.iter_rows(min_row=1, max_row=3, values_only=True))
    finally:
        wb.close()

    channels, names, skus = rows[0], rows[1], rows[2]
    current = ""
    unmapped: list[str] = []
    walked: list[str] = []
    # Column 0 is the sheet's own "Date" header; the sync starts at column 2 for the
    # same reason. Starting at 0 made this walk zero SKUs and pass no matter what.
    for i, raw_sku in enumerate(skus):
        if i == 0:
            continue
        if i < len(channels) and channels[i]:
            current = str(channels[i]).strip()
        if current == "Date":
            break
        if current not in retail.SKU_CHANNEL_PREFIX:
            continue
        sku = retail.clean_sku(raw_sku)
        if not sku:
            continue
        walked.append(sku)
        if sku in retail.SKU_MAP or sku in retail.SKU_UNMAPPED_KNOWN:
            continue
        name = str(names[i]).strip() if i < len(names) and names[i] else "unnamed"
        unmapped.append(f"{current} / {sku} ({name})")

    assert walked, "walked no SKU columns at all - the sheet layout changed and this guard is blind"
    assert not unmapped, (
        "the retail workbook reports SKUs the dashboard has no product for:\n  "
        + "\n  ".join(sorted(set(unmapped)))
        + "\n\nAdd each to SKU_MAP in scripts/sync_retail_sellthrough.py, or to "
          "SKU_UNMAPPED_KNOWN once deliberately excluded."
    )


def test_retail_sku_map_points_at_real_columns():
    """A map entry naming a product the sync never writes would import nothing."""
    import sync_retail_sellthrough as retail

    columns = set(app.revenue_data.columns)
    broken = []
    for sku, product in retail.SKU_MAP.items():
        if not any(f"{prefix}_{product}" in columns for prefix in set(retail.SKU_CHANNEL_PREFIX.values())):
            broken.append(f"{sku} -> {product}")
    assert not broken, "SKU_MAP entries that match no retail column:\n  " + "\n  ".join(broken)


def test_every_product_image_exists():
    """A product whose image is missing renders a broken tile on the P&L."""
    www = ROOT / "App_py" / "www"
    groups = [app.SKU_PRODUCTS, app.ADDON_PRODUCTS, app.APP_SUB_PRODUCTS,
              app.GIFT_BAG_PRODUCTS, app.pnl_seed_items()]
    missing = sorted(
        {
            f"{product['name']} -> {product['image']}"
            for group in groups
            for product in group
            if product.get("image") and not (www / product["image"]).exists()
        }
    )
    assert not missing, "products pointing at images that are not in App_py/www:\n  " + "\n  ".join(missing)

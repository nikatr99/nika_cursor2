"""The P&L product line-ups: raw SKUs, the default merge, and the SBF/HBF families."""

import pytest

import app


FAMILY_UNITS = [
    "SBF",
    "SBF w Solar Roof",
    "SBF w Solar Roof + Perch Extender (Retail)",
    "HBF",
    "HBF w Solar Roof",
    "HBF w Solar Roof + extra base&flower ports (Retail)",
    "Nook",
    "Nook w Solar Roof",
    "Nook + Bird Anatomy book (Learning Bundle)",
    "Nature Cam PRO",
]

FAMILY_ADDONS = [
    "SBF Solar Roof",
    "Wall Mount",
    "Suet Ball Holder",
    "3-in-1 Nutrition Set",
    "Perch Extender",
    "HBF housing",
    "HBF Solar Roof",
    "Pole System",
    "Planter Base",
    "Nook Perch Extender",
    "Nook Solar Roof",
]


def test_family_sets_have_the_requested_rows_in_order():
    units, addons, _ = app.family_pnl_product_sets()
    assert [p["name"] for p in units] == FAMILY_UNITS
    assert [p["name"] for p in addons] == FAMILY_ADDONS


def test_every_family_group_resolves_to_real_columns():
    # merged_products skips a source it cannot find, so a renamed or mistyped source
    # would silently leave a row reading zero. Each group must carry columns.
    units, addons, _ = app.family_pnl_product_sets()
    for product in [*units, *addons]:
        assert any(product["cols"].values()), f"{product['name']} resolved to no columns"


def test_retail_bundles_stay_on_their_own_rows():
    units, _, _ = app.family_pnl_product_sets()
    by_name = {p["name"]: p for p in units}
    bundle = by_name["SBF w Solar Roof + Perch Extender (Retail)"]
    plain = by_name["SBF w Solar Roof"]
    bundle_cols = {c for cols in bundle["cols"].values() for c in cols}
    plain_cols = {c for cols in plain["cols"].values() for c in cols}
    assert bundle_cols and not (bundle_cols & plain_cols)


def test_nature_cam_pro_is_reported_as_hardware_not_an_addon():
    units, addons, _ = app.family_pnl_product_sets()
    assert "Nature Cam PRO" in [p["name"] for p in units]
    assert "Nature Cam PRO" not in [p["name"] for p in addons]


# The one feeder the SBF/HBF line-up deliberately leaves out: Bird Buddy Home was not
# in the requested list. The Nook rows were added to the view in October 2026.
FAMILY_EXCLUDED = ["Bird Buddy Home"]


def test_family_units_leave_out_exactly_the_products_we_expect():
    # The family totals sit below the raw SKU totals by exactly these products. Pinning
    # the list means a feeder added later shows up here as a decision to make, instead
    # of silently dropping out of the view.
    units, _, _ = app.family_pnl_product_sets()
    grouped = {c for p in units for cols in p["cols"].values() for c in cols}
    raw = {c for p in app.SKU_PRODUCTS for cols in p["cols"].values() for c in cols}
    excluded = {
        c
        for p in app.SKU_PRODUCTS
        if p["name"] in FAMILY_EXCLUDED
        for cols in p["cols"].values()
        for c in cols
    }
    assert excluded and not (grouped & excluded)
    assert raw - grouped == excluded


def test_pole_system_and_planter_base_map_to_their_shipping_skus():
    # The line-up names the part the customer buys; the workbook ships them as the
    # two Nature Stations and the Pollinator Pot.
    _, addons, _ = app.family_pnl_product_sets()
    by_name = {p["name"]: p for p in addons}
    source = {p["name"]: p for p in app.ADDON_PRODUCTS}

    pole_cols = {c for cols in by_name["Pole System"]["cols"].values() for c in cols}
    expected_pole = {
        c
        for name in ("Nature Station Essential", "Nature Station Bloom")
        for cols in source[name]["cols"].values()
        for c in cols
    }
    assert pole_cols == expected_pole

    planter_cols = {c for cols in by_name["Planter Base"]["cols"].values() for c in cols}
    expected_planter = {c for cols in source["Pollinator Pot"]["cols"].values() for c in cols}
    assert planter_cols == expected_planter


def test_pnl_product_sets_dispatches_on_mode():
    raw_units = [p["name"] for p in app.pnl_product_sets("raw")[0]]
    merged_units = [p["name"] for p in app.pnl_product_sets("merged")[0]]
    family_units = [p["name"] for p in app.pnl_product_sets("families")[0]]
    assert raw_units == [p["name"] for p in app.SKU_PRODUCTS]
    assert merged_units[0] == "Birdbuddy"
    assert family_units == FAMILY_UNITS
    # Anything unrecognised falls back to the untouched SKU list.
    assert [p["name"] for p in app.pnl_product_sets("nonsense")[0]] == raw_units

"""Hardware-unit totals are derived from the per-SKU columns, not from the
workbook's own line, which stopped picking up new SKUs in February 2025."""

import pandas as pd
import pytest

import app
import dataprep as dp


def test_rebuild_sums_the_source_columns():
    df = pd.DataFrame({"a": [1.0, 2.0], "b": [10.0, 20.0], "Total": [0.0, 0.0]})
    out = dp.rebuild_unit_totals(df, {"Total": ["a", "b"]})
    assert list(out["Total"]) == [11.0, 22.0]


def test_rebuild_ignores_sources_that_are_not_in_the_frame():
    df = pd.DataFrame({"a": [5.0], "Total": [99.0]})
    out = dp.rebuild_unit_totals(df, {"Total": ["a", "missing"]})
    assert list(out["Total"]) == [5.0]


def test_rebuild_leaves_a_target_alone_when_no_source_is_present():
    df = pd.DataFrame({"Total": [99.0]})
    out = dp.rebuild_unit_totals(df, {"Total": ["nothing_here"]})
    assert list(out["Total"]) == [99.0]


def test_rebuild_coerces_text_and_blanks_to_zero():
    df = pd.DataFrame({"a": ["3", None], "b": ["x", 4.0]})
    out = dp.rebuild_unit_totals(df, {"Total": ["a", "b"]})
    assert list(out["Total"]) == [3.0, 4.0]


def _sku_cols(channel):
    return [c for p in app.SKU_PRODUCTS for c in app.product_cols_for_channel(p, channel)]


@pytest.mark.parametrize(
    "column,channel,region",
    [
        ("DTC_Hardware_Units", "DTC", None),
        ("DTC_Total_Hardware_Units", "DTC", None),
        ("DTC_US_Hardware_Units", "DTC", "us"),
        ("DTC_EU_Hardware_Units", "DTC", "eu"),
        ("Amazon_Hardware_Units", "Amazon", None),
        ("Amazon_US_Hardware_Units", "Amazon", "us"),
        ("Amazon_EU_Hardware_Units", "Amazon", "eu"),
    ],
)
def test_every_hardware_line_equals_its_per_sku_sum(column, channel, region):
    # The regression guard: a SKU added to the product list but missing from the
    # unit line (or the reverse) shows up here instead of silently inflating every
    # per-unit metric that divides by it.
    df = app.revenue_data
    prefix = "dtc" if channel == "DTC" else "amazon"
    cols = _sku_cols(channel)
    if region:
        cols = [c.replace(f"{prefix}_", f"{prefix}_{region}_", 1) for c in cols]
    expected = app.sum_cols(df, cols).sum()
    actual = pd.to_numeric(df[column], errors="coerce").fillna(0).sum()
    assert actual == pytest.approx(expected, abs=0.5)


def test_regions_add_back_to_the_combined_line():
    df = app.revenue_data
    for total, us, eu in [
        ("DTC_Total_Hardware_Units", "DTC_US_Hardware_Units", "DTC_EU_Hardware_Units"),
        ("Amazon_Hardware_Units", "Amazon_US_Hardware_Units", "Amazon_EU_Hardware_Units"),
    ]:
        combined = pd.to_numeric(df[total], errors="coerce").fillna(0).sum()
        parts = sum(pd.to_numeric(df[c], errors="coerce").fillna(0).sum() for c in (us, eu))
        assert combined == pytest.approx(parts, abs=0.5), total


def test_the_newer_skus_are_actually_counted():
    # These are the SKUs the workbook line misses; if the rebuild regressed, the
    # December 2025 DTC total drops back to the understated 47,033.
    df = app.revenue_data
    dec = df[(df.Date >= pd.Timestamp("2025-12-01")) & (df.Date <= pd.Timestamp("2025-12-31"))]
    assert pd.to_numeric(dec["DTC_US_Hardware_Units"], errors="coerce").sum() == pytest.approx(54613, abs=1)

import numpy as np
import pandas as pd
import pytest

import app


def _tax_frame() -> pd.DataFrame:
    # Row 0: early, EU renewal share available. Row 1: early, share zero so the
    # EU falls back to VAT on subscriptions. Row 2: after the 2026 split, where
    # nothing may move. Row 3: early, US renewal tax larger than the tax line,
    # so the shift must clip.
    return pd.DataFrame(
        {
            "Date": pd.to_datetime(["2025-06-01", "2025-07-01", "2026-02-01", "2025-08-01"]),
            "Renewal_Tax": [30.0, 20.0, 999.0, 500.0],
            "Renewal_Tax_Share_EU": [0.2, 0.0, 0.9, 0.2],
            "DTC_EU_Subscription": [40.0, 40.0, 40.0, 40.0],
            "DTC_US_Taxes": [100.0, 100.0, 100.0, 100.0],
            "DTC_US_Subscription_Taxes": [0.0, 0.0, 10.0, 0.0],
            "DTC_EU_Taxes": [50.0, 50.0, 50.0, 50.0],
            "DTC_EU_Subscription_Taxes": [0.0, 0.0, 5.0, 0.0],
            "DTC_Taxes": [150.0, 150.0, 150.0, 150.0],
            "DTC_Subscription_Taxes": [0.0, 0.0, 15.0, 0.0],
        }
    )


class TestSplitSubscriptionTax:
    def test_us_shift_moves_renewal_tax(self):
        out = app.split_subscription_tax(_tax_frame())
        assert out.loc[0, "DTC_US_Taxes"] == 70.0
        assert out.loc[0, "DTC_US_Subscription_Taxes"] == 30.0

    def test_eu_shift_uses_renewal_share_when_present(self):
        out = app.split_subscription_tax(_tax_frame())
        # 50 tax * 0.2 renewal share = 10 moved
        assert out.loc[0, "DTC_EU_Taxes"] == 40.0
        assert out.loc[0, "DTC_EU_Subscription_Taxes"] == 10.0

    def test_eu_falls_back_to_vat_when_share_is_zero(self):
        out = app.split_subscription_tax(_tax_frame())
        # 40 subscription * 21% VAT = 8.4 moved
        assert out.loc[1, "DTC_EU_Taxes"] == pytest.approx(41.6)
        assert out.loc[1, "DTC_EU_Subscription_Taxes"] == pytest.approx(8.4)

    def test_rows_from_2026_are_untouched(self):
        out = app.split_subscription_tax(_tax_frame())
        for col in ["DTC_US_Taxes", "DTC_US_Subscription_Taxes", "DTC_EU_Taxes",
                    "DTC_EU_Subscription_Taxes", "DTC_Taxes", "DTC_Subscription_Taxes"]:
            assert out.loc[2, col] == _tax_frame().loc[2, col]

    def test_shift_never_exceeds_the_tax_line(self):
        out = app.split_subscription_tax(_tax_frame())
        # Renewal tax of 500 against a 100 tax line: everything moves, nothing goes negative.
        assert out.loc[3, "DTC_US_Taxes"] == 0.0
        assert out.loc[3, "DTC_US_Subscription_Taxes"] == 100.0

    def test_total_tax_is_preserved_on_every_row(self):
        before = _tax_frame()
        out = app.split_subscription_tax(before)
        total_before = before["DTC_Taxes"] + before["DTC_Subscription_Taxes"]
        total_after = out["DTC_Taxes"] + out["DTC_Subscription_Taxes"]
        assert np.allclose(total_before, total_after)

    def test_frame_without_dates_passes_through(self):
        df = pd.DataFrame({"DTC_Taxes": [1.0]})
        assert app.split_subscription_tax(df) is df


def _exclusion_frame() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "Date": pd.to_datetime(["2026-05-01", "2026-05-02"]),
            "DTC_US_Hardware": [100.0, 200.0],
            "DTC_US_Taxes": [10.0, 20.0],
            "DTC_US_Subscription": [50.0, 60.0],
            "DTC_US_Subscription_Taxes": [5.0, 6.0],
            "DTC_US_Orders": [20.0, 30.0],
            "Renewal_Orders": [4.0, 10.0],
            "Renewal_Orders_EU": [1.0, 2.0],
            "DTC_Total_Hardware": [150.0, 250.0],
            "DTC_Total_Subscription": [70.0, 80.0],
            "DTC_Total_Subscription_Taxes": [7.0, 8.0],
            "DTC_Total_Orders": [25.0, 35.0],
            "Total_Revenue": [1000.0, 2000.0],
            "Web_AOV_US": [11.0, 12.0],
            "Returning_Customers_US": [0.5, 0.4],
            "First_Time_Customers_US": [0.5, 0.6],
        }
    )


class TestApplyRenewalsExclusion:
    def test_disabled_rebuilds_revenue_from_all_parts(self):
        out = app.apply_renewals_exclusion(_exclusion_frame(), enabled=False)
        assert list(out["DTC_US_Revenue"]) == [165.0, 286.0]
        assert list(out["DTC_Total_Revenue"]) == [227.0, 338.0]
        # Nothing else moves with the toggle off.
        assert list(out["Total_Revenue"]) == [1000.0, 2000.0]
        assert list(out["DTC_US_Orders"]) == [20.0, 30.0]
        assert list(out["Web_AOV_US"]) == [11.0, 12.0]

    def test_enabled_keeps_product_side_only(self):
        out = app.apply_renewals_exclusion(_exclusion_frame(), enabled=True)
        assert list(out["DTC_US_Revenue"]) == [110.0, 220.0]
        assert list(out["DTC_Total_Revenue"]) == [150.0, 250.0]
        assert list(out["DTC_US_Subscription"]) == [0.0, 0.0]
        assert list(out["DTC_US_Subscription_Taxes"]) == [0.0, 0.0]

    def test_enabled_removes_renewal_orders(self):
        out = app.apply_renewals_exclusion(_exclusion_frame(), enabled=True)
        assert list(out["DTC_US_Orders"]) == [16.0, 20.0]
        # Total scope removes US and EU renewals together.
        assert list(out["DTC_Total_Orders"]) == [20.0, 23.0]

    def test_enabled_takes_subscriptions_off_total_revenue(self):
        out = app.apply_renewals_exclusion(_exclusion_frame(), enabled=True)
        assert list(out["Total_Revenue"]) == [923.0, 1912.0]

    def test_enabled_rebases_aov_and_customer_mix(self):
        out = app.apply_renewals_exclusion(_exclusion_frame(), enabled=True)
        assert list(out["Web_AOV_US"]) == pytest.approx([110.0 / 16.0, 220.0 / 20.0])
        # returning orders: 0.5*20-4=6 over 16; 0.4*30-10=2 over 20
        assert list(out["Returning_Customers_US"]) == pytest.approx([0.375, 0.1])
        assert list(out["First_Time_Customers_US"]) == pytest.approx([0.625, 0.9])


def test_merge_renewals_file_zero_fills_when_export_is_missing():
    df = pd.DataFrame({"Date": pd.to_datetime(["2026-05-01"])})
    out = app.merge_renewals_file(df, "no_such_export.csv", {"Renewal_Orders": "Renewal_Orders"})
    assert list(out["Renewal_Orders"]) == [0.0]


def test_prepare_amazon_segments_backfills_unsplit_days():
    df = pd.DataFrame(
        {
            "Amazon_Revenue": [100.0, 200.0],
            "Amazon_US_Revenue": [0.0, 150.0],
            "Amazon_EU_Revenue": [0.0, 50.0],
        }
    )
    out = app.prepare_amazon_segments(df)
    # The unsplit day is booked to the US, matching how those eras reported.
    assert list(out["Amazon_US_Revenue"]) == [100.0, 150.0]
    assert list(out["Amazon_EU_Revenue"]) == [0.0, 50.0]


def test_product_base_cols_skips_regional_columns():
    df = pd.DataFrame(columns=["dtc_feeder_units", "dtc_us_feeder_units", "dtc_eu_feeder_units", "DTC_Revenue"])
    assert app.product_base_cols(df, "dtc") == ["dtc_feeder_units"]


def test_apply_dtc_region_selects_regional_columns():
    df = pd.DataFrame(
        {
            "Date": pd.to_datetime(["2026-05-01"]),
            "DTC_Revenue": [99.0],
            "DTC_Total_Revenue": [10.0],
            "DTC_US_Revenue": [6.0],
            "DTC_EU_Revenue": [4.0],
            "DTC_US_Spend": [3.0],
            "DTC_Total_Spend": [5.0],
        }
    )
    assert list(app.apply_dtc_region(df, "all")["DTC_Revenue"]) == [10.0]
    us = app.apply_dtc_region(df, "us")
    assert list(us["DTC_Revenue"]) == [6.0]
    assert list(us["Total_DTC_Spend"]) == [3.0]
    assert list(app.apply_dtc_region(df, "eu")["DTC_Revenue"]) == [4.0]


def test_survey_participants_prefers_the_counted_column():
    df = pd.DataFrame({"q0_participants": [7.0], "q1_a": [1.0], "q1_b": [2.0]})
    assert list(app.survey_participants(df)) == [7.0]
    df_no_count = pd.DataFrame({"q1_a": [1.0, np.nan], "q1_b": [2.0, 4.0]})
    assert list(app.survey_participants(df_no_count)) == [3.0, 4.0]


def test_engagement_frame_uses_imported_rate_when_positive():
    survey = pd.DataFrame(
        {
            "Date": pd.to_datetime(["2026-05-01", "2026-05-02"]),
            "q0_participants": [10.0, 10.0],
            "q0_engagement_rate": [0.5, np.nan],
        }
    )
    revenue = pd.DataFrame(
        {
            "Date": pd.to_datetime(["2026-05-01", "2026-05-02"]),
            "DTC_Orders": [40.0, 40.0],
        }
    )
    out = app.engagement_frame(survey, revenue, by_month=False)
    # Day one trusts the imported rate: denominator is rebuilt from it.
    assert out.loc[0, "Rate"] == 0.5
    assert out.loc[0, "Denominator"] == 20.0
    # Day two has no imported rate and falls back to participants over orders.
    assert out.loc[1, "Rate"] == 0.25
    assert out.loc[1, "Denominator"] == 40.0


def test_group_campaign_note_lines_rejoins_detail_lines():
    notes = pd.DataFrame(
        {
            "start": pd.to_datetime(["2026-05-01", "2026-05-01", "2026-05-03"]),
            "end": pd.to_datetime(["2026-05-02", "2026-05-02", "2026-05-03"]),
            "note": ["Price change", "- OLD: $199", "Unrelated note"],
        }
    )
    out = app.group_campaign_note_lines(notes)
    assert len(out) == 2
    assert out.loc[0, "note"] == "Price change\n- OLD: $199"
    assert out.loc[1, "note"] == "Unrelated note"

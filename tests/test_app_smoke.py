"""Importing app.py loads the real CSVs, runs the full data-prep pipeline, and
builds the UI, so a clean import is itself a broad regression check."""

import pandas as pd

import app


def test_app_object_exists():
    from shiny import App

    assert isinstance(app.app, App)


def test_revenue_data_loaded_and_prepared():
    df = app.revenue_data
    assert not df.empty
    assert df["Date"].notna().all()
    # The prep pipeline must have produced the regional splits.
    for col in ["DTC_Total_Revenue", "DTC_US_Revenue", "Amazon_US_Revenue"]:
        assert col in df.columns, col


def test_date_bounds_are_sane():
    assert app.DATE_MIN <= app.DATE_MAX
    assert app.DEFAULT_DATE_START <= app.DEFAULT_DATE_END


def test_survey_data_loaded():
    assert not app.survey_data.empty
    assert "Date" in app.survey_data.columns

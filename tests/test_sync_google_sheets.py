from datetime import date
from pathlib import Path
import sys

import numpy as np
import pandas as pd


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import sync_google_sheets as sync  # noqa: E402


def test_customer_rates_are_blank_without_customers():
    dates = [date(2026, 9, day) for day in range(1, 4)]
    revenue = pd.DataFrame(
        {
            "Date": dates,
            "Customers": [10, 2, 0],
            "Returning_Customers": [0.4, 0.5, 0.0],
            "First_Time_Customers": [0.6, 0.5, 1.0],
            "Customers_US": [10, 0, 0],
            "Returning_Customers_US": [0.4, np.nan, np.nan],
            "First_Time_Customers_US": [0.6, 1.0, 1.0],
            "Customers_EU": [0, 2, 0],
            "Returning_Customers_EU": [np.nan, 0.5, np.nan],
            "First_Time_Customers_EU": [1.0, 0.5, 1.0],
        }
    )

    out = sync.mask_customer_rates_without_customers(revenue, dates, regional=True)

    assert out.loc[0, "First_Time_Customers"] == 0.6
    assert np.isnan(out.loc[2, "First_Time_Customers"])
    assert np.isnan(out.loc[1, "First_Time_Customers_US"])
    assert np.isnan(out.loc[0, "First_Time_Customers_EU"])
    assert out.loc[1, "First_Time_Customers_EU"] == 0.5

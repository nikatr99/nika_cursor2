"""The P&L "SKU mix" toggle: every row as a share of its channel's feeder units."""

import pytest

import app


def test_hardware_base_sums_each_channel():
    counts = {
        "Feeder A": {"DTC": 10.0, "Amazon": 4.0, "All": 14.0},
        "Feeder B": {"DTC": 30.0, "Amazon": 6.0, "All": 36.0},
    }
    assert app.hardware_base(counts) == {"DTC": 40.0, "Amazon": 10.0, "All": 50.0}


def test_hardware_base_of_nothing_is_empty():
    assert app.hardware_base({}) == {}


def test_mix_share_divides_by_the_feeder_base():
    assert app.mix_share(25.0, 100.0) == 0.25
    # An add-on can outsell the feeders it attaches to, so shares above 1 stand.
    assert app.mix_share(150.0, 100.0) == 1.5
    assert app.mix_share(0.0, 100.0) == 0.0


def test_mix_share_without_a_base_is_undefined_rather_than_zero():
    # Channels that sell no feeders (the app stores) must not report a false 0%.
    assert app.mix_share(5.0, 0.0) is None
    assert app.mix_share(5.0, None) is None


def test_mix_cell_text_shows_percent_and_keeps_the_count_for_the_tooltip():
    display, tip = app.mix_cell_text(124.0, 0.1083)
    assert display == "10.8%"
    assert tip == "10.8% (124 units)"


def test_mix_cell_text_for_a_channel_with_no_feeders():
    display, tip = app.mix_cell_text(2024.0, None)
    assert display == "-"
    assert tip == "- (2,024 units)"


def test_hardware_rows_add_up_to_one_hundred_percent():
    counts = {
        "Feeder A": {"DTC": 871.0},
        "Feeder B": {"DTC": 235.0},
        "Feeder C": {"DTC": 37.0},
        "Feeder D": {"DTC": 2.0},
    }
    base = app.hardware_base(counts)
    total = sum(app.mix_share(row["DTC"], base["DTC"]) for row in counts.values())
    assert total == pytest.approx(1.0)
    assert app.fmt_pct(total) == "100.0%"

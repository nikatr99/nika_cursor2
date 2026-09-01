"""Plotly figure scaffolding shared by every chart on the dashboard."""

from __future__ import annotations

import pandas as pd
import plotly.graph_objects as go


def empty_fig(message: str, height: int = 440) -> go.Figure:
    fig = go.Figure()
    fig.add_annotation(
        text=message,
        x=0.5,
        y=0.5,
        xref="paper",
        yref="paper",
        showarrow=False,
        font={"family": "Montserrat", "size": 15, "color": "#555"},
    )
    fig.update_layout(
        height=height,
        template="plotly_white",
        margin={"l": 40, "r": 20, "t": 20, "b": 60},
        xaxis={"visible": False},
        yaxis={"visible": False},
        paper_bgcolor="#ffffff",
        plot_bgcolor="#ffffff",
        font={"family": "Montserrat"},
    )
    return fig


def normalize_fig_dates(fig: go.Figure) -> None:
    for trace in fig.data:
        x_values = getattr(trace, "x", None)
        if x_values is None:
            continue
        try:
            x_series = pd.Series(list(x_values))
        except TypeError:
            continue
        if not pd.api.types.is_datetime64_any_dtype(x_series):
            continue
        dates = pd.to_datetime(x_series, errors="coerce")
        trace.x = [date.strftime("%Y-%m-%d") if pd.notna(date) else None for date in dates]


def fig_date_tickformat(fig: go.Figure) -> str:
    """Month+year once the span is long enough that day-of-month labels collide."""
    dates: list[pd.Timestamp] = []
    for trace in fig.data:
        x_values = getattr(trace, "x", None)
        if x_values is None:
            continue
        parsed = pd.to_datetime(pd.Series(list(x_values)), errors="coerce").dropna()
        if not parsed.empty:
            dates.extend(parsed.tolist())
    if not dates:
        return "%b %d"
    start, end = min(dates), max(dates)
    span_days = (end - start).days
    month_starts = all(ts.day == 1 for ts in dates)
    # Monthly views land on the 1st, and multi-year ranges repeat "Jan 01" without a year.
    if month_starts or span_days > 100 or start.year != end.year:
        return "%b %Y"
    return "%b %d"


def finish_fig(fig: go.Figure, height: int = 500, percent_y: bool = False) -> go.Figure:
    normalize_fig_dates(fig)
    yaxis = {"title": "", "automargin": True}
    if percent_y:
        yaxis["tickformat"] = ".0%"
        yaxis["range"] = [0, 1]
    fig.update_layout(
        autosize=True,
        height=height,
        template="plotly_white",
        margin={"l": 64, "r": 34, "t": 34, "b": 72},
        paper_bgcolor="#ffffff",
        plot_bgcolor="#ffffff",
        hovermode="x unified",
        font={"family": "Montserrat"},
        legend={
            "orientation": "h",
            "x": 0.5,
            "y": 1.15,
            "xanchor": "center",
            "title": {"text": ""},
            "font": {"family": "Montserrat", "size": 14},
        },
        xaxis={
            "title": "",
            "type": "date",
            "tickformat": fig_date_tickformat(fig),
            "automargin": True,
            "tickfont": {"family": "Montserrat", "size": 14},
        },
        yaxis={**yaxis, "tickfont": {"family": "Montserrat", "size": 14}},
    )
    return fig

# Bird Buddy Dashboard - Shiny for Python

From the repository root, install the dependencies once and use the fixed-port
launcher:

```bash
python3 -m pip install -r App_py/requirements.txt
./run.sh
```

Open <http://127.0.0.1:3838>. The launcher watches code and data files, so reuse
the running server instead of restarting it or opening the app on another port.

## Code layout

`app.py` holds the UI and the server; the layers underneath it live in their
own modules so they can be tested and edited without touching the app shell:

- `dataprep.py` — CSV loading and every data repair: the regional DTC and
  Amazon splits, the Metorik renewals series, the pre-2026 subscription tax
  split, the renewals exclusion with its rate rebasing, and the survey
  engagement frame.
- `formatting.py` — number, money, and percent formatting, `safe_div`,
  `weighted_mean`, and the year-over-year delta pill.
- `figures.py` — the plotly scaffolding shared by every chart.

The repair logic is covered by `tests/` at the repository root; run
`python3 -m pytest tests/` after changing it.

## Data pipeline

Everything is Python; no R is needed at any stage. The usual entry point runs
both required steps in order:

```bash
python3 scripts/sync_all.py            # sheets sync, then retail sell-through
python3 scripts/sync_all.py --renewals # also rebuild the renewals series
```

The individual steps, when needed:

```bash
# Pull the sales workbooks into data/*.csv (all years by default)
python3 scripts/sync_google_sheets.py

# Optional filters
python3 scripts/sync_google_sheets.py --year 2026
python3 scripts/sync_google_sheets.py --since 2026-01
python3 scripts/sync_google_sheets.py --output-dir /tmp/scratch --no-backup   # dry run

# Post-purchase answers only, leaving revenue_data.csv and campaign_notes.csv alone.
python3 scripts/sync_google_sheets.py --year 2021 --survey-only

# Retail sell-through comes from its own workbook and must run after the sync,
# which would otherwise leave those columns zeroed
python3 scripts/sync_retail_sellthrough.py

# Rebuild the Metorik renewals series (only when new exports arrive)
python3 scripts/build_renewals_series.py
```

Each sync writes a timestamped `.backup_*` copy of the CSVs it is about to
change, plus `google_sheets_sync_sources_*.csv` and `..._skips_*.csv` logs
recording which sheet row every field came from. These are all gitignored:
commit the refreshed CSVs after a sync and git history is the real safety
net, with the provenance logs kept on disk until the next housekeeping pass
(the pre-git ones are archived in `/Users/nika/nika_cursor2_archive/`).

### Where the DTC figures come from

DTC financials are read from each workbook's `Summary` sheet rather than the
`DTC US&CA - P&L` / `DTC EU - P&L` tabs. The EU P&L states its breakdown in
euros while its revenue totals are in dollars, so summing those components
mixed currencies. The Summary carries the same breakdown already converted, and
its components add up to the region's revenue figure to the cent in every
workbook.

The Summary reports product tax and subscription tax under separate blocks, so
they are kept as separate columns (`DTC_*_Taxes` and
`DTC_*_Subscription_Taxes`) rather than merged.

Months before the Summary tab existed are read off `Sales` and `Detailed Report`
instead. From October 2022 their product lines come from a block reported gross
while the headline is net, so the two do not tie: the breakdown sits about 4%
above the headline in November 2022, when discounting was heaviest, and the gap
closes month by month until it is within a point either way from March 2023. The
difference is carried on `DTC_Unallocated` so the breakdown still adds up to the
headline, which is why that line reads negative across those months.

July 2021 is the first month in the file. Everything up to September 2022
predates several things: there is no revenue-by-product block at all, so
`DTC_Hardware` and `DTC_Addons` stay empty and `DTC_Unallocated` carries nearly
the whole headline; the first-time against returning customer split and the
`fAOV` / `rAOV` rows are absent up to October 2022, so those columns are left
blank rather than zeroed; TikTok spend runs in August 2021, then not again until
June 2022, and MNTN starts in September 2022.

Through October 2021 the `Sales` tab carries an `Indiegogo` line beside the
`Shopify` one and adds the two into its Total Revenue. The crowdfunder is its own
channel here, so `DTC_Revenue` is read off the `Shopify` row and the $102k raised
over those four months is booked on `IndieGoGo_Revenue` instead of being counted
as store revenue. Only the amount raised is reported, so the IndieGoGo hardware,
add-on and order columns stay empty until the 2023 campaign, which reports both.
From November 2021 the two rows agree, the campaign having closed that October.

Facebook is split across two rows in July and August 2021, `FB - US & CA` and
`FB - Internal Paid`, by who placed the media rather than by audience. The tab's
own spend total adds both, so `Meta_Spend` does too — without the second row July
would read $281k against a $455k total. Pinterest spend appears in the same era
but has no column of its own, so its $584 across the six months reaches
`Total_Spend` without showing in the channel breakdown.

Units for July 2021 to September 2022 do come through, from a block that counts
orders by pack size — `1x BB` through `10x BB` — rather than the feeders in them.
Each row is multiplied out by its pack size, which reproduces the block's own
total: January's 1,591 singles plus 2x51, 3x14 and 5x4 give the 1,755 it reports.
The block's `All` row is not used directly because it floors at zero, which would
read 1 September 2022, a day that nets out to six returns, as none. That era also
lists a single `Solar Roof` rather than separating the feeder sold with a roof
from the roof sold alone, so it feeds `Solar Roof Single`.

### Where the campaign notes come from

Notes sit in the band above the figures on the `Summary` tab. Before that tab
existed they were kept on a `Notes` row on the daily sales tab, and are read from
there for those months; a note merged across several days keeps the whole span.

### Where the post-purchase answers come from

The survey tab has taken three shapes. From July 2021 to October 2023 the
answers sit on the daily sales tab as each day's share of respondents, with no
respondent count beside them; the count is recovered as the smallest denominator
that turns every share back into a whole answer, and the engagement rate is
rebuilt as respondents over DTC orders, which is how every later tab computes it.
From November 2023 to March 2024 a dedicated tab reports one combined set of
answers, and from April 2024 it splits them by new and returning customer. April
2024 straddles the change, carrying both tabs: the survey was recast on the
tenth, so the combined tab covers the first nine days and the split tab the rest,
and each day is read from whichever tab answers for it.

Only the first question ran before November 2023, so those months carry `q1_*`
and the two `q0_*` columns and nothing else. Two answers have since been retired:
search engines shared a single `Google, Yahoo, Bing` option through April 2023,
and `Pinterest` was offered over the same span, so both keep their own columns.

The questionnaire also contains nine version-specific questions beyond the original
dashboard's Q1-Q6. They are imported as `q7_*` through `q15_*`: first-feeder status,
age, gender, comparison with other smart feeders, importance of bird-feeding
knowledge, the purchaser's and gift recipient's bird knowledge, pollinator-garden
familiarity, and prior bird-feeder use. The current demographic questions begin in
late 2024 or early 2025; the short-lived knowledge and experience questions retain
only their actual 2023-24 reporting spans. Their integer counts come from the raw PP
data tabs, avoiding percentage copies and repeated conditional branches.

The Post Purchase Survey page has one `Line chart view` control that switches the
engagement series and every Q1-Q15 through-time chart between percentage lines and
the default stacked bars. The selected daily/monthly aggregation is retained.

### Days the workbooks state inconsistently

Seven days between March 2022 and May 2023 carry a mistyped share, so their
answers total between 99.51% and 101.50% and no respondent count reproduces them
exactly. Each is rebuilt on the smallest count that fits with at most two cells
moved and none moved by more than a percentage point, which in five of the seven
comes down to a single digit: `62.00%` for a plain `62.50%`, `2.83%` for `2.38%`,
and so on. Anything needing a wider correction is left empty rather than guessed
at. A few days in 2024 leave the new-against-returning split blank while still
reporting who answered what; each segment's own shares give its size back, and
the pair is only used when the two add up to the respondents the tab reports.

Every repaired day is written to the sources log with the total it started from
and how much was moved, so the reconstruction can be traced back. Two days remain
unfilled because the workbook records respondents but no answers at all
(2024-05-16 and 2024-05-31).

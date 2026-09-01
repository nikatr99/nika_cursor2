# Bird Buddy Dashboard

From the repository root, install the dependencies once and start the app:

```bash
python3 -m pip install -r App_py/requirements.txt
./run.sh
```

Open <http://127.0.0.1:3838>. The server watches the Python, asset, and CSV
files, so saved changes reload automatically. The production copy runs at
<https://birdbuddy.lenalab.si> behind Google sign-in.

## Repository layout

- `App_py/` — the Shiny for Python dashboard (`app.py` plus the `dataprep`,
  `formatting`, and `figures` modules), its `data/` CSVs and `www/` assets.
  See `App_py/README.md` for the full data-provenance notes.
- `scripts/` — the Excel-to-CSV sync pipeline; `sync_all.py` runs it in the
  required order.
- `Google Sheets/` — the workbook exports the sync reads (one folder per year).
- `wo renewals/` — the raw Metorik renewals exports.
- `tests/` — the pytest suite covering the data-repair logic.
- `docs/` — methodology notes.
- `App/`, `archive/`, `app files/` — the retired R version of the dashboard,
  kept for reference; nothing uses it.

## Refreshing the data

```bash
python3 scripts/sync_all.py            # sheets sync + retail sell-through, in order
python3 scripts/sync_all.py --renewals # also rebuild the Metorik renewals series
```

After a sync, commit the refreshed CSVs so every data change stays diffable
and reversible:

```bash
git add -A 'App_py/data' && git commit -m "Sync data"
```

Git history is the backup system. The old manual `.backup_*` copies are
gitignored, and the pre-git ones were archived to
`/Users/nika/nika_cursor2_archive/`.

## Tests

```bash
python3 -m pip install -r App_py/requirements-dev.txt
python3 -m pytest tests/
```

Run them after touching `App_py/dataprep.py`, the sync scripts, or anything
else that shapes the numbers.

## Working with coding agents

Keep one app server on port `3838`. Before starting it, check whether
<http://127.0.0.1:3838> is already running; if it is, reuse it. Do not restart
the app after each change or launch extra instances on new ports. Run `./run.sh`
only when no server is running—the script will leave an existing server alone.

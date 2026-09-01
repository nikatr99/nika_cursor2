#!/usr/bin/env python3
"""Run the full data sync in the required order.

The Google Sheets sync zeroes the retail sell-through columns, so
sync_retail_sellthrough.py must always run after it. Running the steps
by hand invites getting that order wrong; this wrapper enforces it.

    python3 scripts/sync_all.py                  # full sync, both steps
    python3 scripts/sync_all.py --since 2026-01  # filters pass through to the sheets sync
    python3 scripts/sync_all.py --renewals       # also rebuild the Metorik renewals series

Any argument other than --renewals is forwarded to sync_google_sheets.py
unchanged. The retail and renewals steps take no arguments here; run the
underlying scripts directly for their own options.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"


def run_step(name: str, args: list[str]) -> None:
    script = SCRIPTS / name
    print(f"\n=== {name} {' '.join(args)}".rstrip() + " ===", flush=True)
    result = subprocess.run([sys.executable, str(script), *args], cwd=ROOT)
    if result.returncode != 0:
        sys.exit(f"{name} failed with exit code {result.returncode}; stopping.")


def main() -> None:
    args = sys.argv[1:]
    renewals = "--renewals" in args
    sheets_args = [a for a in args if a != "--renewals"]

    run_step("sync_google_sheets.py", sheets_args)
    run_step("sync_retail_sellthrough.py", [])
    if renewals:
        run_step("build_renewals_series.py", [])

    print(
        "\nSync complete. Review and commit the refreshed data, e.g.:\n"
        "  git add -A 'App_py/data' && git commit -m 'Sync data'"
    )


if __name__ == "__main__":
    main()

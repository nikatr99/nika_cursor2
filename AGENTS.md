# Agent instructions

- Reuse the dashboard at `http://127.0.0.1:3838` when it is already running.
- Do not restart the server after edits or start additional instances on other
  ports; live reload handles code, asset, and CSV changes.
- Run `./run.sh` only when port `3838` has no dashboard server.
- Run `python3 -m pytest tests/` after changing `App_py/dataprep.py`,
  `App_py/formatting.py`, `App_py/figures.py`, or the sync scripts.
- Commit refreshed `App_py/data/*.csv` after running a sync; git history is
  the backup system, so never add new `.backup_*` files.

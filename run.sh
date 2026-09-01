#!/usr/bin/env bash
# Serve the dashboard on a fixed port. Edits to the app or its data are picked
# up automatically, so agents and developers should reuse the running server.
#
#   ./run.sh              http://127.0.0.1:3838
#   PORT=4000 ./run.sh    somewhere else
set -uo pipefail

PORT="${PORT:-3838}"
PYTHON="${PYTHON:-/Users/nika/miniconda3/bin/python3.13}"

# Shiny's own watch list covers *.py and assets but not *.csv, and the dashboard reads
# its CSVs once at import, so without them a fresh sync would need a manual restart.
WATCH="*.py,*.css,*.scss,*.js,*.htm,*.html,*.png,*.yml,*.yaml,*.csv"

# Do not replace a healthy development server or work around it with a new port.
if lsof -ti "tcp:$PORT" >/dev/null 2>&1; then
  echo "Dashboard is already running on http://127.0.0.1:$PORT"
  exit 0
fi

cd "$(dirname "$0")/App_py" || exit 1
echo "Dashboard on http://127.0.0.1:$PORT  (ctrl-c to stop)"
exec "$PYTHON" -m shiny run --port "$PORT" --host 127.0.0.1 \
  --reload --reload-includes "$WATCH" "$@" app.py

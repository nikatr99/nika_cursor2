# Bird Buddy Dashboard

From the repository root, install the dependencies once and start the app:

```bash
python3 -m pip install -r App_py/requirements.txt
./run.sh
```

Open <http://127.0.0.1:3838>. The server watches the Python, asset, and CSV
files, so saved changes reload automatically.

## Working with coding agents

Keep one app server on port `3838`. Before starting it, check whether
<http://127.0.0.1:3838> is already running; if it is, reuse it. Do not restart
the app after each change or launch extra instances on new ports. Run `./run.sh`
only when no server is running—the script will leave an existing server alone.

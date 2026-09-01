import sys
from pathlib import Path

# The dashboard modules live in App_py/, which is the server's working directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "App_py"))

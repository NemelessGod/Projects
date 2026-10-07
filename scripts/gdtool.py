"""Keep gdtoolkit's grammar cache writable without changing HOME or its source."""

import importlib
import os
import sys
from pathlib import Path

# gdtoolkit 4.5 ignores XDG_CACHE_HOME. Redirect its cache location before Parser init.
module = importlib.import_module("gdtoolkit.parser.parser")
module.parser._cache_dirpath = str(
    Path(os.getenv("XDG_CACHE_HOME", "/tmp")) / "gdtoolkit"
)
mode = sys.argv.pop(1)
if mode not in {"format", "lint"}:
    raise SystemExit("Use format or lint")
cli = importlib.import_module(
    f"gdtoolkit.{'formatter' if mode == 'format' else 'linter'}.__main__"
)
cli.main()

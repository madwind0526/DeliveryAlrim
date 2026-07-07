"""Minimal .env file loader (no external dependency).

Reads KEY=VALUE lines from a .env file next to this script and merges
them into os.environ, without overwriting variables already set in the
real environment.
"""

import os
from pathlib import Path

ENV_PATH = Path(__file__).resolve().parent / ".env"


def load_env(path: Path = ENV_PATH) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def require_env(*names: str) -> dict:
    load_env()
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise SystemExit(
            "Missing required .env values: "
            + ", ".join(missing)
            + f"\nCopy {ENV_PATH.parent / 'example.env'} to "
            f"{ENV_PATH} and fill them in."
        )
    return {name: os.environ[name] for name in names}

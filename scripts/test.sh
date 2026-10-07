#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SPIN_ROOT"
# Only create a test database if absent; never erase development data.
if ! docker exec spin-kingdom-db psql -p 55432 -U postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='spin_kingdom_test'" | rg -q '^1$'; then
  docker exec spin-kingdom-db createdb -p 55432 -U postgres spin_kingdom_test
fi
ruff check backend
ruff format --check backend
python scripts/gdtool.py format --check client/scripts client/tests
python scripts/gdtool.py lint client/scripts client/tests
cd backend
pytest -q

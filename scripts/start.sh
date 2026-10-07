#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SPIN_ROOT"
# Reuse existing checkout; each cloud task is already isolated. No worktree.
if docker container inspect spin-kingdom-db >/dev/null 2>&1; then
  docker start spin-kingdom-db >/dev/null
else
  mkdir -p .local/postgres
  docker run -d --name spin-kingdom-db --network host \
    -v "$SPIN_ROOT/.local/postgres:/var/lib/postgresql/data" \
    -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=spin_kingdom \
    postgres:17-bookworm@sha256:3645570cccdfa447589da9f57dd740faa29b30938e861289a5574b6ca6b03826 \
    postgres -c listen_addresses=127.0.0.1 -p 55432 >/dev/null
fi
for _ in {1..30}; do
  if docker exec spin-kingdom-db pg_isready -p 55432 -U postgres >/dev/null; then break; fi
  sleep 1
done
docker exec spin-kingdom-db pg_isready -p 55432 -U postgres >/dev/null
export DATABASE_URL="${DATABASE_URL:-postgresql+psycopg://postgres@127.0.0.1:55432/spin_kingdom}"
cd backend
python -m app.migrate
# Foreground process: task runner may put it in a managed background session.
exec uvicorn app.main:app --host 127.0.0.1 --port 8000

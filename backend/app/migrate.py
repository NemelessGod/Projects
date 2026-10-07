"""Explicit, serialized migration runner. No schema changes on API startup."""

import json
from pathlib import Path

from sqlalchemy import text

from app.configuration import validate_config
from app.db import engine

ROOT = Path(__file__).resolve().parents[1]


def migrate():
    with engine.begin() as conn:
        conn.execute(text("SELECT pg_advisory_xact_lock(53190742)"))
        exists = conn.execute(text("SELECT to_regclass('public.schema_migrations')")).scalar()
        versions = (
            set(conn.execute(text("SELECT version FROM schema_migrations")).scalars())
            if exists
            else set()
        )
        for path in sorted((ROOT / "migrations").glob("*.sql")):
            version = int(path.name.split("_")[0])
            if version not in versions:
                conn.exec_driver_sql(path.read_text())
        config = validate_config(json.loads((ROOT / "config/economy.v1.json").read_text()))
        conn.execute(
            text(
                "INSERT INTO game_config(revision,body,active) VALUES(:r,CAST(:b AS jsonb),true) ON CONFLICT(revision) DO NOTHING"
            ),
            {"r": config["revision"], "b": json.dumps(config)},
        )


if __name__ == "__main__":
    migrate()
    print("Migrations complete.")

"""Trusted local/ops CLI, not a public API. Activates a new validated revision."""

import argparse
import json
from pathlib import Path

from app.configuration import validate_config, validate_transition
from app.db import engine
from app.service import active_config, query


def publish(path: Path):
    body = validate_config(json.loads(path.read_text(encoding="utf-8")))
    with engine.begin() as conn:
        query(conn, "SELECT pg_advisory_xact_lock(53190742)")
        old = active_config(conn)
        validate_transition(old, body)
        query(conn, "UPDATE game_config SET active=false WHERE active")
        query(
            conn,
            "INSERT INTO game_config(revision,body,active) VALUES(:r,CAST(:b AS jsonb),true)",
            r=body["revision"],
            b=json.dumps(body),
        )
    print(f"Activated economy revision {body['revision']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    publish(parser.parse_args().path)

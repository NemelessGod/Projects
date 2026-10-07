import os

# Tests NEVER use the application's database. Only a dedicated *_test DB is allowed.
os.environ["DATABASE_URL"] = os.getenv(
    "TEST_DATABASE_URL", "postgresql+psycopg://postgres@127.0.0.1:55432/spin_kingdom_test"
)
assert os.environ["DATABASE_URL"].split("?")[0].endswith("_test"), "Use a dedicated *_test database"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.db import engine
from app.main import app
from app.migrate import migrate


@pytest.fixture(scope="session", autouse=True)
def schema():
    migrate()


@pytest.fixture()
def client():
    with engine.begin() as conn:
        conn.execute(
            text(
                "TRUNCATE spin_history,economy_ledger,operations,player_buildings,player_energy,player_wallets,sessions,players CASCADE"
            )
        )
        conn.execute(text("UPDATE game_config SET active=(revision=1)"))
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def guest(client):
    response = client.post("/v1/auth/guest")
    assert response.status_code == 201
    data = response.json()
    return data["state"]["player_id"], {"Authorization": "Bearer " + data["token"]}, data["state"]

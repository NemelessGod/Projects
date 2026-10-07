import hashlib
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text

from app.db import engine
from app.service import active_config, create_guest, load_state, perform, query, server_time

app = FastAPI(title="Spin Kingdom API", version="0.1.0")
bearer = HTTPBearer(auto_error=False)


class Command(BaseModel):
    model_config = ConfigDict(extra="forbid")
    idempotency_key: UUID


class UpgradeCommand(Command):
    building_id: str = Field(min_length=1, max_length=64, pattern=r"^[a-z_]+$")


def identity(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if not credentials or len(credentials.credentials) > 256:
        raise HTTPException(401, "Session required")
    hashed = hashlib.sha256(credentials.credentials.encode()).hexdigest()
    with engine.begin() as conn:
        player = query(
            conn,
            """SELECT player_id FROM sessions JOIN players ON players.id=sessions.player_id
              WHERE token_hash=:h AND expires_at>now() AND NOT players.banned""",
            h=hashed,
        ).scalar()
    if player is None:
        raise HTTPException(401, "Session expired or invalid")
    return player


@app.get("/health")
def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
        cfg = active_config(conn)
    return {"status": "ok", "config_revision": cfg["revision"]}


@app.post("/v1/auth/guest", status_code=201)
def guest():
    with engine.begin() as conn:
        return create_guest(conn)


@app.get("/v1/config")
def config(player=Depends(identity)):
    with engine.connect() as conn:
        return active_config(conn)


@app.get("/v1/player")
def player_state(player=Depends(identity)):
    with engine.begin() as conn:
        query(conn, "UPDATE players SET last_login=now() WHERE id=:p", p=player)
        return load_state(conn, player, active_config(conn), server_time(conn))


@app.post("/v1/spins")
def spin(command: Command, player=Depends(identity)):
    with engine.begin() as conn:
        return perform(conn, player, command.idempotency_key, "spin", {})


@app.post("/v1/buildings/upgrade")
def upgrade(command: UpgradeCommand, player=Depends(identity)):
    with engine.begin() as conn:
        return perform(
            conn, player, command.idempotency_key, "upgrade", {"building_id": command.building_id}
        )

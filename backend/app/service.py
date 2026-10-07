import hashlib
import json
import secrets
from datetime import timedelta
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import text

from app.economy import (
    progress,
    regenerate,
    select_symbols,
    slot_rewards,
    upgrade_price,
    xp_required,
)


def query(conn, sql, **params):
    return conn.execute(text(sql), params)


def active_config(conn):
    row = query(conn, "SELECT body FROM game_config WHERE active").scalar()
    if row is None:
        raise HTTPException(503, "Economy configuration is unavailable")
    return row


def server_time(conn):
    return query(conn, "SELECT clock_timestamp()").scalar()


def create_guest(conn):
    cfg = active_config(conn)
    player_id = uuid4()
    token = secrets.token_urlsafe(32)
    now = server_time(conn)
    query(
        conn,
        "INSERT INTO players(id,display_name) VALUES(:id,:name)",
        id=player_id,
        name="Навигатор " + str(player_id)[:5],
    )
    query(
        conn,
        "INSERT INTO sessions(token_hash,player_id,expires_at) VALUES(:h,:p,:e)",
        h=hashlib.sha256(token.encode()).hexdigest(),
        p=player_id,
        e=now + timedelta(days=90),
    )
    query(
        conn,
        "INSERT INTO player_wallets VALUES(:p,:c,:v)",
        p=player_id,
        c=cfg["initial"]["coins"],
        v=cfg["initial"]["premium"],
    )
    query(
        conn,
        "INSERT INTO player_energy VALUES(:p,:s,:m,:t)",
        p=player_id,
        s=cfg["initial"]["spins"],
        m=cfg["initial"]["max_spins"],
        t=now,
    )
    for currency in ("coins", "premium", "spins"):
        value = cfg["initial"][currency]
        query(
            conn,
            """INSERT INTO economy_ledger(player_id,currency,amount,balance_before,balance_after,reason)
              VALUES(:p,:c,:v,0,:v,'guest_start')""",
            p=player_id,
            c=currency,
            v=value,
        )
    return {"token": token, "state": load_state(conn, player_id, cfg, now)}


def load_state(conn, player_id, config, now):
    player = dict(
        query(conn, "SELECT * FROM players WHERE id=:p FOR UPDATE", p=player_id).mappings().one()
    )
    if player["banned"]:
        raise HTTPException(403, "Account suspended")
    wallet = dict(
        query(conn, "SELECT * FROM player_wallets WHERE player_id=:p", p=player_id).mappings().one()
    )
    energy = dict(
        query(conn, "SELECT * FROM player_energy WHERE player_id=:p", p=player_id).mappings().one()
    )
    old = energy["spins"]
    energy["spins"], energy["regenerated_at"] = regenerate(
        old,
        energy["max_spins"],
        energy["regenerated_at"],
        now,
        config["energy"]["regeneration_seconds"],
    )
    query(
        conn,
        "UPDATE player_energy SET spins=:s,regenerated_at=:t WHERE player_id=:p",
        p=player_id,
        s=energy["spins"],
        t=energy["regenerated_at"],
    )
    if energy["spins"] != old:
        query(
            conn,
            """INSERT INTO economy_ledger(player_id,currency,amount,balance_before,balance_after,reason)
              VALUES(:p,'spins',:a,:b,:e,'regeneration')""",
            p=player_id,
            a=energy["spins"] - old,
            b=old,
            e=energy["spins"],
        )
    while True:
        world = config["worlds"][player["world_index"]]
        built = {
            r["building_id"]: r["level"]
            for r in query(
                conn,
                "SELECT building_id,level FROM player_buildings WHERE player_id=:p AND world_id=:w",
                p=player_id,
                w=world["id"],
            ).mappings()
        }
        complete = all(built.get(b["id"], 0) == len(b["costs"]) for b in world["buildings"])
        if not complete or player["world_index"] == len(config["worlds"]) - 1:
            break
        # Live ops may append a world after a player finished the old campaign.
        # Its previous completion reward was already committed; never grant it again.
        player["world_index"] += 1
        query(
            conn,
            "UPDATE players SET world_index=:w WHERE id=:p",
            p=player_id,
            w=player["world_index"],
        )
    buildings = [
        dict(
            b,
            level=built.get(b["id"], 0),
            next_cost=b["costs"][built.get(b["id"], 0)]
            if built.get(b["id"], 0) < len(b["costs"])
            else None,
        )
        for b in world["buildings"]
    ]
    next_time = (
        None
        if energy["spins"] >= energy["max_spins"]
        else (
            energy["regenerated_at"] + timedelta(seconds=config["energy"]["regeneration_seconds"])
        ).isoformat()
    )
    return {
        "player_id": str(player_id),
        "display_name": player["display_name"],
        "avatar": player["avatar"],
        "level": player["level"],
        "xp": player["xp"],
        "xp_required": xp_required(player["level"], config),
        "coins": wallet["coins"],
        "premium": wallet["premium"],
        "spins": energy["spins"],
        "max_spins": energy["max_spins"],
        "world_index": player["world_index"],
        "world": dict(world, buildings=buildings),
        "next_spin_at": next_time,
        "seconds_to_next_spin": None
        if next_time is None
        else max(
            0,
            int(
                (
                    energy["regenerated_at"]
                    + timedelta(seconds=config["energy"]["regeneration_seconds"])
                    - now
                ).total_seconds()
            ),
        ),
        "server_time": now.isoformat(),
        "config_revision": config["revision"],
        "campaign_complete": all(b["next_cost"] is None for b in buildings)
        and player["world_index"] == len(config["worlds"]) - 1,
    }


class RewardService:
    def __init__(self, conn, state, operation_id):
        self.conn, self.state, self.operation_id = conn, state, operation_id

    def change(self, currency, amount, reason):
        if amount == 0:
            return
        before = self.state[currency]
        after = before + amount
        if after < 0:
            raise HTTPException(409, f"Insufficient {currency}")
        self.state[currency] = after
        query(
            self.conn,
            """INSERT INTO economy_ledger(player_id,operation_id,currency,amount,balance_before,balance_after,reason)
              VALUES(:p,:o,:c,:a,:b,:e,:r)""",
            p=self.state["player_id"],
            o=self.operation_id,
            c=currency,
            a=amount,
            b=before,
            e=after,
            r=reason,
        )

    def apply(self, rewards, config, reason):
        for currency in ("coins", "premium", "spins"):
            self.change(currency, rewards.get(currency, 0), reason)
        self.state["level"], self.state["xp"], levels = progress(
            self.state["level"], self.state["xp"], rewards.get("xp", 0), config
        )
        self.change("spins", levels * config["xp"]["level_spins"], "level_up")
        return levels

    def save(self):
        s = self.state
        query(
            self.conn,
            "UPDATE player_wallets SET coins=:c,premium=:v WHERE player_id=:p",
            p=s["player_id"],
            c=s["coins"],
            v=s["premium"],
        )
        query(
            self.conn,
            "UPDATE player_energy SET spins=:s WHERE player_id=:p",
            p=s["player_id"],
            s=s["spins"],
        )
        query(
            self.conn,
            "UPDATE players SET level=:l,xp=:x,world_index=:w WHERE id=:p",
            p=s["player_id"],
            l=s["level"],
            x=s["xp"],
            w=s["world_index"],
        )


def perform(conn, player_id, key, action, payload):
    # Single player row lock serializes every mutation, including read-triggered regeneration.
    locked = query(
        conn, "SELECT banned FROM players WHERE id=:p FOR UPDATE", p=player_id
    ).scalar_one()
    if locked:
        raise HTTPException(403, "Account suspended")
    fingerprint = hashlib.sha256(
        json.dumps({"action": action, "payload": payload}, sort_keys=True).encode()
    ).hexdigest()
    previous = (
        query(
            conn,
            "SELECT payload_hash,response FROM operations WHERE player_id=:p AND idempotency_key=:k",
            p=player_id,
            k=key,
        )
        .mappings()
        .first()
    )
    if previous:
        if previous["payload_hash"] != fingerprint:
            raise HTTPException(409, "Idempotency key already used for another command")
        return previous["response"]
    cfg = active_config(conn)
    now = server_time(conn)
    state = load_state(conn, player_id, cfg, now)
    op_id = uuid4()
    reward_service = RewardService(conn, state, op_id)
    result = {}
    if action == "spin":
        reward_service.change("spins", -cfg["energy"]["cost"], "spin_cost")
        symbols = select_symbols(cfg)
        rewards = slot_rewards(symbols, cfg)
        levels = reward_service.apply(rewards, cfg, "slot")
        result = {
            "symbols": [s["id"] for s in symbols],
            "rewards": rewards,
            "levels_gained": levels,
        }
    elif action == "upgrade":
        building = next(
            (b for b in state["world"]["buildings"] if b["id"] == payload["building_id"]), None
        )
        if building is None:
            raise HTTPException(404, "Building not found in current world")
        try:
            price = upgrade_price(building, building["level"])
        except ValueError as exc:
            raise HTTPException(409, str(exc)) from exc
        reward_service.change("coins", -price, "building_upgrade")
        query(
            conn,
            """INSERT INTO player_buildings(player_id,world_id,building_id,level) VALUES(:p,:w,:b,1)
              ON CONFLICT(player_id,world_id,building_id) DO UPDATE
              SET level=player_buildings.level+1,updated_at=now()""",
            p=player_id,
            w=state["world"]["id"],
            b=building["id"],
        )
        building["level"] += 1
        levels = reward_service.apply({"xp": cfg["xp"]["upgrade"]}, cfg, "building_upgrade")
        complete = all(b["level"] == len(b["costs"]) for b in state["world"]["buildings"])
        if complete:
            reward_service.apply(state["world"]["completion"], cfg, "world_complete")
            state["world_index"] = min(state["world_index"] + 1, len(cfg["worlds"]) - 1)
        result = {
            "building_id": building["id"],
            "price": price,
            "levels_gained": levels,
            "world_complete": complete,
        }
    else:
        raise HTTPException(400, "Unsupported action")
    reward_service.save()
    response = {
        "operation_id": str(op_id),
        "result": result,
        "state": load_state(conn, player_id, cfg, now),
    }
    query(
        conn,
        """INSERT INTO operations(id,player_id,idempotency_key,action,payload_hash,config_revision,response)
          VALUES(:o,:p,:k,:a,:h,:r,CAST(:b AS jsonb))""",
        o=op_id,
        p=player_id,
        k=key,
        a=action,
        h=fingerprint,
        r=cfg["revision"],
        b=json.dumps(response),
    )
    if action == "spin":
        query(
            conn,
            """INSERT INTO spin_history(operation_id,player_id,symbols,rewards)
              VALUES(:o,:p,CAST(:s AS jsonb),CAST(:r AS jsonb))""",
            o=op_id,
            p=player_id,
            s=json.dumps(result["symbols"]),
            r=json.dumps(result["rewards"]),
        )
    return response

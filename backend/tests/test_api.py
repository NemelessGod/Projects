import json
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

from sqlalchemy import text

from app.db import engine


def key():
    return {"idempotency_key": str(uuid4())}


def test_guest_and_restoration(client, guest):
    player, headers, initial = guest
    assert initial["coins"] == 300 and initial["spins"] == 20
    response = client.get("/v1/player", headers=headers)
    assert response.status_code == 200
    assert response.json()["player_id"] == player
    assert client.get("/v1/player").status_code == 401
    assert client.get("/v1/player", headers={"Authorization": "Bearer invalid"}).status_code == 401


def test_spin_replay_and_ledger(client, guest):
    player, headers, _ = guest
    command = key()
    a = client.post("/v1/spins", headers=headers, json=command)
    b = client.post("/v1/spins", headers=headers, json=command)
    assert a.status_code == b.status_code == 200
    assert a.json() == b.json()
    current = client.get("/v1/player", headers=headers).json()
    assert current["coins"] == a.json()["state"]["coins"]
    with engine.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM spin_history")).scalar() == 1
        assert (
            conn.execute(
                text("SELECT count(*) FROM economy_ledger WHERE reason='spin_cost'")
            ).scalar()
            == 1
        )
        assert (
            conn.execute(
                text(
                    "SELECT sum(amount) FROM economy_ledger WHERE player_id=:p AND currency='coins'"
                ),
                {"p": player},
            ).scalar()
            == current["coins"]
        )


def test_concurrent_same_request(client, guest):
    _, headers, _ = guest
    command = key()
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(
            pool.map(lambda _: client.post("/v1/spins", headers=headers, json=command), range(6))
        )
    assert all(r.status_code == 200 for r in results)
    assert len({r.json()["operation_id"] for r in results}) == 1
    with engine.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM operations")).scalar() == 1


def test_concurrent_insufficient_energy(client, guest, monkeypatch):
    player, headers, _ = guest
    from app import service

    config = client.get("/v1/config", headers=headers).json()
    monkeypatch.setattr(service, "select_symbols", lambda _: [config["symbols"][0]] * 3)
    with engine.begin() as conn:
        conn.execute(text("UPDATE player_energy SET spins=1 WHERE player_id=:p"), {"p": player})
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(
            pool.map(lambda _: client.post("/v1/spins", headers=headers, json=key()), range(2))
        )
    assert sorted(r.status_code for r in responses) == [200, 409]
    assert client.get("/v1/player", headers=headers).json()["spins"] == 0


def test_server_price_and_xp(client, guest):
    _, headers, _ = guest
    command = dict(key(), building_id="beacon")
    r = client.post("/v1/buildings/upgrade", headers=headers, json=command)
    assert r.status_code == 200
    assert r.json()["state"]["coins"] == 180
    assert r.json()["state"]["xp"] == 15
    assert r.json()["state"]["world"]["buildings"][0]["level"] == 1
    assert client.post("/v1/buildings/upgrade", headers=headers, json=command).json() == r.json()
    denied = client.post(
        "/v1/buildings/upgrade", headers=headers, json=dict(key(), building_id="beacon")
    )
    assert denied.status_code == 409
    restored = client.get("/v1/player", headers=headers).json()
    assert restored["coins"] == 180 and restored["xp"] == 15


def test_forbid_client_rewards_and_time(client, guest):
    _, headers, _ = guest
    for field in ["coins", "rewards", "server_time", "player_id", "multiplier"]:
        assert (
            client.post(
                "/v1/spins", headers=headers, json=dict(key(), **{field: 1000000})
            ).status_code
            == 422
        )
    assert (
        client.post(
            "/v1/buildings/upgrade",
            headers=headers,
            json=dict(key(), building_id="beacon", price=0),
        ).status_code
        == 422
    )


def test_key_bound_to_action_and_payload(client, guest):
    _, headers, _ = guest
    command = key()
    assert client.post("/v1/spins", headers=headers, json=command).status_code == 200
    assert (
        client.post(
            "/v1/buildings/upgrade", headers=headers, json=dict(command, building_id="beacon")
        ).status_code
        == 409
    )


def test_server_regeneration_once(client, guest):
    player, headers, _ = guest
    with engine.begin() as conn:
        conn.execute(
            text(
                "UPDATE player_energy SET spins=1,regenerated_at=now()-interval '610 seconds' WHERE player_id=:p"
            ),
            {"p": player},
        )
    assert client.get("/v1/player", headers=headers).json()["spins"] == 3
    assert client.get("/v1/player", headers=headers).json()["spins"] == 3


def test_world_completion_and_final_world_once(client, guest):
    player, headers, _ = guest
    config = client.get("/v1/config", headers=headers).json()
    for i, world in enumerate(config["worlds"]):
        with engine.begin() as conn:
            conn.execute(
                text("UPDATE player_wallets SET coins=100000 WHERE player_id=:p"), {"p": player}
            )
            for b in world["buildings"]:
                conn.execute(
                    text(
                        "INSERT INTO player_buildings(player_id,world_id,building_id,level) VALUES(:p,:w,:b,:l)"
                    ),
                    {
                        "p": player,
                        "w": world["id"],
                        "b": b["id"],
                        "l": 2 if b == world["buildings"][0] else 3,
                    },
                )
        r = client.post(
            "/v1/buildings/upgrade",
            headers=headers,
            json=dict(key(), building_id=world["buildings"][0]["id"]),
        )
        assert r.status_code == 200
        assert r.json()["result"]["world_complete"]
        assert r.json()["state"]["world_index"] == 1
        if i == 1:
            assert r.json()["state"]["campaign_complete"]
            assert (
                client.post(
                    "/v1/buildings/upgrade",
                    headers=headers,
                    json=dict(key(), building_id=world["buildings"][0]["id"]),
                ).status_code
                == 409
            )


def test_config_revision_is_server_authoritative(client, guest):
    _, headers, _ = guest
    config = client.get("/v1/config", headers=headers).json()
    config["revision"] = 2
    config["worlds"][0]["buildings"][0]["costs"][0] = 12
    with engine.begin() as conn:
        conn.execute(text("UPDATE game_config SET active=false"))
        conn.execute(
            text("INSERT INTO game_config(revision,body,active) VALUES(2,CAST(:b AS jsonb),true)"),
            {"b": json.dumps(config)},
        )
    r = client.post(
        "/v1/buildings/upgrade", headers=headers, json=dict(key(), building_id="beacon")
    )
    assert r.json()["state"]["coins"] == 288
    assert r.json()["state"]["config_revision"] == 2
    with engine.begin() as conn:
        conn.execute(text("UPDATE game_config SET active=false WHERE revision=2"))
        conn.execute(text("UPDATE game_config SET active=true WHERE revision=1"))
        conn.execute(
            text(
                "DELETE FROM economy_ledger WHERE operation_id IN (SELECT id FROM operations WHERE config_revision=2)"
            )
        )
        conn.execute(text("DELETE FROM operations WHERE config_revision=2"))
        conn.execute(text("DELETE FROM game_config WHERE revision=2"))


def test_expired_and_banned_session(client, guest):
    player, headers, _ = guest
    with engine.begin() as conn:
        conn.execute(text("UPDATE players SET banned=true WHERE id=:p"), {"p": player})
    assert client.post("/v1/spins", headers=headers, json=key()).status_code == 401
    with engine.begin() as conn:
        conn.execute(text("UPDATE players SET banned=false WHERE id=:p"), {"p": player})
        conn.execute(
            text("UPDATE sessions SET expires_at=now()-interval '1 second' WHERE player_id=:p"),
            {"p": player},
        )
    assert client.get("/v1/player", headers=headers).status_code == 401


def test_appended_world_unlocks_without_second_completion_reward(client, guest):
    from copy import deepcopy

    player, headers, _ = guest
    config = client.get("/v1/config", headers=headers).json()
    final = config["worlds"][-1]
    with engine.begin() as conn:
        conn.execute(text("UPDATE players SET world_index=1 WHERE id=:p"), {"p": player})
        for building in final["buildings"]:
            conn.execute(
                text(
                    "INSERT INTO player_buildings(player_id,world_id,building_id,level) VALUES(:p,:w,:b,3)"
                ),
                {"p": player, "w": final["id"], "b": building["id"]},
            )
    before = client.get("/v1/player", headers=headers).json()
    assert before["campaign_complete"]
    appended = deepcopy(final)
    appended["id"] = "dawnreach"
    config["revision"] = 3
    config["worlds"].append(appended)
    with engine.begin() as conn:
        conn.execute(text("UPDATE game_config SET active=false"))
        conn.execute(
            text("INSERT INTO game_config(revision,body,active) VALUES(3,CAST(:b AS jsonb),true)"),
            {"b": json.dumps(config)},
        )
    current = client.get("/v1/player", headers=headers).json()
    assert current["world_index"] == 2 and current["world"]["id"] == "dawnreach"
    assert not current["campaign_complete"]
    assert current["coins"] == before["coins"] and current["spins"] == before["spins"]
    assert all(b["level"] == 0 for b in current["world"]["buildings"])
    assert client.get("/v1/player", headers=headers).json()["world_index"] == 2

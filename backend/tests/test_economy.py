import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from app.economy import progress, regenerate, select_symbols, slot_rewards, upgrade_price

CONFIG = json.loads(
    (Path(__file__).parents[1] / "config/economy.v1.json").read_text(encoding="utf-8")
)
NOW = datetime(2026, 1, 1, tzinfo=timezone.utc)


@pytest.mark.parametrize(
    "spins,maximum,elapsed,expected",
    [(0, 30, 299, 0), (0, 30, 300, 1), (28, 30, 900, 30), (40, 30, 900, 40), (0, 30, -900, 0)],
)
def test_regeneration(spins, maximum, elapsed, expected):
    actual, _ = regenerate(spins, maximum, NOW, NOW + timedelta(seconds=elapsed), 300)
    assert actual == expected


def test_full_energy_never_banks_time():
    s, t = regenerate(30, 30, NOW, NOW + timedelta(days=5), 300)
    assert s == 30
    assert t == NOW + timedelta(days=5)
    assert regenerate(29, 30, t, t + timedelta(seconds=299), 300)[0] == 29


def test_fractional_regeneration_preserved():
    s, t = regenerate(0, 30, NOW, NOW + timedelta(seconds=650), 300)
    assert (s, t) == (2, NOW + timedelta(seconds=600))


def test_progress_multiple_levels():
    assert progress(1, 0, 125, CONFIG) == (3, 0, 2)
    assert progress(1, 49, 0, CONFIG) == (1, 49, 0)


def test_weight_boundaries():
    for draw, expected in [
        (0, "coin"),
        (44, "coin"),
        (45, "bag"),
        (69, "bag"),
        (70, "energy"),
        (99, "jackpot"),
    ]:
        assert [s["id"] for s in select_symbols(CONFIG, lambda n: draw)] == [expected] * 3


def test_triple_and_mixed_rewards():
    symbols = CONFIG["symbols"]
    assert slot_rewards([symbols[0]] * 3, CONFIG)["coins"] == 162
    assert slot_rewards([symbols[0], symbols[1], symbols[2]], CONFIG)["coins"] == 63
    assert slot_rewards([symbols[2]] * 3, CONFIG)["spins"] == 3


def test_upgrade_config():
    b = CONFIG["worlds"][0]["buildings"][0]
    assert [upgrade_price(b, n) for n in range(3)] == [120, 240, 420]
    with pytest.raises(ValueError):
        upgrade_price(b, 3)

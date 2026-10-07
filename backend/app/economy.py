"""Pure economy calculations; time and randomness are injected by the server."""

from datetime import datetime, timedelta
from secrets import randbelow


def regenerate(spins: int, maximum: int, anchor: datetime, now: datetime, seconds: int):
    if spins >= maximum:
        return spins, now
    ticks = max(0, int((now - anchor).total_seconds()) // seconds)
    restored = min(maximum - spins, ticks)
    if spins + restored >= maximum:
        return spins + restored, now
    return spins + restored, anchor + timedelta(seconds=ticks * seconds)


def xp_required(level: int, config: dict) -> int:
    return config["xp"]["base"] + (level - 1) * config["xp"]["growth"]


def progress(level: int, xp: int, added: int, config: dict):
    xp += added
    levels = 0
    while xp >= xp_required(level, config):
        xp -= xp_required(level, config)
        level += 1
        levels += 1
    return level, xp, levels


def select_symbols(config: dict, draw=randbelow):
    symbols = config["symbols"]
    total = sum(s["weight"] for s in symbols)
    result = []
    for _ in range(config["slot"]["reels"]):
        value = draw(total)
        for symbol in symbols:
            value -= symbol["weight"]
            if value < 0:
                result.append(symbol)
                break
    return result


def slot_rewards(symbols: list[dict], config: dict):
    triple = len({s["id"] for s in symbols}) == 1
    coins = sum(s["coins"] for s in symbols)
    if triple:
        coins *= config["slot"]["triple_coin_multiplier"]
    return {
        "coins": coins,
        "spins": sum(s["spins"] for s in symbols),
        "xp": config["xp"]["spin"],
        "triple": triple,
    }


def upgrade_price(building: dict, level: int) -> int:
    if level < 0 or level >= len(building["costs"]):
        raise ValueError("Building is already complete")
    return building["costs"][level]

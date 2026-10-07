"""Validated, bounded economy documents for trusted CLI publishing."""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Positive = Annotated[int, Field(strict=True, ge=1, le=100_000_000)]
Amount = Annotated[int, Field(strict=True, ge=0, le=100_000_000)]
Id = Annotated[str, Field(pattern=r"^[a-z_]+$", min_length=1, max_length=64)]


class Model(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Brand(Model):
    title: str = Field(min_length=1, max_length=40)
    tagline: str = Field(max_length=150)


class Initial(Model):
    coins: Amount
    premium: Amount
    spins: Annotated[int, Field(strict=True, ge=0, le=10000)]
    max_spins: Annotated[int, Field(strict=True, ge=1, le=10000)]


class Energy(Model):
    cost: Annotated[int, Field(strict=True, ge=1, le=100)]
    regeneration_seconds: Annotated[int, Field(strict=True, ge=1, le=86400)]


class Limits(Model):
    max_multiplier: Literal[1]
    max_shields: Annotated[int, Field(strict=True, ge=0, le=10)]


class Xp(Model):
    base: Annotated[int, Field(strict=True, ge=10, le=1000000)]
    growth: Annotated[int, Field(strict=True, ge=0, le=1000000)]
    spin: Annotated[int, Field(strict=True, ge=0, le=10000)]
    upgrade: Annotated[int, Field(strict=True, ge=0, le=10000)]
    level_spins: Annotated[int, Field(strict=True, ge=0, le=100)]


class Symbol(Model):
    id: Literal["coin", "bag", "energy", "star", "jackpot"]
    label: str = Field(min_length=1, max_length=30)
    rarity: Literal["common", "rare", "epic", "legendary"]
    weight: Annotated[int, Field(strict=True, ge=1, le=1000000)]
    coins: Amount
    spins: Annotated[int, Field(strict=True, ge=0, le=100)]
    animation: str = Field(max_length=40)
    sound: str = Field(max_length=40)
    behaviour: Literal["reward"]


class Slot(Model):
    reels: Literal[3]
    triple_coin_multiplier: Annotated[int, Field(strict=True, ge=1, le=10)]


class Building(Model):
    id: Id
    name: str = Field(min_length=1, max_length=40)
    costs: list[Positive] = Field(min_length=1, max_length=20)


class Completion(Model):
    coins: Amount
    spins: Annotated[int, Field(strict=True, ge=0, le=1000)]


class World(Model):
    id: Id
    name: str = Field(min_length=1, max_length=40)
    description: str = Field(max_length=200)
    completion: Completion
    buildings: list[Building] = Field(min_length=1, max_length=10)

    @model_validator(mode="after")
    def unique_buildings(self):
        if len({b.id for b in self.buildings}) != len(self.buildings):
            raise ValueError("Duplicate building ids")
        return self


class EconomyConfig(Model):
    revision: Positive
    brand: Brand
    initial: Initial
    energy: Energy
    limits: Limits
    xp: Xp
    symbols: list[Symbol] = Field(min_length=1, max_length=5)
    slot: Slot
    worlds: list[World] = Field(min_length=1, max_length=100)

    @model_validator(mode="after")
    def unique_ids(self):
        if len({w.id for w in self.worlds}) != len(self.worlds):
            raise ValueError("Duplicate world ids")
        if len({s.id for s in self.symbols}) != len(self.symbols):
            raise ValueError("Duplicate symbol ids")
        return self


def validate_config(body: dict) -> dict:
    return EconomyConfig.model_validate(body).model_dump()


def validate_transition(old: dict, new: dict):
    if new["revision"] <= old["revision"]:
        raise ValueError("New revision must increase")
    if len(new["worlds"]) < len(old["worlds"]):
        raise ValueError("Cannot remove live worlds")
    for old_world, new_world in zip(old["worlds"], new["worlds"], strict=False):
        old_shape = [(b["id"], len(b["costs"])) for b in old_world["buildings"]]
        new_shape = [(b["id"], len(b["costs"])) for b in new_world["buildings"]]
        if old_world["id"] != new_world["id"] or old_shape != new_shape:
            raise ValueError("Live world/building identities and tier counts are immutable")

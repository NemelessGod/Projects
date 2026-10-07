from copy import deepcopy

import pytest
from pydantic import ValidationError

from app.configuration import validate_config, validate_transition
from tests.test_economy import CONFIG


def test_seed_valid():
    assert validate_config(CONFIG) == CONFIG


@pytest.mark.parametrize(
    "section,key,value",
    [
        ("energy", "regeneration_seconds", 0),
        ("xp", "base", 0),
        ("slot", "reels", 4),
        ("energy", "cost", -1),
    ],
)
def test_invalid_config(section, key, value):
    body = deepcopy(CONFIG)
    body[section][key] = value
    with pytest.raises(ValidationError):
        validate_config(body)


def test_live_config_cannot_erase_progress():
    body = deepcopy(CONFIG)
    body["revision"] = 2
    body["worlds"][0]["buildings"][0]["costs"].pop()
    with pytest.raises(ValueError):
        validate_transition(CONFIG, body)
    body = deepcopy(CONFIG)
    body["revision"] = 2
    body["energy"]["regeneration_seconds"] = 240
    validate_transition(CONFIG, body)

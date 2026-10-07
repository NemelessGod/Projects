# API v1

JSON REST, OpenAPI supplied by FastAPI. All gameplay endpoints require `Authorization: Bearer <guest token>`. Never log authorization headers. UUIDs are request keys, not authentication.

| Method | Path | Request / response |
|---|---|---|
| GET | /health | DB and active config readiness |
| POST | /v1/auth/guest | Create guest, returns token once and state; no credentials requested |
| GET | /v1/config | Active versioned economy config |
| GET | /v1/player | Authoritative state; persists server-time regeneration |
| POST | /v1/spins | `{ "idempotency_key": "UUID" }` |
| POST | /v1/buildings/upgrade | `{ "idempotency_key": "UUID", "building_id": "beacon" }` |

Command response: `{ operation_id, result, state }`. Spins return symbol IDs, rewards and level gains. Upgrades return server price, building ID and world completion. State includes identity, balances, XP/requirement, world/buildings, next regeneration time, monotonic-display countdown origin and config revision.

Extra request fields are rejected (422). Invalid/expired token 401, ban check 403 when session was authorized before ban, unknown building 404, insufficient resources/completed building/conflicting key 409. Transport failure/5xx may hide a committed operation: retry **same** key and payload. Never generate a new key for a pending command. No client time, payout, result, price, target player or XP fields are accepted.

Guest creation is not idempotent: loss of the first response can leave an orphan guest. No prior account gets economic rewards twice, but guest creation abuse requires production throttling. Token is saved before any gameplay request. Expiry does not silently create a new account; account recovery/linking is a later phase.

Google auth, attacks, raids, inventories, event claims, billing and admin HTTP routes are not implemented. Public API cannot grant arbitrary currency or modify config.

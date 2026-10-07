# PostgreSQL model

Migration: `backend/migrations/001_core.sql`, serialized using an advisory transaction lock and recorded in `schema_migrations`. Do not use ORM auto-create on startup.

Implemented normalized entities:

| Table | Purpose |
|---|---|
| players | Identity, cumulative level, within-level XP, current world, ban flag and timestamps |
| sessions | SHA-256 hash of high-entropy bearer token, 90-day server expiry |
| player_wallets | One row/player, nonnegative coins and premium |
| player_energy | One row/player, sparks/capacity and server regeneration anchor |
| player_buildings | Composite player/world/building identity and level |
| game_config | Immutable revision JSON and unique active revision |
| operations | Per-player unique UUID idempotency keys, action/payload hash, result and config revision |
| economy_ledger | Signed deltas, before/after constraints, reason and operation reference |
| spin_history | One history record per committed operation |
| schema_migrations | Applied versions |

Foreign keys and check constraints protect core invariants. Player/time indexes support bounded history queries. Operation references in ledger are deferred because ledger changes and saved response belong to the same transaction. Keep operation keys/results for the session lifetime and longer; naive pruning re-enables replay.

World/building definitions are versioned configuration rather than duplicate tables for the MVP. Future persistent inventories/cards/social/events will use relational keys and uniqueness on claims. They are designed in ROADMAP, not provisioned as empty tables.

Application database and dedicated `_test` database are separate. Tests enforce suffix protection before destructive truncation. Application process should receive least-privilege DB credentials in production, migrations use a separate role. Local Docker trust authentication listens **only on 127.0.0.1**, never suitable for public deployment.

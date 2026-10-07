CREATE TABLE IF NOT EXISTS schema_migrations(version integer PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE game_config (
 revision integer PRIMARY KEY CHECK(revision > 0), body jsonb NOT NULL,
 active boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_active_config ON game_config(active) WHERE active;
CREATE TABLE players (
 id uuid PRIMARY KEY, display_name text NOT NULL CHECK(length(display_name) BETWEEN 1 AND 32),
 avatar text NOT NULL DEFAULT 'navigator', level integer NOT NULL DEFAULT 1 CHECK(level > 0),
 xp bigint NOT NULL DEFAULT 0 CHECK(xp >= 0), world_index integer NOT NULL DEFAULT 0 CHECK(world_index >= 0),
 created_at timestamptz NOT NULL DEFAULT now(), last_login timestamptz NOT NULL DEFAULT now(),
 banned boolean NOT NULL DEFAULT false
);
CREATE TABLE sessions (
 token_hash text PRIMARY KEY, player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL
);
CREATE INDEX sessions_player ON sessions(player_id);
CREATE TABLE player_wallets (
 player_id uuid PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
 coins bigint NOT NULL CHECK(coins >= 0), premium bigint NOT NULL CHECK(premium >= 0)
);
CREATE TABLE player_energy (
 player_id uuid PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
 spins integer NOT NULL CHECK(spins >= 0), max_spins integer NOT NULL CHECK(max_spins > 0),
 regenerated_at timestamptz NOT NULL
);
CREATE TABLE player_buildings (
 player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
 world_id text NOT NULL, building_id text NOT NULL, level integer NOT NULL DEFAULT 0 CHECK(level >= 0),
 updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(player_id,world_id,building_id)
);
CREATE TABLE operations (
 id uuid PRIMARY KEY, player_id uuid NOT NULL REFERENCES players(id),
 idempotency_key uuid NOT NULL, action text NOT NULL, payload_hash text NOT NULL,
 config_revision integer NOT NULL REFERENCES game_config(revision), response jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(player_id,idempotency_key)
);
CREATE INDEX operations_player_time ON operations(player_id,created_at DESC);
CREATE TABLE economy_ledger (
 id bigserial PRIMARY KEY, player_id uuid NOT NULL REFERENCES players(id),
 operation_id uuid REFERENCES operations(id) DEFERRABLE INITIALLY DEFERRED,
 currency text NOT NULL CHECK(currency IN ('coins','premium','spins')),
 amount bigint NOT NULL, balance_before bigint NOT NULL CHECK(balance_before >= 0),
 balance_after bigint NOT NULL CHECK(balance_after >= 0), reason text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(balance_after = balance_before + amount)
);
CREATE INDEX ledger_player_time ON economy_ledger(player_id,created_at DESC);
CREATE TABLE spin_history (
 operation_id uuid PRIMARY KEY REFERENCES operations(id), player_id uuid NOT NULL REFERENCES players(id),
 symbols jsonb NOT NULL, rewards jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX spin_player_time ON spin_history(player_id,created_at DESC);
INSERT INTO schema_migrations(version) VALUES (1);

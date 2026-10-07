# Event engine design — PLANNED, NOT IMPLEMENTED

Versioned definition: `id, type, name, starts_at, ends_at, rules, multipliers, milestones, assets, leaderboard_enabled`. UTC timestamps, authoritative database time, validated bounded declarative rules; never accept executable scripts in config.

Committed economy operations publish domain events within the same database transaction (future outbox). Rule engine maps `spin`, `attack_resolved`, `raid_resolved`, `card_added`, `building_upgrade` to progress. Deduplicate by `(event_id, player_id, operation_id)`; unique `(event_id, player_id, milestone_id)` grants. Claim reward and ledger commit atomically. Events cannot retroactively grant from untrusted client analytics.

Tournament groups: fixed membership cohort, indexed score + stable tie-breaker, cursor pagination. Finalization jobs lock tournament and create unique inbox reward references. Repeat jobs are safe. End time/late-arrival policy and event/config revisions must be explicit.

Next steps after combat/inventory phases: schema, rule validation, fake-clock tests at boundaries, replay/concurrency tests, config publishing and server-controlled availability. No active event/tournament buttons claim to provide this functionality today.

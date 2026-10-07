# Development roadmap

0. Architecture, economy, schema, stack ADR.
1–4. First playable slice: guest, home, authoritative slot/energy/rewards, construction/XP/worlds, durable cloud saves and idempotency.
5. Combat: server-selected targets, single-use actions from spin result, deterministic locking of attacker/defender, shield consumption, history, hidden raid grid and limited picks.
6. Inventory: atomic chest opening, weighted server loot, card sets and unique completion claims.
7. Daily/wheel/missions/achievements: server eligibility, shared reward pipeline, unique claims and clock-boundary tests.
8. Events/tournaments/rankings: rules/outbox, unique milestones, bounded ranking pagination, safe finalization jobs.
9. Friends/inbox: bilateral relationships, limited gift quotas, immutable reward references, revenge authorization.
10. Shop/ad abstractions and live ops: clearly labelled mock development products, verified provider callbacks before production grants; no real payments without explicit approval.
11. Visual/audio polish, accessibility, profiling on modest Android phones, load testing/security hardening.
12. Account linking/recovery, HTTPS deployment, production signing/store packaging, privacy disclosures, release QA; publication requires approval.

Do not expand into later systems before the first vertical slice passes its checklist. No empty scaffolds are described as complete services. Development continues across sessions via PROJECT_STATE.md and TODO.md.

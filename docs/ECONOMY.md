# Economy v1 — development balance

Authoritative source: active `game_config.body` row. Seed: `backend/config/economy.v1.json`. Every operation records the exact revision. Seed migration never overwrites an existing revision.

- Guest starts with 300 coins, 20 sparks, capacity 30 and no crystals.
- Spin costs 1 spark; regeneration is 1 / 300 seconds using database time. Rewards may exceed capacity; no regeneration above capacity, no hidden time banking while full. Partial elapsed regeneration time is retained below capacity.
- Three independent cryptographically sampled weighted symbols. Weights sum to 100; weights are not client-selected.
- Each symbol pays its configured coins/spins; any identical triple multiplies coins by 3. Energy triple awards three sparks (no coin multiplier effect).
- XP requirements per next level: `50 + (level - 1) * 25`, carry excess XP through multiple levels. Spin = 2 XP, upgrade = 15 XP; each level awards 3 sparks.
- Upgrade prices are explicit lists per world/building. Server rejects completed buildings and insufficient coins. World completion grants configured rewards once and advances to next world, or marks final world complete.

Currency ledger includes initial grants, regeneration, spin debits/rewards, construction spending, level rewards and world rewards. Ledger balances must reconcile; failed operations roll back everything. XP is authoritative player progression with immutable operation responses, not spendable currency.

Balance is deliberately small for validation, not commercial tuning. Before live ops: simulate progression distribution, payout variance, economy sources/sinks, full-world costs, retention and abuse. No premium spending, real-money products, ads or rewards for client-reported achievements exist yet.

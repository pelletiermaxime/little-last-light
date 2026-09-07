# First-clear balance playtest

Target: roughly 9–12 attempts for a first clear, to be assessed through fresh-profile human play rather than enforced through a run-count gate.

## Changes

- Energy per second: low 0.6, medium 1.2, high 2.4 (increased 20% after run-four feedback). A three-minute high-brightness run earns 432 before upgrades.
- Energy Gain is a permanent Lantern upgrade: +25% passive income per level, capped at +125%. Levels cost 100, 200, 400, 800, and 1600 energy. It works at every brightness.
- Defeating the five-minute Drencher awards a fixed 300 energy once per run. This is included in run earnings, saved immediately, and identified in the results. Passive-income upgrades do not multiply this reward; merely ending a run or reaching five minutes does not grant it.
- All turret types cost 60, 85, 110, and so on, sharing the same price at a given layout size. The starter stays free; refunds return actual paid prices. New placements and moves require 72 pixels between turret centers, up from 36.
- All eight upgrades now have five levels. Prices double each level.
- Damage progresses 1 → 2.5 → 4 → 5.5 → 7 → 8.5, adding 1.5 per upgrade. The first upgrade one-shots a one-minute basic pursuer with proximity boosting.
- At level five: fire rate reaches 1.5 shots/second, health reaches 100 HP, slow activation reaches 2.25 seconds, duration reaches 2.05 seconds, and slow strength reaches 70%. Slow range is 175 pixels. Duration starts at 1.3 seconds and gains 0.15 per upgrade. A single fully upgraded slow turret still leaves a 0.2-second gap; this buffs coverage and duration without changing prices or pulse cadence.
- Pursuer spawn growth continues more slowly after 100 seconds. Minimum intervals are 0.25 / 0.15 / 0.10 seconds by brightness, before encounter-phase adjustments.
- Pursuers keep gaining 1 health per 30 seconds, plus 1 per 45 seconds after minute five. Their speed stays 85.
- Following the first player test, charger pressure cadence progresses from 4 seconds at introduction to 2.5 at two minutes, then 2 at ten minutes, with at most eight alive. After minute one, Gathering also spawns chargers at half the pressure frequency. Charge warnings, speed, and damage are unchanged.
- Recovery pursuer pressure rises from 25% toward 50% between minutes two and ten. After minute five, recovery permits occasional chargers at intervals of at least 12 seconds. Earlier recovery stops new chargers.
- Boss health, attacks, and arrival times are unchanged.
- The stationary ward has been removed. Damage turrets within 110 pixels receive ×1.5 damage and fire rate, including while the player moves. Proximity Power adds 0.1 to both multipliers per level, reaching ×2.0 at level five. It costs 150, 300, 600, 1200, and 2400 energy. Leaving range removes both bonuses. Slow turrets are excluded. The player ring, turret glow, and link identify the effect.

## Play locally

From the project directory:

```sh
godot --path . --script tests/launch_balance_test.gd
```

This uses a separate `user://balance-test-v1.json` profile, with normal encounter timings and leaderboard publication disabled. Progress is stamped with `application/config/version` from `project.godot`, independently of the `dev` leaderboard label. Changing that version starts fresh; restarting the same version keeps progress. Unstamped saves also start fresh. This balance build is 0.0.2, so the next launch resets the previous test progression. Audio/display settings are separate. No old-layout migration is needed.

For each attempt, note survival time, energy earned, purchases, brightness used, and what killed you. Early targets are roughly 2–4 minutes and a useful purchase choice, approaching the five-minute boss around runs 3–5, and the finale around runs 9–12. These are tuning goals, not verified outcomes.

For proximity boosting, watch whether chargers force you out of boosted positions, whether returning to a cluster feels rewarding, and whether the glow/link make the affected towers obvious.

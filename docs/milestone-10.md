# Milestone 10: swarm performance and leaderboard run details

M10 brings together the enemy-performance and leaderboard-run-details branches, including their integration with M9's upgrades, lower starting health, and results screen.

## What players get

Basic enemies and idle turrets do less repeated work as the swarm grows. Movement, spawn pressure, health scaling, and combat rules remain intact. This is a performance improvement, not a new difficulty milestone.

New leaderboard records can show energy earned, energy invested in the defense, and an expandable turret-layout diagram with upgrade levels. Survival time still determines rank. Older records explicitly show missing details as **Not recorded**, rather than implying zero investment.

## The idea to learn: drawing and moving are separate

Godot can reuse drawing commands while moving or rotating a canvas item. Previously, each basic enemy rebuilt its circles and health bar every frame. Its body now lives on a child canvas item that rotates toward its heading; the health bar stays upright and redraws when damage changes it. Chargers keep their animated telegraph and distinct appearance.

Turrets redraw when a shot starts or expires. Idle turrets search for targets every 0.1 seconds instead of every frame, and compare squared distances. The tradeoff is up to 0.1 seconds of acquisition delay, subject to frame duration; firing cooldowns are preserved.

Contact damage still applies immediately. The HUD displays accumulated hits on its existing 10 Hz update instead of rebuilding for every attacker. Death still refreshes the interface immediately and opens results.

The branch's headless benchmark reported substantially lower CPU frame times. Those are workload-specific historical measurements, not predictions of browser FPS. The population remains uncapped, so long rendered runs still need profiling. See the [original benchmark notes](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/docs/performance.md) for methodology and limits.

## The idea to learn: a record is a snapshot

A published score should describe the defense used for that run, even if the player later sells or moves turrets.

At run start, Main records defense investment: the actual purchase costs of current turrets plus all purchased damage, fire-rate, and health levels. Unspent savings, refunded turrets, and earnings from the new run do not count. The free starter contributes zero.

Upgrade prices double, so cumulative spending is:

```text
base × (2^level − 1) = next upgrade price − base
```

For example, damage level 2 costs 60 + 120 = 180. Three turrets contribute 50, fire-rate level 1 adds 50, and health level 1 adds 40: total investment is 320 energy.

When a personal best ends, its pending publication stores earnings, investment, normalized turret coordinates, arena dimensions, and upgrade levels. Retries and saved pending offers retain that snapshot after preparation changes or restarting the game. Development runs continue to stay local.

## Passing the snapshot through the leaderboard

The publication prompt explains that energy and turret positions become public. Convex validates bounded payloads, numbers, coordinates, and layouts; the website draws the diagram directly from data without uploading screenshots.

Optional fields preserve compatibility with old clients and records. A better score replaces the complete previous record so an older client cannot accidentally inherit another run's layout. Equal or lower scores leave the existing best unchanged. Legacy available-energy balances are not relabeled as investment.

## Verification and release

The merged project passed all 15 Godot regression suites. Leaderboard verification covers HTTP/database behavior, TypeScript, a production build, and desktop/mobile browser scenarios using mocked subscriptions rather than public test scores.

Deploy the updated Convex backend and leaderboard website before releasing the updated game. The GitHub game workflow does not deploy those services. Old records need no backfill; details that were never recorded cannot be reconstructed.

## Read this milestone's code later

- [enemy.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/enemy.gd) and [turret.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/turret.gd): cached drawings and target polling.
- [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/main.gd): investment calculation and saved run snapshots.
- [runDetails.ts](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/leaderboard/convex/runDetails.ts): layout validation.
- [TurretLayout.vue](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/leaderboard/app/components/TurretLayout.vue): diagram rendering.
- [Feature notes](https://github.com/pelletiermaxime/little-last-light/blob/milestone-10/docs/leaderboard-run-details.md): compatibility and deployment details.

# Leaderboard run details

Each newly completed personal best now saves and submits both energy figures and a snapshot of its turret layout:

- **Earned:** energy generated during that run.
- **Invested:** actual purchase costs of the current turrets plus cumulative costs of persistent damage, fire-rate, and health upgrades, recorded at run start. The starting turret is free. For example, three turrets without upgrades represent 50 invested energy. Damage level 2, fire-rate level 1, and health level 1 add 270 energy. Unspent savings and refunded/sold turrets are excluded.
- **Turret layout:** normalized turret coordinates and arena dimensions, captured before returning to preparation. Moving turrets, resetting the layout, retrying publication, or reopening the game preserves the completed record's snapshot.

The website shows invested energy first, followed by run earnings, beside survival time. This lets players compare survival against the progression supporting each defense. An expandable **Turret layout** diagram displays the saved defense pattern, with blue turret markers, an arena-center guide, and the recorded damage, fire-rate, and health upgrade levels. It supports keyboard interaction and mobile screens. It is a diagram generated directly from run data; screenshot uploads and image storage are unnecessary.

Older scores and pending offers continue to work. Missing details are explicitly marked **Not recorded**, while actual zero energy remains zero. Equal or lower submissions preserve the existing best and its details. A better submission replaces the complete record, including clearing previous details when an old client submits it.

The earlier preview's available-energy balance is not defense investment. Existing `totalEnergy` values remain compatible with storage and submission but are not shown as investment. New game runs send `energyInvested` instead. Previously published test records may show investment as **Not recorded** until a new best is published from the updated game.

The publication prompt now tells the player that energy and turret positions will be public. Duration still determines rank. The server validates energy, arena dimensions, coordinates, turret count, and request size.

## Verification

- Six Convex HTTP/database tests passed, covering both new and old submissions, validation, privacy, record replacement, layouts larger than the old request limit, and never mislabeling old balances as investment.
- Nuxt and Convex TypeScript checks passed.
- Production Nuxt build passed.
- Eight Playwright tests passed across desktop and mobile, including energy display, exact diagram coordinates, keyboard expansion, live updates, missing legacy data, and no page overflow.
- Godot integration checks cover purchase costs, persistent upgrade spending and levels, free starter, exclusion of banked savings and run earnings, refund/reset behavior, persistence, death, and voluntary End Run. Results-screen and performance changes from main are integrated; the performance test uses current health and the results phase.
- `git diff --check` passed.
- Desktop and mobile screenshots were visually inspected. Browser checks used mocked Convex subscriptions against the real built website; no test scores were submitted to a hosted database.

## Deployment

Deploy the updated Convex backend and website before releasing the updated game. Existing records do not require a database backfill, and their original energy/layout cannot be reconstructed retrospectively. Browser tests regenerate desktop and mobile preview screenshots under `leaderboard/test-results` using test records.

## Turret types

New game builds include `type: "damage" | "pulse"` with each submitted turret position. The backend preserves this optional field in both HTTP and realtime results. The website shows damage turrets as blue circles and slow (`pulse`) turrets as purple diamonds, with counts in the legend. Older positions without a type appear gray and are labeled **Type not recorded**; their type cannot be inferred from position. Previously published game builds continue to submit untyped positions until updated, and existing pending offers retain their original snapshot.

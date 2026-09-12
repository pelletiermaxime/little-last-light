# Achievements

The game tracks four lifetime milestones in unassisted play: `first_tower`,
`defeat_drencher`, `defeat_rainkeeper`, and `defeat_snuffer`. The free starting
tower, moving a tower, and failed purchases do not unlock `first_tower`.
Boss unlocks require an actual defeat during a running game with a living lantern.
The website displays live community counts and percentages below the leaderboard.

## In-game menu and notifications

Open **Achievements** from preparation to see all four milestones, descriptions,
locked/unlocked states, your completion count, and the current save/sync status.
The page has a Sync achievements button and supports keyboard/controller Back
navigation and the preparation menu's touch layout.

Each newly earned achievement displays a four-second popup with its name and
description plus the existing upgrade sound. Popups queue, do not block input,
and do not pause play. Loading an existing unlock does not replay the popup.

The catalog is currently defined in code: `game/achievement_tracker.gd` supplies
the offline game catalog and `leaderboard/convex/achievementCatalog.ts` supplies
the backend/website catalog and accepted IDs. New milestones require updating
both, adding the gameplay trigger, and shipping an updated game.

## Identity and persistence

Achievements send the same private 64-character device token as scores. Both
endpoints derive `playerHash = SHA-256(token)` on the server. No username or
published score is required. The API does not accept a public hash as proof of
identity and never exposes tokens, hashes, or individual unlock histories in stats.
As with scores, these are client-reported milestones, not server-verified gameplay.

`<save_path>.achievements-editor.json` and `<save_path>.achievements-export.json`
store the token, unlocks, and participation flag separately for editor and exported
games, so editor testing cannot upload its unlocks to production. The original
pre-release `<save_path>.achievements.json` is adopted only by editor builds.
These files are stored separately from gameplay progress. Existing score tokens are adopted, including
when a version update discards the gameplay save. Future score submissions use
this durable identity too. Resetting gameplay preserves achievements and identity;
deleting local data or using another device/browser profile creates another identity.
Unreadable achievement files are preserved and tracking stops for that session.

The client persists before uploading, sends its complete unlock set, and retries
failed uploads every 30 seconds while open, with a 10-second request timeout.
Reloading retries stored progress. A successful older request never acknowledges
unlocks earned while it was in flight. Editor play uses `leaderboard/dev_api_url`
(`https://notable-giraffe-170.convex.site`); exported builds use `leaderboard/api_url`.
The leaderboard and achievement tracker share this endpoint selection. Automated
headless achievement checks stay offline. Development and production use separate
Convex environments; there is no achievement scope field.

## HTTP contract

`POST /achievements`, with `Content-Type: application/json`:

```json
{"token":"<the same 64-character token used for scores>","unlocked":["first_tower"]}
```

An empty `unlocked` array registers participation without awarding anything. The
client registers on the first eligible run or purchase, not merely opening a menu.
The response is `{"ok":true}`. Unknown IDs, invalid tokens, malformed JSON return 400; non-JSON requests return 415; bodies above 4096
characters return 413. Browser OPTIONS preflight is supported.

`GET /achievements` returns the environment's population and all four catalog entries:

```json
{"totalPlayers":2,"achievements":[{"id":"first_tower","name":"Growing the Light","description":"Buy your first tower.","unlockedPlayers":1,"percentage":50}]}
```

The example abbreviates the catalog. Counts use unique tracked identities, including
zero-unlock players. Percentages are `unlockedPlayers / totalPlayers * 100`, or zero
when nobody is tracked; the website shows a dash for that empty population.
Historical scores are not backfilled because they cannot prove these milestones.
All game versions share lifetime stats within a Convex environment. Development
achievements belong in the development Convex environment; production achievements
belong in production. There is no scope or version parameter in the achievements API.

## Convex model

- `achievementPlayers`: one participation row per player hash.
- `playerAchievements`: one unlock per player hash and catalog ID; timestamp
  is first server receipt, not an inferred offline event time.
- `achievementCounts`: population and per-achievement counters, updated in the same
  transaction as registration/unlocks. Indexed queries avoid scanning player rows.
- `achievementCatalog.ts`: stable IDs, names, descriptions and input validators.
- `api.achievements.stats({})`: public reactive query for the website.
- `internal.achievements.sync`: internal write function; the HTTP action derives identity.

Repeated reports are idempotent. Do not manually delete source rows without also
repairing their counters. New milestone IDs require coordinated catalog, client
and test updates; if introduced after launch, decide explicitly whether they use
the existing lifetime population or a new eligibility cohort.

## Validation and release

Run `pnpm test` and `pnpm typecheck` in `leaderboard`, and
`godot --headless --path . --script tests/check_achievements.gd` from the game root.
Deploy the Convex backend before publishing the updated website and game, using
the existing release process in `leaderboard/README.md`. Until deployment, exported
clients retain unlocks locally and retry. No database migration or backfill is needed.

Implementation validation (2026-09-12): 16 Convex/Vitest tests, 14 desktop/mobile
browser tests, TypeScript checks, and the Nuxt production build passed. Godot's
achievement, leaderboard, reset-progress and Rainkeeper checks passed; the final
achievement run produced no stderr. Desktop and mobile screenshots were visually
inspected using fixture counts, not production player data. `git diff --check`
passed. The development Convex backend was deployed to `notable-giraffe-170`, and
the user's existing first-tower unlock was synced successfully (HTTP 200; one
tracked player and one first-tower unlock). On 2026-09-12, production Convex
(`judicious-meerkat-207`) and the Cloudflare Pages website were also deployed.
The public website was verified rendering all four achievements with its separate
production population (zero tracked players at verification). Deployment URL:
https://76f3c482.little-last-light-leaderboard.pages.dev . The local dev server was
stopped. Game and website changes remain uncommitted; the game itself was not released.

The new `tests/check_achievement_ui.gd` checks menu navigation, locked/unlocked
rows, popup deduplication/expiry, compact layout and editor endpoint selection.
It also ran in native Godot for screenshot inspection of the page and popup.
The menu-pages and touch-control regression checks passed after the UI additions.

Pre-release cleanup validation: all 47 Godot checks passed, including editor/export
achievement isolation and legacy editor-file migration. All 19 Python release
tests, 16 backend tests, 14 browser tests, type checks and the website build passed.
Web and Linux test exports succeeded; the Linux export booted with temporary user
data. The local Windows export could not run because its export template is not
installed; CI installs the matching Windows release template before exporting.

The HTTP integration and transactional counter updates follow Convex's official
[HTTP actions](https://docs.convex.dev/functions/http-actions) and
[atomicity](https://docs.convex.dev/database/advanced/occ) documentation.

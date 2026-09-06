# Little Last Light leaderboard

Nuxt 4 website and a **separate** Convex backend. NHL Stats is a stack reference only; do not use its deployment, credentials, or database. The Godot game stays a native Godot project. This folder's `.gdignore` keeps website dependencies out of game imports and exports.

## Local setup

Requires Node 24 and pnpm 10.33.0.

```sh
cd leaderboard
pnpm install
pnpm dev:convex
```

Choose/create a **Little Last Light** Convex project when prompted. Convex writes deployment configuration to `.env.local`. The website uses `better-convex-nuxt` (matching nhlstats) and live `useConvexQuery` subscriptions. Add `NUXT_PUBLIC_CONVEX_URL=https://…convex.cloud` to `.env` for Nuxt, then start the website:

```sh
pnpm dev
```

The default website is at `http://localhost:3000`. The Godot game publishes over HTTP: set `leaderboard/api_url` to the matching `https://…convex.site` URL and `leaderboard/site_url` to the website URL in `project.godot`, or use the build variables below. The website's `.convex.cloud` URL and the game's `.convex.site` URL must refer to the same deployment. Leave the URLs blank to keep online features unconfigured; the game remains playable and explains that records are local.

## Production

### Cloudflare Pages

Published at **https://little-last-light-leaderboard.pages.dev/**. The public page was verified in a browser and successfully loaded the current version and published score from Convex. It retains the live subscriptions implemented by `better-convex-nuxt`.

This site uses a static Nuxt export on Cloudflare Pages, with live browser subscriptions to Convex. `wrangler.toml` points Pages at `.output/public`; it does not need a Worker server or `nodejs_compat` bindings.

First-time CLI setup:

```sh
pnpm exec wrangler login
pnpm exec wrangler pages project create little-last-light-leaderboard --production-branch main
pnpm run deploy
```

After setup, `pnpm run deploy` deploys the Convex backend and generates the website with that deployment's URL injected as `NUXT_PUBLIC_CONVEX_URL`, then uploads the site to the Pages production branch. With the local development selection in `.env.local`, `convex deploy` targets the project's production deployment. In CI, any `CONVEX_DEPLOY_KEY` must belong to production. The injected URL overrides the development URL in `.env` during generation. Changing a Pages runtime variable cannot change a URL already embedded in a static export. Use `pnpm run deploy` explicitly: `pnpm deploy` is pnpm's unrelated built-in workspace command.

The first deployment uses Wrangler Direct Upload. Subsequent publication is through the same command or Wrangler in CI; this does not create Cloudflare's native Git integration. The game itself continues to be hosted by the existing GitHub Pages workflow.

### Production backend and game configuration

1. Run `pnpm run deploy` to deploy the production backend and website together.
2. The production backend is `judicious-meerkat-207`: website subscriptions use `https://judicious-meerkat-207.convex.cloud`, and published games use `https://judicious-meerkat-207.convex.site`. Production scores are separate from development scores; test records are not copied.
3. Set the game repository's public Actions variables `LEADERBOARD_API_URL` (the `.convex.site` API) and `LEADERBOARD_SITE_URL` (the hosted website). `scripts/build-release.sh` embeds them in all three game exports. These are public addresses, not secrets. Local exports accept the same environment variables. Release stamping already supplies the exact version used by the game.
4. Build and play an exported game; beat a record, publish a username, then verify that exact release on the website. Desktop and Pages clients use the same JSON API with browser CORS preflight support.

There is no version registration step. Each score carries the game's release version, and the website discovers versions from published scores automatically. A direct link such as `/?version=0.0.1` works even before that release has any scores.

The existing Pages game deployment stays in place; the website has a separate hosting lifecycle. CI validates the website and backend without needing a Convex account.

## Configured development deployment

Created with the Convex CLI on 2026-09-05:

- Project: `little-last-light`, team `maxime-pelletier-5d389`.
- Deployment: `dev/maxime` (`notable-giraffe-170`), US East.
- [Convex dashboard](https://dashboard.convex.dev/t/maxime-pelletier-5d389/little-last-light/notable-giraffe-170).
- HTTP API: `https://notable-giraffe-170.convex.site`.
- Website subscription URL: `https://notable-giraffe-170.convex.cloud`.
- Table: `scores`, with the three indexes from `convex/schema.ts`.
- All valid release version strings can accept scores without registration.

The CLI selection is saved in ignored `.env.local`. The website's ignored `.env` points to the development cloud subscription URL. Run `pnpm dev` in this folder to open the leaderboard website locally. Run `pnpm dev:convex` when editing backend functions, or `pnpm exec convex dev --once` for a single push. After installing the module or changing the environment, restart an already-running Nuxt server and reload the browser once to load the updated application.

The game in `project.godot` uses the production API and public Cloudflare website, including when launched locally for testing. For isolated development testing, change its API to `https://notable-giraffe-170.convex.site` and website to `http://localhost:3000` together. GitHub Actions variables `LEADERBOARD_API_URL` and `LEADERBOARD_SITE_URL` point future game exports to the production API and public website. Existing exported games need to be rebuilt to pick up these settings; restart a running local game after changing its URLs.

## Behavior and data

- Both the version selector and the selected board subscribe to public Convex read queries through `useConvexQuery`, with subscriptions enabled and authentication disabled for these public results. Version arguments are reactive; switching versions replaces the active board subscription. New scores update the page automatically, without polling or a Refresh button. The write mutation remains internal behind the validated Godot HTTP endpoint, and public queries omit device hashes.

- Survival duration, in integer milliseconds, determines the top 100 for each exact semantic version. Ties are displayed in Convex index order (newer document first for equal duration); ranks are sequential.
- New records snapshot `energyInvested` (energy spent on the defense at run start), `energyEarned` (earnings from this run), and `turretLayout`. Investment sums the actual purchase costs of the current turrets and cumulative spending on persistent damage, fire-rate, and health upgrades. The starting turret is free. Sold/refunded turrets, unspent savings, and run earnings are excluded. This gives survival records context about how much progression supported the defense. The layout contains arena `width`/`height`, normalized `{ x, y }` turret positions in the range 0–1, and optional `upgrades` levels (`damage`, `fireRate`, `health`). The origin is at the top left. The website renders a responsive SVG diagram at the saved arena aspect ratio and displays the recorded upgrade levels; no screenshot upload or image storage is needed. The center marker is an arena reference, not a recorded player position.
- Defense investment is captured at run start. Earnings and layout are captured on death or voluntary End Run before earnings are banked and cleared. The pending offer retains the original snapshot through layout changes, resets, retries, and reopening. Publication discloses that energy and the turret layout become public. Both energy figures are displayed as whole units, rounded down to match the game; fractional values remain stored.
- These fields are optional for existing scores and old game clients. Missing values display as “Not recorded” rather than zero; an explicitly empty layout means zero turrets. Duplicate, tied, and lower submissions do not replace an existing best's details. A better run replaces the whole score, clearing obsolete details if submitted by an older client. Old scores cannot be reconstructed from the player's current preparation layout.
- The HTTP endpoint validates finite, non-negative energy, arena dimensions of 1–16,384, and at most 1,024 normalized turret positions. Investment and earnings are independent; a free defense can earn energy. The earlier preview's `totalEnergy` field remains accepted for compatibility but is not displayed or interpreted as investment. JSON bodies are capped at 131,072 characters, allowing layouts beyond the previous 2,048-character limit. These are storage/input bounds, not anti-cheat guarantees.
- Each device/save has a cryptographically random token. The backend stores its SHA-256 hash and keeps one best score per token and version. It never returns tokens or hashes in public results. Repeated requests and lower scores are idempotent; improving writes have a five-second per-device cooldown.
- A username uses 3–20 ASCII letters, numbers, or underscores. It is a non-unique display name, not a login or proof of ownership. A better score may change it. Different devices can share a name and have separate entries; deleting a save creates a new identity.
- Nothing publishes automatically. The preparation sidebar offers publication after a new completed personal best. “No thanks” clears the offer. A failed/unfinished offer and username survive reopening; a newer best replaces the pending offer. Local saving must succeed before publication. Continuing to play during a request cannot erase a newer pending record.
- Local records are keyed by release. Energy and turret positions carry forward. Existing unversioned best times are preserved as `legacy_best_time`, without guessing which release produced them. They do not prevent setting a record in a new version.
- This is an **unverified community leaderboard**: clients report their own durations and versions, and progression/turrets carry between runs. Input limits (maximum 24 hours), version format validation, idempotency, and a device cooldown are not anti-cheat or robust abuse prevention. New tokens can bypass the cooldown. Add server-verified runs and stronger abuse controls before offering prizes or competitive rankings. Never embed a deployment/admin key in Godot.

## Checks

Deploy the updated Convex schema/functions before publishing the updated website and game builds. Optional fields require no backfill. The game and leaderboard have separate release pipelines; a local worktree change does not update either hosted application.

```sh
pnpm check
pnpm exec playwright install chromium
pnpm test:browser
godot --headless --path .. --script res://tests/check_leaderboard.gd
```

Vitest uses `convex-test` in the edge runtime, with tests under `convex/` as required by the project's Convex guidelines. It exercises the actual HTTP actions and database functions: validation, CORS, privacy, version isolation, ranking, duplicate/lower submissions, updates, cooldown, and the top-100 limit. Godot checks cover save migration, version records, opt-in controls, focus, retry state and responses arriving after a newer record.

Playwright starts and stops the production Nuxt build on port 3187. Tests mock the Convex WebSocket protocol while running the real module and client. They push new scores and new versions after initial page load, verify automatic display changes, check that switching versions removes the old subscription, and cover empty deep links, initial error recovery, and desktop/mobile layout. It needs `pnpm build` first (included in `pnpm check`). These browser tests do not submit real records.

The realtime integration passes three edge-runtime Convex tests, Nuxt/backend type checking, the production build, and six Playwright desktop/mobile checks. The browser tests prove later WebSocket updates change the score and version selector without reloads. The updated local page was also opened against the real development deployment and successfully displayed the existing published record. No synthetic scores were added to the live database for these checks. Earlier game changes passed all seven Godot check scripts and seven Python tests. Convex retains the obsolete `versions` table's data after schema removal; the application no longer reads or writes it and no maintenance is required.

Implementation references: [Convex HTTP actions](https://docs.convex.dev/functions/http-actions), [Convex realtime queries](https://docs.convex.dev/realtime), and [better-convex-nuxt](https://github.com/lupinum-dev/better-convex-nuxt).

# M16 — The Snuffer and dawn

**Encounter revision:** the initial sweep/pursuit described below was replaced
after the user's playtest. See [the current bullet-hell design and validation](milestone-16-bullet-hell.md).
The victory, persistence and leaderboard contract below remain in place.

Implemented in the separate `38ae/little-last-light` worktree. No merge, push,
deployment, source-checkout edits, or release-version changes were performed.

## What this milestone teaches

A boss is a small timed state machine. `snuffer.gd` separates arrival, warnings,
active attacks and recovery instead of combining movement and damage in one timer.
Each update consumes time up to the next boundary before advancing the state.
This keeps warning duration and one-hit attacks consistent across frame sizes.

The pursuit snapshots a direction at the start of its warning. Its damage check
intersects the full movement segment with the lantern's contact circle. Checking
only the end position would allow a long frame to pass through the lantern
without registering a hit. Sweep damage happens once at the warning boundary;
its preview remains fixed, so leaving the fan is a reliable response.

The run controller owns the outcome. Boss defeat calls the same guarded `end_run`
path as lantern death. Changing phase before banking or cleanup prevents another
signal from recording or paying the result twice. Visual animation belongs to the
results screen and cannot delay saving or leave combat active.

## Encounter rules

- At 15:00, `update_final_encounter()` spawns the Snuffer once. Ordinary enemies,
  chargers, any undefeated Drencher and all water hazards are removed. The HUD
  explicitly says the lesser threats retreat. Drencher scheduling at 5:00 stays.
- Three seconds of arrival protection allow the warning to remain visible even
  inside a powerful turret layout. Turrets acquire the boss through the existing
  `enemies` group and use the normal `take_damage` interface afterward.
- Health: 1,200. Sweep: fixed 120-degree fan, 170-pixel radius, 1.3-second warning,
  one 22-damage hit and a short visible follow-through. The lantern's radius adds
  12 pixels of contact allowance at the outer edge.
- Pursuit: fixed direction, 1.3-second warning, 190 pixels/second for 2.4 seconds,
  one 18-damage hit at most. Arena clamping prevents the boss leaving the field.
  There are no additional body-contact attacks or persistent ground hazards.
- Attacks alternate, separated by 2.4 seconds of recovery. Below 35% health,
  future recoveries shorten to 1.4 seconds. This is the sole low-health behavior
  change; warnings and movement speed do not become faster.
- All damage goes through `lantern.take_damage`, the M15 ward integration point.

## Victory, failure and persistence

Victory stops combat immediately, banks current earnings once, saves, and shows
“Dawn has come” with a two-second warm wash. The existing Continue button returns
to preparation. Leaving the screen kills the tween and restores its normal color.

Total clear time is the run clock at the killing blow, including the final fight
and arrival warning. Night survival stops at 900 seconds for newly recorded runs.
The results show total time separately from night survival after 15:00.

`last_run.victory` distinguishes success. `version_clears` stores the fastest
total clear time per game version in seconds. Both fields are additive; save
format version 1 and the existing save filename remain. Missing clear data means
no recorded clear. Historical survival bests, including records longer than 15
minutes, remain untouched and valid. Clear time and pending publication are saved
before displaying results. A slower clear or later defeat does not overwrite a
better pending clear.

Same-update resolution is explicit and sequential: the first terminal event wins.
If lantern death is processed first, the run is a defeat and boss signals cannot
upgrade it. If boss death is processed while lantern health is positive, victory
ends combat and subsequent damage is ignored. There is no posthumous clear and no
deferred frame-end arbitration. Repeated death/defeat calls cannot bank again.

## Leaderboard contract and authorization

The existing anonymous 64-hex-character device token is validated by the HTTP
endpoint and SHA-256 hashed server-side. Only the internal mutation writes scores;
public queries omit token/hash. This remains a community-submitted, unverified
leaderboard, not server-authoritative gameplay. No authentication model changed.
Release and `dev` partitions retain the existing version validation and selection.

Optional `clearTimeMs` represents a completed run; missing means survival-only.
A clear requires integer `durationMs = 900000` and an integer total clear time
between 900000 and 86400000. Old payloads and rows remain accepted.

Clears rank first, fastest total clear time first; survival-only rows follow,
longest survival first. A first clear replaces that device/version's survival
record. Faster clears replace slower ones. Neither a slower clear nor an older
client's longer survival score can replace a clear. Existing five-second publish
throttling and idempotent no-improvement retries remain. The compound optional
field index makes both sections bounded, with at most 100 total public rows.
Equal scores retain the existing index creation-time tiebreak behavior.

The game publication prompt, in-game rows and website distinguish clear time.
Historical rows without clear metadata retain their original values and survival
ordering. This does not require rewriting stored rows.

## Integration notes for M14 and M15

1. **M15 scheduling:** call `update_final_encounter()` before ordinary encounter
   scheduling and return from that scheduling branch if it returns true. Keep
   autosaving outside this early return. The helper performs the final transition
   and reports whether final combat owns the arena. The individual ordinary spawn
   helpers also reject calls once `final_boss_spawned` is true. Reset this flag in
   `start_run`; retain `_clear_enemies` removal of `final_bosses`.
2. **M14 slow:** this implementation deliberately does not implement slow. Snuffer
   extends `enemy.gd` but overrides `_process`, so merely adding slow handling to
   the base enemy's process function will not affect pursuit. At integration, tick
   the shared slow timer once per actual delta and apply the shared boss movement
   multiplier to `PURSUIT_SPEED` displacement. Keep warning/recovery clocks at
   normal speed. Adjust pursuit preview length to the effective movement speed;
   do not slow the windup or permit permanent immobilization. Clear effects through
   normal node cleanup. Reuse M14's boss susceptibility rule rather than adding a
   second independent slow policy.
3. **M15 ward:** both attacks call `take_damage` once per attack. Verify stationary
   protection does not allow the lantern to ignore both attacks indefinitely.
4. Expected merge overlap: `main.gd` constants, `start_run`, `_process`, save/load
   validation, and `game_hud.gd`. Preserve M14 layout metadata changes inside
   `_run_turret_layout` and pending submissions. Snuffer, results and backend clear
   representation are M16-owned changes.
5. Deploy backend schema/index and clear-aware code before releasing the game.
   The old backend strips unknown metadata, so publishing a new clear to it would
   silently lose clear semantics. Nothing was deployed here. Keep this gate in
   the combined release review and assign the new game version through the usual
   release tooling. If the production table is large, stage/backfill the new index
   first, then enable its queries in a subsequent deployment.

## Validation and playtest evidence

- All 24 `tests/check_*.gd` Godot scripts passed headlessly, including existing
  Drencher, movement, charger, save/run, leaderboard, results, pause, build and UI
  regressions. The M16 script was extended and rerun after that full pass.
- `check_final_encounter.gd` covers 14:59.99/15:00, spawn once, ordinary-spawn
  suppression, live Drencher/water cleanup, full arrival protection, warning
  duration, one-hit sweep, locked pursuit, swept collision, low-health behavior,
  pause, ordinary turret damage, both death orderings, single banking, results,
  slower/faster clear selection, pending record preservation, legacy save validity,
  invalid clear data, reload, paused End Run and restart.
- `playtest_final_encounter.gd` compares the same six fully upgraded damage
  turrets and 85-HP lantern. Stationary: defeat after 44.9 fight seconds. A normal
  speed orbit through the defense: victory after 88.4 seconds with 63 HP. This is
  a deterministic positioning probe, not a human playtest or a full progression
  run. No M14/M15 mechanics are present in this isolated worktree.
- All 9 Convex/Vitest HTTP contract tests passed, including mixed legacy/clear
  ordering, first/faster/slower clear replacement, old-client protection, identity
  privacy, release partitioning, validation and the 100-row cap.
- Convex TypeScript check and Nuxt prepare/typecheck/build completed successfully.
  Nuxt typechecking reported an existing installed-dependency warning resolving
  `vue-router/volar/sfc-route-blocks`, despite exit 0. Dependencies were copied into
  this worktree from the existing source installation after offline pnpm failed
  to open its database; package/lock files were not changed.
- Native rendered regression captured `/tmp/lll-final-sweep.png` and
  `/tmp/lll-final-results.png`; both were visually inspected. Initial sandboxed
  runs could not access the display; approved native execution succeeded. Native
  startup also reports the existing settings anchor warning. Verbose inspection
  traced shutdown resource warnings to unfinished Ogg confirmation/back playback
  after many scripted run transitions. This focused test now mutes its audio
  in memory and yields after scene cleanup; audio has separate regression coverage.
  No screenshots imply interactive human input was exercised.

## Remaining combined checks

The complete fresh-profile path to 15:00 depends on M15 pacing and must be tested
after integration. Pulse/ward synergy, an all-damage versus mixed layout comparison,
small-window/controller readability and browser end-to-end persistence also need
the combined build. Boss numbers and the provisional name/design remain tuning
choices. Native focused evidence supports readable positioning; it does not prove
the full 15-minute progression is balanced or enjoyable yet.

## Changed files

- `snuffer.gd` (+ UID): boss state machine and procedural warning/body drawing.
- `main.gd`: final scheduling boundary, outcome handling and additive clear saves.
- `game_hud.gd`: Snuffer name, arrival message and attack instructions.
- `results_screen.gd`: victory recap, separate clocks and dawn tween cleanup.
- `leaderboard_panel.gd`: clear-aware publication and score labels.
- `leaderboard/convex/schema.ts`, `scores.ts`, `validation.ts`: optional clear
  contract, bounded ranking and best-score replacement.
- `leaderboard/app/pages/index.vue`: website labels and ranking explanation.
- `leaderboard/convex/scores.test.ts`: clear HTTP contract regressions.
- `tests/check_final_encounter.gd`, `tests/playtest_final_encounter.gd`: regression
  coverage, native captures and deterministic positioning comparison.
- `docs/milestone-16.md`: this learning and integration report.

Useful commands from this worktree:

```sh
rtk proxy godot --headless --path . --script res://tests/check_final_encounter.gd
rtk proxy godot --headless --path . --script res://tests/playtest_final_encounter.gd
rtk proxy godot --path . --log-file /tmp/lll-m16-visual.log --script res://tests/check_final_encounter.gd -- --capture-final
```

From `leaderboard/`, run the installed Vitest entrypoint, Convex `tsc`, and Nuxt
`prepare`, `typecheck`, `build`. Use the project's regular pnpm scripts when its
environment/store is available.

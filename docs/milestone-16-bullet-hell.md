# M16 — Bullet-hell revision

The user found the original Snuffer too easy and too similar to an ordinary
pursuer. The boss now fires reusable droplets and drifts between patterns. Sweep,
pursuit and body-contact damage have been removed. The existing victory, banking,
save compatibility and leaderboard work remain unchanged.

## Patterns

- **Cyan aimed volleys:** one-second warning, then eight five-droplet volleys
  spaced 0.32 seconds apart. Each volley aims at the current lantern position;
  droplets retain their launch velocity. Speed is 215 pixels/second, slightly
  below the lantern's movement speed. Leading a stream and then changing route
  lets the player dodge while remaining near the defense. The five-wide fan keeps
  the original 0.14-radian spacing and extends to +/-0.28 radians.
- **Lavender 360-degree rings:** one-second warning, then all 36 droplets fire
  around the full circle at 165 pixels/second. No sector is omitted. A complete
  circular warning replaces the previous gap indicator. Moving away from the
  boss gives the droplets space to separate before weaving between them.
- **Below half health:** ring patterns emit three waves, 0.85 seconds apart,
  rotating each successive wave by half a droplet spacing (five degrees), so
  the spaces between droplets shift. Warnings and projectile speed do not change.
- **Recovery:** 1.8 seconds of slow drift toward successive positions around the
  arena center. The boss stays still while firing and never chases on contact.
  Existing droplets remain active during recovery, so the arena is not instantly
  safe when the boss stops shooting.
- **Desperation at one-third health (400/1,200 HP):** repositioning speed rises
  from 85 to 212.5 pixels/second (2.5x), and recovery lasts 1.2 seconds. A current
  recovery is capped at 1.2 seconds remaining. Active warnings/volleys are not
  interrupted, and the boss remains stationary while firing. Bullet speeds and
  the five-wide/triple-ring patterns are unchanged. A three-second “DESPERATION”
  announcement and permanent amber corona mark the transition. Repeated hits
  cannot retrigger it; a killing blow skips the phase announcement.

Health remains 1,200. Arrival protection remains three seconds. Normal arrival is
15:00; `tests/launch_final_encounter.gd` overrides the runtime deadline to 01:00,
uses a temporary save and disables publishing. It provides six upgraded turrets,
85 HP and 1,000 energy for interactive testing from preparation.

Following the user's second playtest, final arrival now preserves all existing
enemies and hazards, including an undefeated Drencher and its water. Following
the next difficulty adjustment, ordinary pursuers and chargers keep spawning at
their existing cadence and scaling throughout the boss fight. The Snuffer takes
HUD priority if both bosses remain alive.
Victory, death and voluntary run end still clear all combat and hazards.

## Projectile and damage learning

`enemy_droplet.gd` is a standalone `Node2D` reusable by future shooting enemies.
A shooter supplies the target, velocity, damage and tint. Each projectile draws
once and moves its cached canvas geometry, expires after eight seconds or leaving
the arena, and joins both `hazards` and `enemy_projectiles` for immediate cleanup.
The boss caps active projectiles at 180.

Collision checks the entire movement segment, preventing tunneling through the
lantern during long frames. The droplet core has a five-pixel collision radius;
the lantern uses an eight-pixel projectile hit radius. The glow is not damaging.
A visible 0.18-second launch grace prevents a new ring immediately hitting a
player overlapping its spawn point.

Droplets call `lantern.take_projectile_damage`, which allows one 12-damage hit
per 0.35 seconds and forwards accepted hits to the normal `take_damage` method.
This shared grace prevents several overlapping droplets dealing simultaneous
damage. Contact enemies retain their existing damage behavior. The grace clock
respects pause and resets on a new run. All projectiles disappear on defeat,
victory or voluntary run end.

## Validation

- All 25 Godot regression scripts passed. The two input-specific tests initially
  failed with a real controller connected; rerunning them with the locally
  documented SDL `SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0xffff/0xffff` setting
  isolated physical input and both passed. That setting was used only in test
  subprocesses; the interactive game keeps normal controller support.
- `check_droplets.gd` verifies arrival/warning timing, eight volleys, new aim versus
  fixed fired velocity, all 36 evenly spaced directions, low-health overlap, paused projectile
  movement/lifetime, swept hits, shared grace, arming, expiry, the projectile cap,
  victory cleanup and reset. Existing final-encounter tests still verify the
  stable health HUD, preservation of existing enemies/Drencher water, final-boss
  HUD priority, single banking, death ordering and records.
- `check_desperation.gd` checks the exact 400-HP threshold, 2.5x displacement,
  recovery timing, one-time announcement, pause, full warnings, stationary
  shooting, unchanged projectile speed, restart and killing-blow handling.
- Native rendering of the ring pattern was captured and inspected at
  `/tmp/lll-bullet-hell.png`. Droplets, boss silhouette and HUD instructions were
  readable. This is a controlled visual fixture; the three ring generations are
  advanced together for the capture, so it is not a timing/play-feel recording.
- Before the five-wide volleys and continued spawning adjustment, six upgraded
  turrets and 85 HP in the boss-only positioning probes produced:

| Movement policy | Result | Fight duration | Remaining HP |
| --- | --- | --- | --- |
| Stationary | Defeat | 16.1 seconds | 0 |
| Fixed orbit | Defeat | 46.5 seconds | 0 |
| React to projected droplet paths | Victory | 64.4 seconds | 73 |

The reactive probe evaluates candidate movement directions against incoming
projectile segments at normal player speed. This establishes that a route to
victory exists and simple circling no longer automatically wins; it does not
establish human difficulty. These focused probes start without ordinary enemies;
the interactive session also retains whatever is alive at final arrival.
The next user playtest should judge density, spacing
readability, recovery and damage tuning.

## Integration

Integrated with M14/M15 for release: all 31 Godot regression scripts and seven
Python release/configuration tests pass. Shared slow is wired at half boss
susceptibility and expires without slowing attack clocks. Projectile hits flow
through the ward. Save serialization retains turret types, all upgrades and clear
records. The schedule continues its Gathering/Pressure/Recovery cycle beyond
15:00 instead of shutting ordinary spawning down.

M15 must call `update_final_encounter()` alongside ordinary encounter scheduling.
Do not return early or disable regular spawns when it reports an active final
boss. Existing pursuer scaling, charger cadence and charger population limits
continue to apply. This supersedes the initial M16 scheduling notes.

M14's shared slow should affect `DRIFT_SPEED` movement through its normal boss
susceptibility policy. Snuffer still overrides `_process`, so base-enemy timer
updates need to be explicitly wired there. Do not implicitly slow projectiles
or pattern clocks. M15 ward remains downstream of `take_projectile_damage`, in
`take_damage`. Retain the new projectile grace reset and `enemy_projectiles` group
removal when merging main/lantern changes.

Changed for this revision: `snuffer.gd`, new `enemy_droplet.gd`, `lantern.gd`,
`main.gd` cleanup/reset, the two final-encounter test scripts, new
`tests/check_droplets.gd`, and these learning notes. No backend contract changes,
deployment, merge or push were needed for the projectile redesign.

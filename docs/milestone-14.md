# Milestone 14: slow support turret

The player-facing name is **Slow turret**. Internal `pulse` identifiers remain
unchanged for save compatibility; the effect still uses a visible pulse.

M14 adds a second turret job. Damage turrets shoot; pulse turrets briefly slow
nearby enemies so your existing damage coverage gets more time to fire. Buy either
type in **Place turrets**. B and the existing controller build shortcut still buy
a damage turret. **V** or **L1 / LB** begins a pulse purchase; its button displays
the keyboard shortcut or the active controller's shoulder-button icon. You can
also choose the pulse button with mouse or menu focus and confirm.

## Initial tuning

| Property | Pulse turret |
| --- | --- |
| Range | 150 pixels, compared with the damage turret's 220 |
| Interval | 3 seconds, beginning when an enemy is found in range |
| Effect | 45% slower movement for 1.5 seconds |
| Damage | None |
| Boss effect | Half susceptibility: 22.5% slower movement |
| Price | Current damage-turret price plus 20 energy |
| Permanent upgrades | Separate activation-rate, slow-strength, and slow-duration tracks |

## Upgrades by type

**Buy upgrades** shows every upgrade on one page, grouped under **Damage turrets**,
**Slow turrets**, and **Lantern**. Compact buttons and spacing keep all three groups,
their headings, and progress indicators on one page without scrolling. Smaller
windows scale the complete card to fit. Back
returns directly to preparation. G/F/H open this page and buy their corresponding
damage/fire-rate/health upgrade; U opens the page without purchasing.

Every upgrade has four progress segments and a current-level/maximum indicator
under its button, such as **2/4**. The count uses the actual level cap; this UI
change does not increase the number of purchasable levels.

All upgrades apply to every existing and future turret of that type. The Slow
turrets group shows the current combined effect above three purchase buttons:

| Track | Base | Per level | Level 4 | Prices |
| --- | --- | --- | --- | --- |
| Activation rate | Every 3.0s | Interval −0.3s | Every 1.8s | 60, 120, 240, 480 |
| Slow strength | 45% | +5 percentage points | 65% | 80, 160, 320, 640 |
| Slow duration | 1.5s | +0.2s | 2.3s | 50, 100, 200, 400 |

These are initial tuning values. Maximum activation and duration can sustain a
slow on enemies in range. Overlap refreshes without multiplying strength. Bosses
still resist half the slowdown, and charger warning/charge timing stays unchanged.
Damage-turret fire-rate upgrades do not alter Slow turrets.

The optional `slow_rate`, `slow_strength`, and `slow_duration` fields live in the
existing saved `upgrades` object. Missing fields default to zero. Slow upgrades
count toward run investment, persist through layout refunds, and are cleared by
Reset all progress. Public run diagrams still require the coordinated records
schema update described below to display these additional upgrade levels.

The first purchased damage turret costs 20; the first purchased pulse costs 40.
Both count toward the existing ten-energy increase per purchased turret. Each
turret retains its actual paid price for selling and refunding the layout.

Overlapping pulses refresh the duration without multiplying slow strength or
adding durations together. Multiple staggered turrets can sustain a slow, but
never reduce the movement factor below the purchased strength (0.35 at maximum).
A pulse waits for a
target rather than wasting its cooldown on an empty arena; idle scans retain the
existing 0.1-second polling interval.

The ring-shaped green body, smaller range circle, expanding pulse, and temporary
green enemy tint distinguish support from damage. Pulses reuse the existing
rate-limited shot sound. Balance values are an initial playtest, not settled tuning.

## Slow movement without slowing attack clocks

`enemy.gd` owns `apply_slow(factor, duration)`, `slow_remaining`, `slow_factor`, and
the exported `slow_susceptibility`. Slow never changes the configured base speed.
Ordinary movement splits a frame at effect expiry so real contact time still
determines damage. Changing modulation preserves cached enemy body drawings.

Chargers consume the slow timer in every state, but only their approach movement
slows. Warning, lock, charge speed, and recovery retain their existing timing and
advertised trajectory. The Drencher has 0.5 susceptibility and consumes slow time
during its arrival warning as well as pursuit.

Scene-tree pause freezes both pulses and status timers. Enemy removal clears
status with the enemy, and the existing run transition resets turret cooldown and
flash state.

## Reuse and persistence

`pulse_turret.gd` extends the damage turret script, sharing range, cooldown, flash,
purchase-cost, and type properties. It replaces firing and drawing rather than
introducing a general turret framework. A separate scene makes placement previews
and real instances use the same body and range.

Save version 1 gains an optional `turret_types` array alongside positions and
purchase costs. Older saves default every entry to `damage`; the free first turret
must remain a damage turret. The existing save validation rejects inconsistent
type arrays and preserves unreadable saves. Buying, moving, canceling, selling,
resetting, and reopening preserve mixed layouts and paid prices.

## Integration with M15 and M16

M15's ward and encounter schedule are separate worktree changes. M14 leaves the
lantern damage interface and ordinary spawn schedule unchanged.

For M16's boss, set `slow_susceptibility = 0.5`. Consume status time during every
state, using `_consume_slow(delta)` when a subclass does not call the base movement
processor. Apply its returned movement time to pursuit, keeping warning and attack
clocks at real speed. Do not consume the timer twice when calling the base processor.

Published run layouts still use the existing x/y-only contract. Local saves retain
turret types, but public layout diagrams do not yet distinguish pulse turrets.
Coordinate an optional turret type field across the Godot payload, backend
validation/storage, and record rendering when integrating M16's records work.
Do not send an extra field to the current strict backend before it supports it.

## Verification

All 27 Godot regression scripts passed, including the new
`tests/check_pulse_turret.gd`. Its checks cover purchases, previews, invalid
placement, free moves, upgrades, old and mixed saves, slow refresh/expiry, contact
time, charger warning/charge timing, Drencher resistance, pause, restart, and refunds.
Existing menu tests cover controller navigation and all preparation pages at
640×480. The release Web export also completed.

Release verification also passed all seven Python versioning tests. The pause
card refits and recenters when wrapped text or keyboard-hint visibility changes;
layout checks cover tall and small windows, with a native 720×1360 visual check.

In the local browser build, a real run earned energy, the pulse purchase charged
40, the new body and range rendered correctly, and reloading restored the mixed
layout with the remaining balance. No record was published during verification.

Native placement and combat captures were also inspected after enabling display
access for the isolated preview. The expanding pulse and overlapping coverage
render correctly. Full balance comparisons between all-damage and mixed layouts
remain a playtest task, particularly alongside the M15 ward and encounter pacing.

Start with [pulse_turret.gd](../pulse_turret.gd), [enemy.gd](../enemy.gd),
[build_controller.gd](../build_controller.gd), and
[the pulse regression checks](../tests/check_pulse_turret.gd).

# M14–M16 roadmap: deeper defenses and a run you can win

Recorded September 6, 2026, after the M13 sound and settings milestone.

Status: approved direction for planning; implementation is still pending. The
three milestones can be built together as one coordinated update. Their numbers
group the features and completion criteria; they do not require separate releases.

## Direction

Give the player more reasons to experiment with turret layouts, make holding a
defended position a useful playstyle, and finish the planned fifteen-minute run
with a boss and victory. Preserve the small core: fixed turrets, a mobile lantern,
automatic shooting, brightness as a risk/reward choice, and purchases during
preparation.

The starting point already includes permanent damage/fire-rate/health upgrades,
chargers, the five-minute Drencher encounter, online records, controller support,
preparation menus, sound effects, and settings. See the [design concept](concept.html)
and [M13 notes](milestone-13.md).

| Milestone | Main addition | Player benefit |
| --- | --- | --- |
| M14 | One pulse support turret | Choose between more damage and keeping enemies in existing coverage |
| M15 | A stationary ward and deliberate encounter pacing | Alternate between holding a defended pocket and dodging |
| M16 | A final boss at 15:00 and victory flow | Give preparation and progression a complete destination |

## M14: give turrets different jobs

### Proposed first version

Keep the current damage turret and add one **pulse turret**. Every few seconds,
it briefly slows enemies within a small radius. The player still guides enemies
through fixed defenses; the support turret helps nearby damage turrets get more
shots into those enemies.

- Offer the pulse turret during preparation with a clear description and price.
- Show its range during placement and make each pulse visible during combat.
- Overlapping slows refresh the effect rather than multiplying its strength.
- Give bosses reduced susceptibility, subject to playtesting.
- Keep buying, moving, selling, resetting, and saved layouts coherent across types.
- Keep the existing turret as the straightforward damage option.

The key question is: **buy another damage turret, or increase the value of the
damage coverage already in place?**

### Godot learning focus

Reusable turret scenes and timed status effects. Extract shared behavior as the
second turret needs it; avoid designing a large turret framework in advance.

### Completion criteria

- [ ] An all-damage layout and a mixed layout are both useful in playtests.
- [ ] The pulse turret's contribution is visible and understandable.
- [ ] Multiple pulse turrets cannot compound slow into an unintended permanent lock.
- [ ] Preparation actions and saving preserve each turret's type and paid price.
- [ ] Existing saves load their old turrets as the existing damage type.
- [ ] Pause, enemy death, and run reset handle slow timers and effects correctly.

### Tuning and choices still open

Price, radius, pulse interval, slow strength/duration, boss resistance, and how
existing permanent upgrades affect the support turret. Decide explicitly whether
slow affects charger approach, charge movement, or both; preserve readable attack
warnings and fair dodges.

### Alternative preserved from the brainstorm

A **piercing turret** would reward lining enemies up behind the lantern and lean
more toward active movement. The pulse turret is the preferred first addition
because it has a more distinct support job. Piercing remains a future option,
not an additional requirement for this update.

## M15: make holding ground a playstyle

### Proposed first version

After standing still briefly, the lantern forms a **small protective ward**.
It absorbs a limited amount of damage while settled. Moving removes the ward;
while settled, it can recharge after a period without taking damage.

The key question is: **stay inside this defended pocket, or leave before the
incoming attack overwhelms it?**

- Make forming, active, and broken ward states visually distinct.
- Let the ward protect against occasional enemies slipping through coverage.
- Keep dodging valuable when concentrated pressure exceeds the protection.
- Let Drencher puddles naturally encourage relocation.
- Keep the first version to one defensive mechanic rather than an upgrade tree.

Define formation delay, capacity, recharge delay/rate, movement threshold, and
damage handling during implementation. Controller drift must not make the ward
unreliable. Prevent tiny movement or repeated activation from granting unintended
free protection. Exact numerical values are playtest decisions.

### Encounter pacing

Shape the existing enemy schedule into recognizable pressure and recovery periods.
Use the current pursuers, chargers, and Drencher before expanding the enemy roster.
The goal is to replace repetitive escalation with purposeful combinations and
breathing room while retaining brightness's risk/reward role.

Coordinate the schedule with M16: the Drencher arrives at 5:00, and the final boss
arrives at 15:00. Do not assume a new ten-minute boss is needed. Decide how an
undefeated Drencher interacts with the final encounter and how ordinary spawning
behaves during that encounter.

### Godot learning focus

A small player-state system and configurable encounter timing.

### Completion criteria

- [ ] Settling feels useful without making movement unnecessary.
- [ ] A charger or hazardous ground gives a clear reason to leave a defended spot.
- [ ] Ward state and available protection are easy to read.
- [ ] Movement, incoming damage, recharge, pause, defeat, and restart interact correctly.
- [ ] Runs have noticeable changes in pressure and opportunities to recover position.
- [ ] Active and low-input playstyles both receive actual playtesting.

### Alternative preserved from the brainstorm

If holding ground proves less enjoyable than active movement, an **active lantern
ability** could replace the ward: a short dash or a repelling flash. This is an
alternative direction, not a requirement to add another input alongside the ward.
The preferred combined plan is pulse turret plus stationary ward.

## M16: survive until dawn

### Proposed first version

Add the planned final encounter at **15:00**. A working boss concept is
**The Snuffer**, a creature drawn to the last remaining light. The name and visual
design remain provisional.

Use at most two attacks and one behavior change at low health:

1. A clearly warned sweeping attack makes the lantern reposition.
2. A committed pursuit lets the player lure the boss through turret coverage.

A short recovery window creates an opportunity to settle and deal damage. The
low-health change should intensify these familiar patterns without requiring a
large new move set. Let this encounter focus on positioning; the Drencher already
fills the persistent ground-hazard role.

Defeating the boss ends the run in victory, with a small dawn transition, victory
results, and a recorded clear time. Return to preparation through the established
results flow.

### Victory and records

- Distinguish victory from defeat in run state and results.
- Decide how earnings are banked on victory and ensure they are awarded once.
- Record clear time with an explicit definition, preferably total elapsed run time
  through the killing blow; boss fight duration can be a separate field if useful.
- Decide how completed runs appear in the survival-based leaderboard before
  changing ranking or publication behavior. Longer survival and faster clears
  measure different accomplishments.
- Keep older records and locally saved progress readable.
- Define the outcome if the lantern and boss die during the same update.
- Make boss death and the ending sequence safe against repeated triggers.

### Godot learning focus

Boss phase coordination, encounter transitions, and an explicit victory state.

### Completion criteria

- [ ] The final encounter starts once at the intended time.
- [ ] Its warnings and recovery windows support fair positioning decisions.
- [ ] Pulse turret and ward interactions remain useful without trivializing the boss.
- [ ] Victory clears combat and hazards and awards the intended result exactly once.
- [ ] Defeat, victory, pause, and the next run all work correctly.
- [ ] Results and online records represent clears consistently.
- [ ] A fresh profile can progress to a satisfying win without an excessively long,
      repetitive stretch before the final encounter.

## Implementing all three together

Build these as one feature set, with small working checkpoints. The proposed order
below reduces rework; all three can ship together.

1. **Settle shared rules.** Decide support-turret upgrade behavior, slow interactions,
   ward semantics, final-encounter spawning, and victory/leaderboard representation.
2. **Build the pulse turret end to end.** Include preparation, runtime behavior,
   old-save compatibility, and visible feedback before expanding the combat loop.
3. **Build the ward end to end.** Integrate it into the existing damage path and
   HUD, then try it with pursuers, chargers, and the Drencher.
4. **Structure encounter timing.** Preserve the five-minute encounter and provide
   a clear place for the fifteen-minute final boss. Keep the schedule easy to tune.
5. **Build the final boss and victory flow.** Include result persistence and records
   handling so the run is complete from preparation through its ending.
6. **Tune the combined game.** Adjust turret costs, slow, ward strength, enemy pacing,
   and boss health using full runs and focused encounter playtests.

### Shared integration checklist

- [ ] Existing save data retains layouts, energy, and permanent upgrades.
- [ ] Turret type and any new persistent fields have explicit defaults.
- [ ] Damage handling consistently accounts for the ward and existing hazards.
- [ ] Temporary effects respect pause and never leak into a fresh run.
- [ ] Menus and new feedback remain usable with mouse, keyboard, and controller.
- [ ] New effects remain readable in a crowded arena and fit the existing sound mix.
- [ ] Support effects and boss visuals preserve swarm performance.
- [ ] Relevant regression checks pass; new checks cover meaningful state transitions
      and interactions, with visual and feel judgments verified through playtesting.
- [ ] Desktop and browser builds receive an end-to-end check of the combined update.

### Playtest comparisons

Compare all-damage versus mixed turret layouts, active dodging versus settling,
and early progression versus upgraded runs. Try each against ordinary pressure,
chargers, the Drencher, and the final encounter. Use focused boss setups for rapid
iteration, then verify the complete progression from a fresh profile.

Watch especially for slow plus ward making one position permanently safe, the ward
becoming irrelevant under late-game damage, support turrets becoming mandatory,
and too much empty or repetitive time on the way to 15:00.

## Scope guardrails

The intended update adds one turret type, one stationary defense mechanic,
encounter pacing, and one final boss with a victory flow. Piercing shots, a dash,
and a repelling flash are preserved ideas for alternatives or later work. A large
skill tree, more arenas, more intermediate bosses, and additional turret types
are outside this first combined implementation.

All new numbers and provisional boss details need playtesting. The goal is a
simple game with more meaningful choices and a satisfying ending.

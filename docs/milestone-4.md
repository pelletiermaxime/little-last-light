# Milestone 4: survive, prepare, improve, repeat

This lesson describes **M4 as it shipped**, rather than the current game. [Browse the complete milestone source](https://github.com/pelletiermaxime/little-last-light/tree/milestone-4). The short excerpts below come from that tag; full files remain available through the links.

## What changed

M4 moves construction **between runs** and keeps your energy and turret layout after defeat. Start with the free turret, survive to earn energy, then improve your defense and try again.

Preparation allows purchases and free repositioning. A run starts with full health, Low brightness, a centered lantern, and a fresh timer. No energy is earned in preparation, and no construction is allowed during combat.

## The idea to learn: explicit game phases

Main owns two named phases: `PREPARATION` and `RUNNING`.

```text
Preparation → Start run → Running → Defeat → Preparation
```

The scene remains alive in both phases. Main only spawns during a run. Lantern's `running` flag controls movement, income, damage, and elapsed time. Real turrets stop processing during preparation; the building interface remains active.

Starting is guarded so combat cannot begin with an unfinished placement:

[main.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/main.gd#L47)

```gdscript
func start_run() -> void:
	if phase != Phase.PREPARATION or $BuildController.placing:
		return
	_clear_enemies()
	lantern.health = lantern.max_health
	lantern.energy = 0.0
	lantern.elapsed = 0.0
```

The rest of the method resets brightness, spawn progress, and the lantern's position, then enables combat. It retains purchased turret nodes and banked energy. Keeping those objects alive replaces M3's whole-scene restart.

## Follow the energy

There are two balances: `lantern.energy` is earned in the current attempt; `main.banked_energy` is available to spend between attempts.

Suppose you have 10 banked energy and earn 35. Defeat transfers those earnings into the bank, giving 45, and clears the run balance. Buying the first extra turret costs 20, leaving 25 for the next preparation.

The death handler begins by leaving RUNNING:

[main.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/main.gd#L65)

```gdscript
func _on_lantern_died() -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.PREPARATION
	lantern.running = false
```

That guard is important: a second death notification cannot bank the same earnings twice. The handler also clears enemies, stops turrets, updates the result, and saves.

## Moving a turret without buying another

The controller remembers the selected turret, hides it, and shows a preview. The real node stays at its original position until confirmation. A valid click moves that node for free; Escape simply shows it again.

A new purchase creates a node instead. Prices increase with the number bought: 20, 30, 40, and so on. Both paths check arena boundaries and spacing. The sidebar is outside the playable arena, so there are no invisible HUD exclusion zones inside it.

## Saving and difficulty

The JSON save stores energy, best completed time, and normalized turret coordinates. Normalized coordinates describe a fraction of arena width and height, so a saved layout can adapt to another window size. Saves write to a temporary file before replacing the previous file. Empty files mean a fresh profile; malformed nonempty files are preserved and produce a warning.

M4 increases spawn frequency, the health of new enemies, and eventually enemy speed as elapsed time rises. This is historical tuning: M6 later removes the speed increase to make escape reliable. None of these settings are a promise of a particular survival time.

## Try it and understand the checks

Earn energy, die, move the starter turret, buy another, and restart. Notice which values reset and which survive. Cancel a move and confirm that its original position remains intact.

Tests cover phase restrictions, banking once, purchasing, free relocation, save/reopen, damaged-save handling, increasing pressure, and contact damage. Contact includes the fraction of a frame spent touching the lantern, rather than charging for time spent approaching.

## Full source when you need it

The key files are [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/main.gd), [build_controller.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/build_controller.gd), and [tests/check_runs.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/tests/check_runs.gd). Difficulty and contact scenarios are in [tests/check_difficulty.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/tests/check_difficulty.gd) and [tests/check_health.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-4/tests/check_health.gd).

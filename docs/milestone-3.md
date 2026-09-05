# Milestone 3: building turrets during a run

This lesson describes **M3 as it shipped**, rather than the current game. [Browse the complete milestone source](https://github.com/pelletiermaxime/little-last-light/tree/milestone-3). The short excerpts below come from that tag; full files remain available through the links.

## What changed

M3 lets you spend energy on fixed turrets **during combat**. At 20 energy, press B or click Build turret. The game pauses and a ghost turret follows the mouse. Click a valid green position to buy, or press Escape to cancel without spending.

Purchases last only for that attempt. Death and restart reload the starting scene. M4 later changes this to persistent purchases between runs.

## The idea to learn: a scene is a reusable template

A `PackedScene` is a saved arrangement of nodes. Calling `instantiate()` creates a new copy with its own position and firing cooldown. M3 extracts the turret into `turret.tscn` so the starting turret and purchased ones use the same template.

Real turrets are children of Main, alongside Lantern. They stay where you place them because they are not children of the moving lantern. The preview belongs to BuildController, which controls its visibility and lifetime.

## Follow one purchase

Entering placement checks affordability and game state before pausing:

[build_controller.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/build_controller.gd#L92)

```gdscript
func begin_placement() -> void:
	if placing or get_tree().paused or lantern.health <= 0.0 or lantern.energy < TURRET_COST:
		return
```

The button may be disabled, but the method still needs its own guard because keyboard input calls it too. Entering the mode does not spend anything.

BuildController uses `PROCESS_MODE_ALWAYS` so it can update the preview and receive cancellation while the tree is paused. The preview uses disabled processing and is removed from the real-turret group: it draws like a turret but cannot shoot or block its own placement.

A click passes through position and affordability checks before purchase:

[build_controller.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/build_controller.gd#L116)

```gdscript
func try_place(point: Vector2) -> bool:
	# Validate everything before spending: invalid clicks never cost energy.
	if not placing or lantern.health <= 0.0 or lantern.energy < TURRET_COST or not can_place_at(point):
		return false
	var turret := TURRET_SCENE.instantiate() as Node2D
	get_parent().add_child(turret)
	turret.global_position = point
	lantern.energy -= TURRET_COST
	lantern._update_status()
	cancel_placement()
	return true
```

For example, buying with 27.5 energy leaves 7.5. An invalid position leaves the balance unchanged. Ending placement immediately prevents a second click from buying a duplicate.

M3 reserves room for the HUD and prevents turret bodies from overlapping. Range circles may overlap; covering the same approach from multiple turrets is intentional.

## Try it and understand the checks

In a separate M3 checkout, change `TURRET_COST` from 20 to 10. Does a cheaper second turret make High brightness more useful? Then try increasing turret spacing while leaving attack range unchanged.

The build test checks input, paused time and earnings, invalid positions, cancellation, cost, duplicate clicks, fixed turret positions, shooting, and restart. These checks establish the rules; playtesting tells us whether the economy is fun.

## Full source when you need it

Read [build_controller.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/build_controller.gd) for placement, [turret.tscn](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/turret.tscn) for the reusable scene, and [tests/check_build.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-3/tests/check_build.gd) for the regression scenarios.

To inspect historical code without changing the current project, use `git show milestone-3:build_controller.gd`. If you want to edit or run that version separately, use a detached worktree and a disposable save profile.

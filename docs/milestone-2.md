# Milestone 2: health, defeat, restart

Open the project and press **F5**. You now start with **100 health**. Each enemy touching the lantern deals **15 damage per second**. The red ring means you are taking damage. Move away from your turret and let an enemy reach you to try it.

At zero health, the game freezes and shows your survival time. Click **Try again**, or press **R**, to start fresh. WASD/arrows and Space still work during a run.

## Follow one hit through the code

1. [enemy.gd](../enemies/enemy.gd) checks its distance to the lantern. Within 20 pixels, it calls `target.take_damage(contact_damage_per_second * delta)`. Multiplying by seconds makes damage independent of frame rate. Multiple enemies each contribute damage.
2. [lantern.gd](../lantern.gd) owns its health. `take_damage()` subtracts damage, updates the HUD, and flashes the red ring. Health never drops below zero.
3. When health reaches zero, the lantern emits its `died` signal. A signal is an announcement: the lantern says what happened without needing to know how a defeat menu works.
4. [main.gd](../main.gd) connects that signal to `_on_lantern_died()`. It opens the menu and pauses the scene tree. Movement, enemies, turret fire, energy, and the survival timer all stop.

## Why the restart button still works

The defeat menu lives in a CanvasLayer with `PROCESS_MODE_ALWAYS`. That menu keeps accepting input while the gameplay is paused. Its button calls `_restart_run()`, which unpauses and reloads the current scene. Fresh nodes mean fresh health, enemies, energy, and cooldowns.

The menu is created in code in `_create_defeat_screen()`. These are ordinary Godot UI nodes; when running from the editor you can inspect them in the Remote scene tree.

## Try one small change

Select **Lantern** and change **Max Health** in the Inspector from 100 to 50. Run again and let one enemy reach you. You should survive roughly half as long under continuous contact. Restore it afterward if you prefer the original pace.

## Verification

Godot imports the project successfully. The behavioral check covers contact distance, timed damage, health clamping, a single death signal, gameplay freezing, menu processing during pause, and a restart with fresh state.

Run it with `godot --headless --path . --script res://tests/check_health.gd` from the project folder. The test prints PASS on success.

Next milestone: earn currency and place another fixed turret with a range preview.

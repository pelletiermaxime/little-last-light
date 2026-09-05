# Milestone 5: clarity and feel

This lesson describes **M5 as it shipped**, rather than the current game. [Browse the complete milestone source](https://github.com/pelletiermaxime/little-last-light/tree/milestone-5). The short excerpts below come from that tag; full files remain available through the links.

## What changed

M5 makes existing decisions easier to read: health has a bar and danger feedback, brightness has three selectable buttons, and preparation shows the last run's earnings, survival time, and purchase affordability.

The core economy and combat rules stay the same. A shared scrollable sidebar keeps the run information and preparation controls together.

## The idea to learn: the interface reads state

GameHUD is responsible for presentation. Lantern still owns health, brightness, and current earnings; Main owns banked energy and run results; BuildController owns placement and prices.

This avoids keeping a second copy of health or currency inside labels. When something changes, the HUD reads the authoritative value and displays it.

Ordinary text refreshes ten times per second. Events such as damage, brightness changes, or defeat refresh immediately through Lantern's `_update_status()` bridge. Combat and movement keep their normal update rates.

## Give every control the same entry point

Keyboard/controller brightness cycling and the three buttons call one method:

[lantern.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-5/lantern.gd#L80)

```gdscript
func set_brightness(level: int) -> void:
	if not running or level < 0 or level >= BRIGHTNESS_NAMES.size():
		return
	brightness = level
	_update_status()
	queue_redraw()
```

The guard keeps preparation and invalid indices from changing brightness. Putting the change in one place means every input method gets the same validation, HUD refresh, and visual update.

The buttons read the existing energy rates—1, 3, and 6 per second. The lantern's glow and ray count reinforce the selected level in the arena. Low brightness reduces attraction; it does not stop pressure increasing with run duration.

## Capture a result before resetting it

Death adds current earnings to the bank and clears them. A recap that reads the cleared value would say you earned zero.

M5 stores the result first:

[main.gd, excerpt](https://github.com/pelletiermaxime/little-last-light/blob/milestone-5/main.gd#L72)

```gdscript
	last_run = {"duration": lantern.elapsed, "energy": lantern.energy, "new_best": lantern.elapsed > best_time}
```

A Dictionary groups the values needed to describe that completed attempt. The best-time update and banking happen afterward, so `new_best` compares against the previous record.

For example, 5 energy in reserve plus 28.4 earned becomes 33.4 available, while the recap still says 28 earned. Buying a 20-energy turret leaves 13.4; the next turret costs 30, so the UI rounds the shortage up to 17.

The recap is session-only in M5. The save still stores progress, but reopening does not invent a last-run recap.

## Feedback needs to outlive gameplay

A red hit flash originally stayed visible after a fatal hit because run processing stopped. M5 lets that visual feedback decay during preparation while time and income remain stopped. This is a small example of separating animation from game rules.

## Try it and understand the checks

Choose High brightness, take some damage, then compare the live HUD with the preparation recap. Buy a turret and watch the available balance and shortage update.

The HUD checks cover brightness input, phase restrictions, time formatting, danger feedback, recap/banking order, affordability, save warnings, flash decay, and fresh values on restart. Visual checks covered preparation, low health, a new record, and placement at 1152 × 648. They do not establish perfect layout at every possible resolution or a measured performance improvement.

## Full source when you need it

Read [game_hud.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-5/game_hud.gd) for presentation, [lantern.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-5/lantern.gd) for brightness and hit feedback, [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-5/main.gd) for result capture, and [tests/check_hud.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-5/tests/check_hud.gd) for the scenarios.

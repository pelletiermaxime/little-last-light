# Milestone 9: upgrades, selling, and run results

M9 makes earned energy a choice between wider turret coverage, stronger shots, faster firing, and more lantern health. Five minutes remains a progression target to playtest, not a guaranteed survival time.

## What changed

Preparation offers three permanent upgrade tracks. Damage and fire rate apply to every turret, including the free starter and future purchases. Health affects the lantern. Buttons show the current stat, next stat, and price; scroll the sidebar on shorter windows.

| Upgrade | Effect per level | Prices in energy | Maximum |
| --- | --- | --- | --- |
| Damage | +1 damage | 60, 120, 240, 480 | 5 damage |
| Fire rate | +25% of the original rate | 50, 100, 200, 400 | 1.333 shots/second |
| Health | +15 HP, starting at 25 | 40, 80, 160, 320 | 85 HP |

All tracks stop at four levels. Fully upgrading both turret stats costs 1,650 energy; health adds 600. Keyboard shortcuts are G, F, and H; controller equivalents are L1, R1, and R3.

Select a purchased turret as if moving it, then use **Sell selected**, X, or controller L3 to refund its original price. The free starter cannot be sold. Reset Layout refunds purchased turrets and preserves upgrades.

## The idea to learn: derive stats from levels

Main owns the three upgrade levels. It calculates stats from those levels instead of repeatedly multiplying existing values:

```gdscript
func turret_shots_per_second() -> float:
	return (1.0 + 0.25 * fire_rate_level) / 1.5

func lantern_max_health() -> float:
	return 25.0 + 15.0 * health_level
```

Fire rate increases additively from the original 0.667 shots/second. Its first two upgrades give 0.833 and 1.0 shots/second. Turret configuration converts that rate into a cooldown using `1.0 / rate`.

Configuration runs after loading, when buying upgrades, and when creating turrets. Buying a turret before or after an upgrade therefore produces identical stats. Every run refills the lantern to its upgraded maximum; the HUD danger threshold is 25% of that maximum.

Purchases check phase, placement state, funds, and level caps before spending. Combat, pause, and results cannot enable purchases. Repeated keyboard events are ignored so holding a shortcut cannot accidentally buy several levels.

## Why each turret stores its price

Purchase order previously implied prices: 20, 30, 40… Individual selling breaks that assumption.

Buy turrets for 20 and 30, then sell the 20-energy turret. The next turret costs 30 because price depends on how many you currently own. The remaining purchased turrets now represent 30 + 30 energy, so Reset Layout must refund 60.

`purchase_cost` records the actual payment. Selling removes the turret from its group before queued deletion, preventing another click or save from counting it twice.

The save gains optional `upgrades` and `turret_costs` fields. Older saves default missing levels to zero and reconstruct original purchase prices from saved turret order. Validation checks integer level bounds and cost metadata. Moving a turret preserves its original saved position until placement is confirmed.

## Results before preparation

The phase flow is `PREPARATION → RUNNING → RESULTS → PREPARATION`. Death and voluntary End Run bank earnings once, then show survival time, earned energy, personal best, and the leaderboard controls. Continue unlocks preparation.

The existing leaderboard panel moves into the results card and back instead of being recreated. Its request and retry state survive the transition. Development runs keep records local; exported releases retain opt-in publication.

## Playtest and verification

Early playtests made ten minutes too comfortable. Prices now double per level, upgrade caps are lower, and starting health dropped from 100 to 25 after a 5:45 run with two unupgraded turrets. Three charger hits kill a fresh lantern. These changes make mistakes more costly; encounters still need tuning for players who avoid damage.

All 14 headless suites passed, including actual shot damage/cooldown, refunds, save migration, health progression, phase restrictions, single banking, and leaderboard retries. Preparation and results were also checked visually.

## Read this milestone's code later

These links stay pinned to M9 as later milestones change the game:

- [main.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-9/main.gd): purchases, derived stats, phases, and persistence.
- [build_controller.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-9/build_controller.gd): upgrade buttons, selling, and input.
- [results_screen.gd](https://github.com/pelletiermaxime/little-last-light/blob/milestone-9/results_screen.gd): recap and leaderboard transition.
- [Tests](https://github.com/pelletiermaxime/little-last-light/tree/milestone-9/tests): executable examples of the expected behavior.

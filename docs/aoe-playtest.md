# Ember Pot playtest

Run from the project directory:

```sh
godot --path . --script res://tests/launch_aoe_playtest.gd
```

This opens a separate persistent `user://ember-playtest-v1.json` profile with an
Ember Pot and Watchlight placed alongside the basic starter. It provides at least
1500 energy on each launch. Your normal save and the old three-prototype playtest
save are untouched. Rearrange, sell, or buy turrets in **Place turrets**, then
choose **Done → Start run**. Move with WASD/arrows and lead enemies through the
defenses. Normal encounters and lantern damage still apply.

Ember Pot is also available in the regular placement toolbar with its stats below
the purchase button. It follows the shared 60, 85, 110… energy price ladder and
saves, moves, and refunds normally. Its fixed 1 damage is unaffected by upgrades
and proximity; balance and progression integration remain provisional. Records
with Ember layouts stay local until tuning and leaderboard support are ready.

Every 3 seconds, Ember Pot selects the nearest enemy within 220 pixels and lobs
a coal at that enemy's current position. The landing point stays fixed. After
0.45 seconds, all living enemies within 65 pixels of that point take 1 damage
once. Flight time is included in the cadence. A broken circle marks the splash
footprint, an airborne coal shows travel, and a brief burst marks impact. The
turret waits if no enemy is in acquisition range.

Ember Pot was selected after comparing the three AOE prototypes; Cinder Bell and
Lantern Flare have been removed. The Flare **pickup** from main is unaffected.

Compare Ember against a sparse stream, then a group led through its coverage.
Try adding a Slow turret. Watchlight retains its long-range, furthest-target
behavior and its normal upgrade/proximity bonuses. These starting values are
not a claim of equal balance between splash and sniper damage.

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
the purchase button. In **Place turrets**, press **L3 / left-stick click** to
select Ember Pot directly; its purchase button shows the matching controller icon.
It follows the shared 60, 85, 110… energy price ladder and
saves, moves, and refunds normally. Damage and Fire Rate upgrades now apply to
Ember Pot too: it has the basic turret's damage and twice its firing interval.
Lantern proximity boosts damage and recharge speed, including the Proximity
Power upgrade. Each coal keeps its damage at launch; moving during flight does
not change that coal's damage or its 0.45-second flight time. Records
with Ember layouts stay local until tuning and leaderboard support are ready.

At base stats, every 3 seconds Ember Pot selects the nearest enemy within 220 pixels and lobs
a coal at that enemy's current position. The landing point stays fixed. After
0.45 seconds, all living enemies within 65 pixels of that point take 1 damage
once. Flight time is included in the cadence. A broken circle marks the splash
footprint, an airborne coal shows travel, and a brief burst marks impact. The
turret waits if no enemy is in acquisition range.

Ember Pot was selected after comparing the three AOE prototypes; Cinder Bell and
Lantern Flare have been removed. The Flare **pickup** from main is unaffected.

Compare Ember against a sparse stream, then a group led through its coverage.
Try adding a Slow turret. Watchlight retains its long-range, furthest-target
behavior. Both Ember and Watchlight benefit from damage/rate upgrades and proximity. These starting values are
not a claim of equal balance between splash and sniper damage.

# Reset turret layout and refund energy

During preparation, the Reset layout button shows how much energy it will refund. R or controller Triangle/Y triggers the same action. It removes purchased turrets, restores one free turret to the original starting position, and saves the refunded balance and layout. Best survival and existing earned energy are preserved. A paused run is still a run, so reset is unavailable there.

The refund follows the existing price ladder. For `n` purchased turrets it is `20*n + 10*n*(n-1)/2`: three purchases refund 20 + 30 + 40 = 90, rather than three times the current next price. One turret is excluded because the starter was free. This relies on the game's current deterministic prices; if future versions introduce discounts, upgrades, or different prices, they should persist the actual refundable investment rather than infer it from count.

An unfinished placement is only a preview and has not cost anything. Reset cancels it, restoring a hidden turret if it was being moved. Removed turrets leave the `turrets` group immediately before `queue_free()`, so the refund count, subsequent clicks, and saving already see just one turret during that same frame. This prevents a second click from refunding the same purchases twice.

The survivor is reset to arena center plus 80 pixels horizontally, clamped inside the placement margins. It is an ordinary identical turret; there is no separate starter upgrade state. Existing saves remain version 1. A save error continues to use the visible save-warning mechanism.

`tests/check_reset_layout.gd` buys turrets through the real placement code, verifies the exact refund including a fractional starting bank, cancels unfinished moves and purchases, checks repeat-click safety, exercises controller reset, checks combat and pause restrictions, and reloads the resulting save. It uses an isolated temporary profile. All nine Godot regression suites passed, and the new button was checked in a native render.

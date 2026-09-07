# The Rainkeeper

The selected ten-minute boss from issue #2. It arrives once at **10:00** in normal
runs, alongside ordinary enemy pressure and any surviving five-minute Drencher.
The Snuffer still arrives at 15:00 and must be defeated to win.

The Rainkeeper has 900 HP and three seconds of protected arrival. Each burst marks
three consecutive positions, with a **0.85-second warning** before each strike.
Marks lock immediately and never track the lantern. Each **100 px-radius pool**
lasts **three seconds**, dealing 8 damage per second; overlapping rain pools do not
multiply damage. Strikes are separated by 0.35 seconds, followed by a **1.5-second
recovery** in which the boss approaches the lantern. Pulse slows affect that movement,
not its attack clocks. There is no passive body-contact damage.

Defeating it clears its water and continues the run. It awards no additional boss
bonus. The HUD prioritizes Snuffer, then Rainkeeper, then Drencher when multiple
bosses survive. The discarded Tidekeeper and Wickwatcher experiments remain in Git
history, rather than in the game.

The three-strike version was selected after hands-on comparison of all three boss
concepts. Automated checks cover scheduling, fixed warnings, pool damage/expiry,
overlap, slow movement, pause, targeting, restart and coexistence with both bosses.

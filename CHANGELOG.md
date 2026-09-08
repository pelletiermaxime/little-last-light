# Changelog

Player-facing changes are recorded here and used by the release script. New changes
go under **Unreleased**. Version numbers are assigned automatically when publishing;
see the release workflow in [README.md](README.md#automatic-versions-and-changelog).

This history starts with v0.0.14. Earlier releases retain their original notes on GitHub.

## [Unreleased]

## [0.0.23] - 2026-09-08

### Added

- Added an Assistance submenu with half-price upgrades, a shorter night (bosses at 2:30, 5:00, and 7:30), and half-speed enemies and projectiles. Assisted progress cannot publish leaderboard records, even after assists are turned off; reset progress to return to eligible play.
- Added damage-taken options (75%, 50%, or invincible) for assisted play.
- Added visual accessibility options for stronger danger cues, reduced decorative effects and flashes, and hiding turret range circles while retaining placement guides. Visual preferences keep leaderboard eligibility.

### Changed

- Removed the Done button from Settings; use Escape or controller Back to return.

## [0.0.22] - 2026-09-08

### Added

- Added Ember Pot, an area-damage turret whose lobbed coals explode to damage nearby enemies. It benefits from Damage and Fire Rate upgrades and lantern proximity bonuses. Build it from the placement toolbar or with L3 / left-stick click. Runs using Ember Pot are saved locally and cannot be published to the leaderboard.

### Fixed

- Upgrade comparisons use "to" instead of an arrow symbol that can be missing in web fonts.

## [0.0.21] - 2026-09-08

### Added

- The placement screen now shows each turret's base damage, range and firing interval, plus targeting or slowing effects, below its purchase button. Whole-number stats omit unnecessary decimals.
- Added the Watchlight sniper: long-range shots at the furthest enemy, a directional shuttered housing, and heavy damage with a slow recharge. Build it with right-stick click on a controller or the placement toolbar; damage upgrades and lantern proximity boosts apply.

### Changed

- Basic, Slow, and Watchlight turrets now share the same purchase price: 60 energy initially, increasing by 25 for each purchased turret in the layout.
- Upgrade purchases use mouse clicks or menu navigation and confirmation. Removed the G, F, and H shortcuts and their button hints.
- Watchlights now acquire their next target immediately after shooting and turn toward it during reload, updating their aim as enemies move or die.
- Turret purchases use the mouse toolbar or controller shortcuts. Removed the B, V, and N keyboard purchase shortcuts; right-stick click now selects the Watchlight on controllers.

## [0.0.20] - 2026-09-07

- No player-facing changes recorded for this release.

## [0.0.19] - 2026-09-07

### Added

- Early-run Kindling and Flare pickups reward movement with eight seconds of doubled passive energy or a nearby burst of damage. Walk into their marked circles before the countdown expires.
- Pickup markers are compact, with a detailed explanation only on the first offer of each type per run. Flare bursts reach 180 pixels and deal 8 damage.
- Sentinel pickups create a powerful turret for 12 seconds at the collection spot. Stillness pickups freeze enemy movement and attacks for 3 seconds while you and your turrets stay active.

## [0.0.18] - 2026-09-07

- Republished the same game content as v0.0.17, including the new ten-minute Rainkeeper boss. No additional gameplay changes.

## [0.0.17] - 2026-09-07

### Added

- The Rainkeeper arrives at ten minutes, marking three consecutive rain strikes that leave lingering pools and force you to plan your return to the defense.

## [0.0.16] - 2026-09-07

### Changed

- Release notes now use this maintained changelog instead of commit titles.
- Energy Gain now also boosts the five-minute boss reward: 300 energy without upgrades, increasing by 75 per level to 675 at maximum level.

## [0.0.15] - 2026-09-07

### Added

- Standing near damage turrets boosts their damage and firing speed by 50%. The new Proximity Power upgrade raises both bonuses to 100% at maximum level.
- Added an Energy Gain upgrade, granting 25% more passive energy per level.
- Defeating the five-minute boss awards a one-time 300-energy bonus, shown in the HUD and run results.

### Changed

- Replaced the ward mechanic with the proximity boost, including visible links to boosted turrets.
- Rebalanced progression with more expensive towers and upgrades, and five levels for every upgrade.
- Damage upgrades add 1.5 damage per level, reaching 8.5 damage at maximum level before proximity bonuses.
- Increased passive energy income by 20% over the previous balance iteration.
- Increased minimum turret spacing to discourage tightly packed clusters.
- Chargers appear more frequently, and enemy pressure continues to increase during longer runs.
- Strengthened slow turrets with 175 range and a slow lasting 1.3 seconds, increasing to 2.05 seconds with upgrades. Maximum slow strength is 70%.
- Progress now resets when the game version changes during development. Existing saves are not migrated.

## [0.0.14] - 2026-09-07

### Added

- Added the bullet-hell finale, desperation phase, and victory records.

### Fixed

- Leaderboard run layouts now distinguish damage turrets from slow turrets, with separate colors, shapes, and a legend.

# Changelog

Player-facing changes are recorded here and used by the release script. New changes
go under **Unreleased**. Version numbers are assigned automatically when publishing;
see the release workflow in [README.md](README.md#automatic-versions-and-changelog).

This history starts with v0.0.14. Earlier releases retain their original notes on GitHub.

## [Unreleased]

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

### Fixed

- Leaderboard run layouts now distinguish damage turrets from slow turrets, with separate colors, shapes, and a legend.

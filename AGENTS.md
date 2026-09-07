@/home/maximep/.codex/RTK.md

## Changelog

- Update `CHANGELOG.md` in the same change as player-facing gameplay, balance, UI, bug fixes, or release behavior. Use concise player-facing bullets under `### Added`, `### Changed`, or `### Fixed` in `## [Unreleased]`; omit empty categories.
- Before adding new entries, check the latest published version/tag. If that release consumed the current Unreleased entries, move those entries unchanged into `## [X.Y.Z] - YYYY-MM-DD` using the actual release version and UTC publication date, then start fresh Unreleased entries. Do not guess the next version from `project.godot`: CI assigns patch versions automatically.
- Keep released entries as history. Do not rewrite older releases to describe newer behavior. Tests and internal refactors need no changelog bullet unless they change user-visible behavior.
- `scripts/prepare-release.py` uses the matching version section when present, otherwise Unreleased. Empty or unchanged Unreleased entries produce a no-player-facing-changes note. CI does not commit changelog rollover edits back to the repository.

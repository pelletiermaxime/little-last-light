@/home/maximep/.codex/RTK.md

## Changelog

- Update `CHANGELOG.md` in the same change as player-facing gameplay, balance, UI, bug fixes, or release behavior. Use concise player-facing bullets under `### Added`, `### Changed`, or `### Fixed` in `## [Unreleased]`; omit empty categories.
- Do not guess or bump patch versions before merging: CI assigns them automatically. After desktop publication succeeds, the release workflow commits the assigned `project.godot` version and moves the published entries into `## [X.Y.Z] - YYYY-MM-DD` using GitHub's actual UTC publication date, preserving newer Unreleased entries. If a legacy release or failed writeback left consumed notes in Unreleased, verify the published release before repairing that rollover.
- Keep released entries as history. Do not rewrite older releases to describe newer behavior. Correct inaccurate release notes in both the file and the corresponding GitHub release. Development-only previews, comparison tools, test launchers, tests, and internal refactors do not belong in player-facing changelogs unless they change the shipped player experience.
- `scripts/prepare-release.py` uses the matching version section when present, otherwise Unreleased. Empty or unchanged Unreleased entries produce a no-player-facing-changes note. Its `--record-published` mode performs the automatic post-publication writeback; retries must preserve future entries and never downgrade the version. Do not manually move release tags from the source commit to the later metadata commit.

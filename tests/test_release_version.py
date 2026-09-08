"""Regression checks for version ordering and safe release retries."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "prepare_release", Path(__file__).resolve().parents[1] / "scripts/prepare-release.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseVersionTests(unittest.TestCase):
    def test_first_release(self):
        self.assertEqual(release.choose_version("0.0.1", {}, "new"), (0, 0, 1))

    def test_patch_order_is_numeric(self):
        tags = {"v0.0.9": "a", "v0.0.10": "b"}
        self.assertEqual(release.choose_version("0.0.1", tags, "new"), (0, 0, 11))

    def test_retry_reuses_version_even_after_newer_release(self):
        tags = {"v0.0.1": "original", "v0.0.2": "newer"}
        self.assertEqual(release.choose_version("0.0.1", tags, "original"), (0, 0, 1))

    def test_manual_minor_bump_sets_new_minimum(self):
        self.assertEqual(
            release.choose_version("0.1.0", {"v0.0.9": "old"}, "new"), (0, 1, 0)
        )

    def test_rejects_invalid_base(self):
        for value in ["0.01.1", "0.0", "0.0.1\n", "0.0.1; echo bad"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                release.choose_version(value, {}, "new")


class ReleaseChangelogTests(unittest.TestCase):
    def manifest(self, consumed="### Added\n\n- Ember Pot."):
        return {"version": "0.0.2", "changes": consumed,
                "consumed_unreleased": consumed}

    def test_record_rolls_entries_and_preserves_history(self):
        source = "# Changelog\n\n## [Unreleased]\n\n### Added\n\n- Ember Pot.\n\n## [0.0.1] - 2026-09-01\n\n- Old.\n"
        actual = release.record_changelog(source, self.manifest(), "2026-09-08")
        self.assertEqual(release.changelog_sections(actual)["Unreleased"], "")
        self.assertIn("## [0.0.2] - 2026-09-08\n\n### Added\n\n- Ember Pot.", actual)
        self.assertTrue(actual.endswith("## [0.0.1] - 2026-09-01\n\n- Old.\n"))
        self.assertEqual(release.record_changelog(actual, self.manifest(), "2026-09-08"), actual)

    def test_record_preserves_concurrent_additions_and_edits(self):
        source = "## [Unreleased]\n\n### Added\n\n- Ember Pot.\n- Future enemy.\n\n### Fixed\n\n- New fix.\n"
        actual = release.record_changelog(source, self.manifest(), "2026-09-08")
        self.assertEqual(release.changelog_sections(actual)["Unreleased"], "### Added\n\n- Future enemy.\n\n### Fixed\n\n- New fix.")
        edited = "## [Unreleased]\n\n### Added\n\n- Ember Pot now does more damage.\n"
        actual = release.record_changelog(edited, self.manifest(), "2026-09-08")
        self.assertIn("more damage", release.changelog_sections(actual)["Unreleased"])

    def test_record_does_not_erase_future_repeated_entries_on_retry(self):
        source = "## [Unreleased]\n\n### Added\n\n- Ember Pot.\n\n## [0.0.2] - 2026-09-08\n\n- Corrected published notes.\n"
        self.assertEqual(release.record_changelog(source, self.manifest(), "2026-09-08"), source)

    def test_record_empty_release_and_multiline_entries(self):
        manifest = self.manifest("")
        manifest["changes"] = "- No player-facing changes recorded for this release."
        actual = release.record_changelog("## [Unreleased]\n", manifest, "2026-09-08")
        self.assertEqual(release.changelog_sections(actual)["Unreleased"], "")
        self.assertEqual(release.changelog_sections(actual)["0.0.2"], manifest["changes"])
        body = "### Added\n\n- A turret.\n  With a second line.\n- Future."
        consumed = "### Added\n\n- A turret.\n  With a second line."
        self.assertEqual(release.remaining_unreleased(body, consumed), "### Added\n\n- Future.")

    def test_record_keeps_category_and_duplicate_entries_distinct(self):
        source = "### Added\n\n- Same.\n- Same.\n\n### Fixed\n\n- Same."
        self.assertEqual(release.remaining_unreleased(source, "### Added\n\n- Same."), "### Added\n\n- Same.\n\n### Fixed\n\n- Same.")

    def test_delayed_record_inserts_in_version_order(self):
        source = "## [Unreleased]\n\n## [0.0.10] - 2026-09-09\n\n- Latest.\n\n## [0.0.1] - 2026-09-01\n\n- Old.\n"
        actual = release.record_changelog(source, self.manifest(), "2026-09-08")
        self.assertLess(actual.index("## [0.0.10]"), actual.index("## [0.0.2]"))
        self.assertLess(actual.index("## [0.0.2]"), actual.index("## [0.0.1]"))

    def test_unreleased_preserves_categories_and_markdown(self):
        body = "### Added\n\n- A **new** turret.\n\n### Fixed\n\n- Targeting."
        source = f"# Changelog\n\n## [Unreleased]\n\n{body}\n\n## [0.0.1] - 2026-09-01\n\n- Old.\n"
        self.assertEqual(release.release_changes(source, "0.0.2"), body)

    def test_matching_version_takes_priority_on_retry(self):
        source = "## [Unreleased]\n- Future.\n## [v0.0.2] - 2026-09-07\n- Current.\n## [0.0.1]\n- Old."
        self.assertEqual(release.release_changes(source, "0.0.2"), "- Current.")

    def test_empty_or_unchanged_unreleased_does_not_repeat_notes(self):
        for source, previous in [
            ("## [Unreleased]\n", ""),
            ("## [Unreleased]\n- Old.\n", "## [Unreleased]\n- Old.\n"),
        ]:
            with self.subTest(source=source):
                self.assertEqual(
                    release.release_changes(source, "0.0.2", previous),
                    "- No player-facing changes recorded for this release.",
                )

    def test_archived_previous_entries_allow_fresh_notes(self):
        previous = "## [Unreleased]\n- Old."
        source = "## [Unreleased]\n- New.\n## [0.0.1]\n- Old."
        self.assertEqual(release.release_changes(source, "0.0.2", previous), "- New.")

    def test_missing_duplicate_and_empty_version_sections_fail(self):
        for source in [
            "# Changelog\n## [0.0.1]\n- Old.",
            "## [Unreleased]\n- One.\n## [Unreleased]\n- Two.",
            "## [Unreleased]\n- Future.\n## [0.0.2]\n",
        ]:
            with self.subTest(source=source), self.assertRaises(ValueError):
                release.release_changes(source, "0.0.2")

    def test_build_metadata_and_retry_in_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            shutil.copyfile(spec.origin, root / "scripts/prepare-release.py")
            (root / "project.godot").write_text('[application]\nconfig/version="0.0.1"\n')
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True, stderr=subprocess.STDOUT).strip()

            git("init")
            git("config", "user.name", "Release Test")
            git("config", "user.email", "release@example.invalid")
            git("add", ".")
            git("commit", "-m", "Original release without changelog")
            git("tag", "v0.0.1")
            (root / "CHANGELOG.md").write_text("## [Unreleased]\n\n### Changed\n\n- Stronger slow turrets.\n")
            git("add", "CHANGELOG.md")
            git("commit", "-m", "Internal commit title must not become release notes")
            commit = git("rev-parse", "HEAD")
            env = {**os.environ, "GITHUB_OUTPUT": str(root / "outputs"), "GITHUB_REPOSITORY": "example/game"}

            def build():
                subprocess.run([sys.executable, "scripts/prepare-release.py"], cwd=root, env=env, check=True, capture_output=True, text=True)
                return (root / "export/release/notes.md").read_text()

            notes = build()
            self.assertIn("# Little Last Light v0.0.2", notes)
            self.assertIn("### Changed\n\n- Stronger slow turrets.", notes)
            self.assertNotIn("Internal commit title", notes)
            self.assertIn(commit, notes)
            self.assertIn("https://github.com/example/game/compare/v0.0.1...v0.0.2", notes)
            self.assertIn("## Downloads", notes)
            self.assertEqual((root / "export/release/version.txt").read_text(), "0.0.2\n")
            self.assertIn('config/version="0.0.2"', (root / "project.godot").read_text())
            self.assertEqual((root / "outputs").read_text(), "version=0.0.2\ntag=v0.0.2\n")
            git("tag", "v0.0.2")
            self.assertEqual(build(), notes)
            manifest = json.loads((root / "export/release/publication.json").read_text())
            self.assertEqual(manifest["commit"], commit)
            self.assertEqual(manifest["version"], "0.0.2")
            # A merge lands while publication is running. Record only this release.
            changelog = root / "CHANGELOG.md"
            changelog.write_text(changelog.read_text() + "- A later change.\n")
            git("add", "CHANGELOG.md")
            git("commit", "-m", "Concurrent player-facing change")
            # The recording job has a fresh checkout, not the stamped build copy.
            git("checkout", "--", "project.godot")
            self.assertIn('config/version="0.0.1"', (root / "project.godot").read_text())
            command = [sys.executable, "scripts/prepare-release.py", "--record-published",
                       "export/release/publication.json", "--published-at", "2026-09-07T21:00:00-04:00"]
            subprocess.run(command, cwd=root, check=True, capture_output=True)
            self.assertIn('config/version="0.0.2"', (root / "project.godot").read_text())
            self.assertIn("## [0.0.2] - 2026-09-08", changelog.read_text())
            self.assertEqual(release.changelog_sections(changelog.read_text())["Unreleased"], "### Changed\n\n- A later change.")
            git("add", "project.godot", "CHANGELOG.md")
            git("commit", "-m", "Record published release [skip ci]")
            recorded = changelog.read_text()
            # Retry must be a no-op and must never lower a newer version/minimum.
            (root / "project.godot").write_text('[application]\nconfig/version="0.1.0"\n')
            subprocess.run(command, cwd=root, check=True, capture_output=True)
            self.assertEqual(changelog.read_text(), recorded)
            self.assertIn('config/version="0.1.0"', (root / "project.godot").read_text())
            # Restore the original pre-rollover retry fixture for the old no-note check.
            git("checkout", "v0.0.2", "--", "project.godot", "CHANGELOG.md")
            git("commit", "-m", "Restore fixture")
            git("commit", "--allow-empty", "-m", "Maintenance only")
            self.assertIn("No player-facing changes recorded", build())


if __name__ == "__main__":
    unittest.main()

"""Regression checks for version ordering and safe release retries."""
import importlib.util
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
            git("commit", "--allow-empty", "-m", "Maintenance only")
            self.assertIn("No player-facing changes recorded", build())


if __name__ == "__main__":
    unittest.main()

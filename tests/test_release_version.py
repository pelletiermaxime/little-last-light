"""Regression checks for version ordering and safe release retries."""
import importlib.util
from pathlib import Path
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


if __name__ == "__main__":
    unittest.main()

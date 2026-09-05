import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("configure", Path(__file__).parents[1] / "scripts/configure-leaderboard.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LeaderboardConfigTests(unittest.TestCase):
    def test_urls_are_embedded_and_absent_environment_preserves_local_settings(self):
        original = '[leaderboard]\napi_url=""\nsite_url=""\n'
        self.assertEqual(module.configure(original, {}), original)
        configured = module.configure(original, {"LEADERBOARD_API_URL": "https://game.convex.site/", "LEADERBOARD_SITE_URL": "https://game.example/board/"})
        self.assertIn('api_url="https://game.convex.site"', configured)
        self.assertIn('site_url="https://game.example/board"', configured)

    def test_rejects_credentials_and_invalid_urls(self):
        for value in ['http://example.com', 'https://user:secret@example.com', 'https://example.com?q=x', 'not-a-url']:
            with self.assertRaises(ValueError):
                module.configure('api_url=""', {"LEADERBOARD_API_URL": value})

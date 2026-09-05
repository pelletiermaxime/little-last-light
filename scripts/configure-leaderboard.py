#!/usr/bin/env python3
"""Embed public leaderboard URLs in exports; no deployment credentials belong here."""
import json
import os
from pathlib import Path
import re
from urllib.parse import urlparse


def configure(text: str, environment: dict) -> str:
    for variable, setting in [("LEADERBOARD_API_URL", "api_url"), ("LEADERBOARD_SITE_URL", "site_url")]:
        if variable not in environment:
            continue
        value = environment[variable].strip().rstrip("/")
        parsed = urlparse(value)
        if value and (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment):
            raise ValueError(f"{variable} must be an HTTPS URL without credentials, query, or fragment")
        text, count = re.subn(rf"^{setting}=.*$", lambda _: f"{setting}={json.dumps(value)}", text, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f"Expected exactly one {setting} setting")
    return text


if __name__ == "__main__":
    project = Path(__file__).resolve().parent.parent / "project.godot"
    project.write_text(configure(project.read_text(), os.environ))

#!/usr/bin/env python3
"""Display the exported build's version in the browser page."""

from html import escape
from pathlib import Path
import re
import sys


def stamp_version(path: Path) -> None:
    html = path.read_text()
    if "</body>" not in html:
        raise ValueError("Exported page has no closing body tag")
    version = path.with_name("version.txt").read_text().strip()
    if not version:
        raise ValueError("Exported build has no version")
    html = re.sub(r'<a\b[^>]*\bid="game-source-link"[^>]*>.*?</a>\s*', '', html, flags=re.DOTALL)
    html = re.sub(r'<span\b[^>]*\bid="game-version"[^>]*>.*?</span>\s*', '', html, flags=re.DOTALL)
    label = (
        '<span id="game-version" '
        'style="position:fixed;right:8px;bottom:8px;z-index:100;'
        'padding:4px 8px;color:#bfd0d8;pointer-events:none;user-select:none;'
        f'font:12px sans-serif">v{escape(version)}</span>\n'
    )
    path.write_text(html.replace("</body>", label + "</body>", 1).rstrip() + "\n")


if __name__ == "__main__":
    stamp_version(Path(sys.argv[1]))

#!/usr/bin/env python3
"""Expose the accompanying GPL source archive on the exported browser page."""

from pathlib import Path
import sys


def add_source_link(path: Path) -> None:
    html = path.read_text()
    if 'id="game-source-link"' in html:
        return
    if "</body>" not in html:
        raise ValueError("Exported page has no closing body tag")
    link = (
        '<a id="game-source-link" href="little-last-light-source.zip" download '
        'style="position:fixed;right:8px;bottom:8px;z-index:100;'
        'padding:4px 8px;background:#17232d;color:#e8f1f1;'
        'font:12px sans-serif;border-radius:4px">Source (GPLv3)</a>\n'
    )
    path.write_text(html.replace("</body>", link + "</body>", 1))


if __name__ == "__main__":
    add_source_link(Path(sys.argv[1]))

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
godot_bin="${GODOT_BIN:-godot}"
python3 scripts/prepare-release.py
python3 scripts/configure-leaderboard.py

# Keep desktop binaries outside the directory uploaded to Pages.
mkdir -p export/{web,windows,linux,downloads}
touch export/.gdignore
"$godot_bin" --headless --editor --import
for check in tests/check_*.gd; do
  "$godot_bin" --headless --script "$check"
done
"$godot_bin" --headless --export-release Web export/web/index.html
"$godot_bin" --headless --export-release Windows export/windows/little-last-light.exe
"$godot_bin" --headless --export-release Linux export/linux/little-last-light.x86_64

test -s export/web/index.html
test -s export/web/index.wasm
test -s export/web/index.pck
test -s export/windows/little-last-light.exe
test -s export/linux/little-last-light.x86_64
chmod +x export/linux/little-last-light.x86_64
cp export/release/version.txt export/web/version.txt
cp export/release/version.txt export/windows/version.txt
cp export/release/version.txt export/linux/version.txt
# Supply matching game source with every build, including browser downloads.
# The independently hosted backend is not linked into the game executable.
git archive --format=zip --output=export/downloads/little-last-light-source.zip HEAD -- . ':!leaderboard' ':!.github' ':!.agents' ':!.codex'
# Release preparation stamps these files after checkout; include their exact
# exported versions instead of the pre-stamp copies from the source commit.
zip -q export/downloads/little-last-light-source.zip project.godot export_presets.cfg
for platform in web windows linux; do
  cp LICENSE.txt THIRD_PARTY_NOTICES.txt README.md export/downloads/little-last-light-source.zip "export/$platform/"
done
python3 scripts/link-web-source.py export/web/index.html
touch export/web/.nojekyll

# tar preserves the Linux executable permission; Windows gets a zip.
rm -f export/downloads/little-last-light-windows-x86_64.zip
(cd export/windows && zip -q -r ../downloads/little-last-light-windows-x86_64.zip .)
tar -czf export/downloads/little-last-light-linux-x86_64.tar.gz -C export/linux .
(cd export/downloads && sha256sum ./*.zip ./*.tar.gz > SHA256SUMS.txt)

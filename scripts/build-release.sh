#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
godot_bin="${GODOT_BIN:-godot}"
python3 scripts/prepare-release.py

# Keep desktop binaries outside the directory uploaded to Pages.
mkdir -p export/{web,windows,linux,downloads}
touch export/.gdignore
"$godot_bin" --headless --editor --import
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
touch export/web/.nojekyll

# tar preserves the Linux executable permission; Windows gets a zip.
rm -f export/downloads/little-last-light-windows-x86_64.zip
(cd export/windows && zip -q -r ../downloads/little-last-light-windows-x86_64.zip .)
tar -czf export/downloads/little-last-light-linux-x86_64.tar.gz -C export/linux .
(cd export/downloads && sha256sum ./*.zip ./*.tar.gz > SHA256SUMS.txt)

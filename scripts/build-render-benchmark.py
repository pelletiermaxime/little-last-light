#!/usr/bin/env python3
"""Export a disposable Web benchmark without changing the game's startup scene."""

import argparse
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ref", help="Build a committed Git revision with the current benchmark harness")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    godot = os.environ.get("GODOT_BIN", "godot")
    with tempfile.TemporaryDirectory(prefix="lll-render-benchmark-") as temporary:
        project = Path(temporary) / "project"
        project.mkdir()
        if args.ref:
            archive = subprocess.check_output(["git", "archive", "--format=tar", args.ref], cwd=source)
            with tarfile.open(fileobj=io.BytesIO(archive)) as files:
                files.extractall(project, filter="data")
        else:
            shutil.copytree(
                source, project, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(
                    ".git", ".godot", "export", "node_modules", ".nuxt", ".output",
                    "dist", "test-results", "playwright-report", ".wrangler", ".env*",
                ),
            )
        for name in ["benchmark_rendering.gd", "benchmark_rendering.tscn"]:
            shutil.copy2(source / "tests" / name, project / "tests" / name)
        settings = project / "project.godot"
        settings.write_text(re.sub(
            r'^run/main_scene=.*$', 'run/main_scene="res://tests/benchmark_rendering.tscn"',
            settings.read_text(), flags=re.MULTILINE,
        ))
        subprocess.run([godot, "--headless", "--path", str(project), "--editor", "--import"], check=True)
        subprocess.run([
            godot, "--headless", "--path", str(project),
            "--export-release", "Web", str(output / "index.html"),
        ], check=True)
    shutil.copy2(source / "tests" / "benchmark_rendering.html", output / "benchmark.html")
    print(f"Benchmark ready: {output / 'benchmark.html'}")


if __name__ == "__main__":
    main()

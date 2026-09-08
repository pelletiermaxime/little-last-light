#!/usr/bin/env python3
"""Select an automatic patch version, stamp the build, and write release notes."""

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess


VERSION_RE = re.compile(r"v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")


def version_tuple(value):
    match = VERSION_RE.fullmatch(value)
    if not match:
        raise ValueError(f"Invalid version: {value!r}")
    return tuple(map(int, match.groups()))


def choose_version(base, tags, commit):
    """Tags map version strings to commits; retries keep their existing version."""
    versions = sorted((version_tuple(tag), sha) for tag, sha in tags.items())
    existing = [version for version, sha in versions if sha == commit]
    if existing:
        return existing[-1]
    minimum = version_tuple(base)
    if not versions:
        return minimum
    major, minor, patch = versions[-1][0]
    return max(minimum, (major, minor, patch + 1))


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def changelog_sections(source):
    """Read level-two release headings, preserving Markdown within each entry."""
    sections = {}
    heading = None
    lines = []
    for line in source.splitlines() + ["## "]:
        if line.startswith("## "):
            if heading is not None:
                if heading in sections:
                    raise ValueError(f"Duplicate changelog section: {heading}")
                sections[heading] = "\n".join(lines).strip()
            match = re.fullmatch(r"## \[(Unreleased|v?\d+\.\d+\.\d+)\](?: - \d{4}-\d{2}-\d{2})?", line)
            heading = match[1].removeprefix("v") if match else None
            lines = []
        else:
            lines.append(line)
    return sections


def release_changes(source, version, previous_source=""):
    sections = changelog_sections(source)
    if version in sections:
        if not sections[version]:
            raise ValueError(f"Empty changelog section for {version}")
        return sections[version]
    if "Unreleased" not in sections:
        raise ValueError("CHANGELOG.md must contain an [Unreleased] section")
    changes = sections["Unreleased"]
    previous = changelog_sections(previous_source).get("Unreleased", "")
    if not changes or changes == previous:
        return "- No player-facing changes recorded for this release."
    return changes


def remaining_unreleased(current, consumed):
    """Remove only exact published entries; retain additions and edited entries."""
    def groups(body):
        parts = re.split(r"(?m)^(### .+)\n", body)
        pairs = [("", parts[0])]
        pairs.extend(zip(parts[1::2], parts[2::2]))
        return [(heading, [entry.strip() for entry in re.split(r"(?m)(?=^- )", text)
                           if entry.strip()]) for heading, text in pairs]

    published = Counter((heading, entry) for heading, entries in groups(consumed)
                        for entry in entries)
    result = []
    for heading, entries in groups(current):
        kept = []
        for entry in entries:
            key = (heading, entry)
            if published[key]:
                published[key] -= 1
            else:
                kept.append(entry)
        if kept:
            result.append((heading + "\n\n" if heading else "") + "\n".join(kept))
    return "\n\n".join(result)


def record_changelog(source, manifest, publication_date):
    sections = changelog_sections(source)
    version = manifest["version"]
    # A retry must not consume future entries or overwrite editorial corrections.
    if version in sections:
        return source
    if "Unreleased" not in sections:
        raise ValueError("CHANGELOG.md must contain an [Unreleased] section")
    heading = re.search(r"(?m)^## \[Unreleased\][^\n]*\n", source)
    following = re.search(r"(?m)^## ", source[heading.end():])
    end = heading.end() + following.start() if following else len(source)
    remaining = remaining_unreleased(sections["Unreleased"], manifest["consumed_unreleased"])
    source = source[:heading.end()] + "\n" + (remaining + "\n\n" if remaining else "") + source[end:]
    # Keep history in descending version order even on a delayed retry.
    insertion = len(source)
    for match in re.finditer(r"(?m)^## \[(v?\d+\.\d+\.\d+)\].*$", source):
        if version_tuple(match[1]) < version_tuple(version):
            insertion = match.start()
            break
    entry = f"## [{version}] - {publication_date}\n\n{manifest['changes']}\n\n"
    return source[:insertion].rstrip() + "\n\n" + entry + source[insertion:]


def record_published(manifest_path, published_at):
    manifest = json.loads(Path(manifest_path).read_text())
    version_tuple(manifest["version"])
    publication = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
    if publication.tzinfo is None:
        raise ValueError("Publication timestamp must include a timezone")
    date = publication.astimezone(timezone.utc).date().isoformat()
    subprocess.run(["git", "merge-base", "--is-ancestor", manifest["commit"], "HEAD"], check=True)
    changelog = Path("CHANGELOG.md")
    updated_changelog = record_changelog(changelog.read_text(), manifest, date)
    project = Path("project.godot")
    source = project.read_text()
    match = re.search(r'^config/version="([^"]+)"$', source, re.MULTILINE)
    if not match:
        raise ValueError("project.godot must define config/version")
    # Preserve a newer publication or a manually requested major/minor minimum.
    if version_tuple(match[1]) < version_tuple(manifest["version"]):
        source = source[:match.start(1)] + manifest["version"] + source[match.end(1):]
    changelog.write_text(updated_changelog)
    project.write_text(source)


def main():
    os.chdir(Path(__file__).resolve().parents[1])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record-published", metavar="MANIFEST")
    parser.add_argument("--published-at", help="Actual GitHub release publication timestamp")
    args = parser.parse_args()
    if args.record_published:
        if not args.published_at:
            parser.error("--record-published requires --published-at")
        record_published(args.record_published, args.published_at)
        return
    commit = git("rev-parse", "HEAD")
    tags = {
        tag: git("rev-list", "-n", "1", tag)
        for tag in git("tag", "--list", "v*").splitlines()
        if VERSION_RE.fullmatch(tag)
    }
    project = Path("project.godot")
    source = project.read_text()
    base_match = re.search(r'^config/version="([^"]+)"$', source, re.MULTILINE)
    if not base_match:
        raise ValueError("project.godot must define config/version")
    selected = choose_version(base_match[1], tags, commit)
    version = ".".join(map(str, selected))
    tag = f"v{version}"
    previous = sorted(t for t in tags if version_tuple(t) < selected)
    previous = max(previous, key=version_tuple) if previous else None
    previous_source = ""
    if previous and "CHANGELOG.md" in git("ls-tree", "--name-only", previous, "CHANGELOG.md").splitlines():
        previous_source = git("show", f"{previous}:CHANGELOG.md")
    changelog_source = Path("CHANGELOG.md").read_text()
    changes = release_changes(changelog_source, version, previous_source)
    notes = (
        f"# Little Last Light {tag}\n\n"
        f"Built from commit `{commit}`.\n\n"
        "## Changes\n\n" + changes + "\n\n"
        "## Downloads\n\n"
        "Extract the Windows ZIP and run `little-last-light.exe`, or extract the Linux "
        "tarball and run `./little-last-light.x86_64`. These are unsigned x86_64 builds. "
        "`SHA256SUMS.txt` contains archive checksums.\n\n"
        "[Play in your browser](https://pelletiermaxime.github.io/little-last-light-demo/).\n"
    )
    if previous:
        repo = os.environ.get("GITHUB_REPOSITORY", "pelletiermaxime/little-last-light")
        notes += f"\n[Full changelog](https://github.com/{repo}/compare/{previous}...{tag}).\n"
    output = Path("export/release")
    output.mkdir(parents=True, exist_ok=True)
    Path("export/.gdignore").touch()
    (output / "notes.md").write_text(notes)
    (output / "version.txt").write_text(version + "\n")
    sections = changelog_sections(changelog_source)
    (output / "publication.json").write_text(json.dumps({
        "commit": commit, "version": version, "changes": changes,
        "consumed_unreleased": "" if version in sections else sections["Unreleased"],
    }, indent=2) + "\n")
    project.write_text(source[:base_match.start(1)] + version + source[base_match.end(1):])
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as stream:
            stream.write(f"version={version}\ntag={tag}\n")
    print(f"Build version: {tag}")


if __name__ == "__main__":
    main()

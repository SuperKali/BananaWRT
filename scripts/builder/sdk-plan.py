#!/usr/bin/env python3
"""Resolve SDK builds from the active configurations in this checkout.

Version bumps (--before) only cover upstream ImmortalWrt lines. A fork line
(version.json sets repo_url) builds its SDK only when asked for by track or
by version, since its branch name does not change when its source does.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

SDK_TRACKS = ('stable', 'oldstable', 'nightly', 'mtk-vendor')
VERSION = re.compile(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9][A-Za-z0-9.-]*)?')
FORK_VERSION = re.compile(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?-[A-Za-z0-9][A-Za-z0-9.-]*')


def git(*args):
    return subprocess.check_output(('git', *args), text=True)


def resolve(before, versions, track):
    if before:
        git('rev-parse', '--verify', f'{before}^{{commit}}')
    paths = sorted(Path('config').glob('*/version.json'))
    if not paths:
        raise ValueError('No version.json configurations found')

    rows = {}
    for path in paths:
        config = json.loads(path.read_text())
        fork = bool(config.get('repo_url'))
        if config['status'] != 'active' or (fork and before is not None):
            continue
        tracks = [t for t in SDK_TRACKS if t in config['tracks']]
        if not tracks or (track and track not in tracks):
            continue
        version = config['branch']
        line = config['version_line']
        if fork and not track and version not in versions:
            continue
        series = 'v' + '.'.join(re.split(r'[.-]', version)[:2])
        valid = (FORK_VERSION.fullmatch(version) and line.startswith(series + '-')) if fork else \
            (VERSION.fullmatch(version) and line == series)
        if not valid:
            raise ValueError(f'{path}: invalid version or line ({version}, {line})')
        if line != path.parent.name:
            raise ValueError(f'{path}: version line does not match its directory')
        if before and git('ls-tree', '--name-only', before, '--', str(path)):
            previous = json.loads(git('show', f'{before}:{path}'))
            if previous.get('branch') == version:
                continue
        if versions and version not in versions:
            continue
        if version in rows:
            raise ValueError(f'Duplicate SDK version {version}')
        rows[version] = {'version': version, 'version_line': line, 'track': track or tracks[0]}

    if versions and set(rows) != versions:
        raise ValueError(f'No active SDK configuration for {", ".join(sorted(versions - rows.keys()))}')
    if track and len(rows) != 1:
        raise ValueError(f'Expected one active SDK configuration for {track}, found {len(rows)}')
    return list(rows.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--before', help='compare config/ with this previous commit')
    mode.add_argument('--versions', help='build these exact versions, comma-separated')
    mode.add_argument('--track', choices=SDK_TRACKS, help='build the configured version for this track')
    args = parser.parse_args()
    if args.before is not None and not re.fullmatch(r'[0-9a-f]{40}', args.before):
        parser.error('Invalid base commit SHA')
    versions = set(args.versions.split(',')) if args.versions is not None else set()
    if any(not (VERSION.fullmatch(v) or FORK_VERSION.fullmatch(v)) for v in versions):
        parser.error('Invalid SDK version list')
    try:
        print(json.dumps(resolve(args.before, versions, args.track), separators=(',', ':')))
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
        print(f'SDK plan: {exc}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

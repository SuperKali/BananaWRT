#!/usr/bin/env python3
"""Stage the expected SDK artefacts and merge their entries into the CDN index."""

import json
import os
from pathlib import Path
import re
import shutil
import sys

BASE = 'https://repo.superkali.me/bananawrt/sdk'


def stage(artifacts, root, index_path, matrix):
    index = json.loads(index_path.read_text())
    versions = index['versions']
    if not isinstance(versions, dict) or not all(
        isinstance(value, dict) and isinstance(value.get('architectures'), dict)
        for value in versions.values()
    ):
        raise ValueError('Invalid existing SDK master index')
    if not matrix['include']:
        raise ValueError('Empty SDK matrix')

    receipt = {}
    for row in matrix['include']:
        version, arch = row['version'], row['arch']
        if arch not in ('X64', 'ARM64') or not re.fullmatch(r'[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[A-Za-z0-9][A-Za-z0-9.-]*)?', version):
            raise ValueError(f'Invalid SDK matrix row: {row}')
        if (version, arch) in receipt:
            raise ValueError(f'Duplicate SDK artefact: {version}/{arch}')
        relative = Path(arch) / version
        directory = artifacts / f'sdk-{arch}-{version}' / 'bananawrt/sdk' / relative
        if len(matrix['include']) == 1 and not directory.is_dir():
            # download-artifact extracts a lone artifact straight into its
            # path, without the directory named after the artifact.
            directory = artifacts / 'bananawrt/sdk' / relative
        info = json.loads((directory / 'sdk-info.json').read_text())
        filename = info['filename']
        url = f'{BASE}/{arch}/{version}/'
        if (
            info['version'] != version or info['architecture'] != arch
            or not re.fullmatch(r'immortalwrt-sdk-[A-Za-z0-9._+~-]+\.tar\.(?:zst|xz|gz)', filename)
            or info['download_url'] != url + filename
            or not re.fullmatch(r'[0-9a-f]{64}', info['sha256'])
            or type(info['size']) is not int or info['size'] < 1
            or (directory / filename).stat().st_size != info['size']
            or (directory / 'config.buildinfo').stat().st_size < 1
        ):
            raise ValueError(f'Invalid SDK artefact: {version}/{arch}')
        target = root / relative
        target.mkdir(parents=True, exist_ok=True)
        for name in (filename, 'config.buildinfo', 'sdk-info.json'):
            shutil.copy2(directory / name, target / name)
        arches = versions.setdefault(version, {'architectures': {}})['architectures']
        arches[arch] = {
            'sdk_url': url, 'config_url': url + 'config.buildinfo', 'info_url': url + 'sdk-info.json',
        }
        receipt[version, arch] = {
            key: info[key] for key in ('version', 'architecture', 'filename', 'sha256', 'size')
        }

    (root / 'sdk-master-index.json').write_text(json.dumps(index, indent=2) + '\n')
    return list(receipt.values())


if __name__ == '__main__':
    try:
        result = stage(*(Path(p) for p in sys.argv[1:4]), json.loads(os.environ['SDK_MATRIX']))
        print(json.dumps(result, separators=(',', ':')))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        sys.exit(f'SDK staging: {exc}')

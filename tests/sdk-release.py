#!/usr/bin/env python3
"""Offline coverage for version-bump SDKs and package dispatch."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts/builder'
BASE = 'https://repo.superkali.me/bananawrt/sdk'
VERSION = '25.12.3'


def run(*args, cwd, env=None):
    return subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


class SdkRelease(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)

    def git(self, *args):
        result = run('git', *args, cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def config(self, line, version, tracks, status='active', **extra):
        save(self.root / 'config' / line / 'version.json', dict(
            version_line=line, branch=version, tracks=tracks, status=status, **extra,
        ))

    def plan(self, *args, success=True):
        result = run(sys.executable, '-I', SCRIPTS / 'sdk-plan.py', *args, cwd=self.root)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stderr

    def test_changed_upstream_versions_only(self):
        self.git('init', '-q')
        self.git('config', 'user.name', 'SDK Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.config('v24.10', '24.10.6', ['oldstable'])
        self.config('v25.12', '25.12.2', ['stable'])
        self.config('v25.12-mtk-vendor', '25.12-linkup', ['mtk-vendor'], repo_url='https://example.invalid')
        self.config('v23.05', '23.05.1', ['oldstable'], status='eol')
        self.git('add', 'config')
        self.git('commit', '-qm', 'Seed version configs')
        before = self.git('rev-parse', 'HEAD')
        self.assertEqual(self.plan('--before', before), [])
        self.config('v25.12', '25.12.2', ['nightly', 'stable'])
        self.config('v25.12-mtk-vendor', '25.12-linkup-v2', ['mtk-vendor'], repo_url='https://example.invalid')
        self.config('v23.05', '23.05.2', ['oldstable'], status='eol')
        self.assertEqual(self.plan('--before', before), [])
        self.config('v24.10', '24.10.7', ['oldstable'])
        self.config('v25.12', VERSION, ['stable', 'nightly'])
        self.config('v26.02', '26.02.0-rc1', ['nightly'])
        result = self.plan('--before', before)
        self.assertEqual([(r['version'], r['track']) for r in result], [
            ('24.10.7', 'oldstable'), (VERSION, 'stable'), ('26.02.0-rc1', 'nightly'),
        ])
        self.assertEqual(self.plan('--track', 'stable'), [result[1]])
        self.assertEqual(self.plan('--versions', VERSION + ',24.10.7'), result[:2])
        self.assertIn('No active SDK configuration', self.plan('--versions', '23.05.2', success=False))
        fork = {'version': '25.12-linkup-v2', 'version_line': 'v25.12-mtk-vendor', 'track': 'mtk-vendor'}
        self.assertEqual(self.plan('--track', 'mtk-vendor'), [fork])
        self.assertEqual(self.plan('--versions', '25.12-linkup-v2'), [fork])
        self.assertEqual(self.plan('--versions', VERSION), [result[1]])
        self.assertNotEqual(self.plan('--before', 'f' * 40, success=False), '')

    def fixtures(self):
        out = []
        for arch in ('X64', 'ARM64'):
            filename = f'immortalwrt-sdk-{VERSION}-{arch}.tar.zst'
            directory = self.root / f'artefacts/sdk-{arch}-{VERSION}/bananawrt/sdk/{arch}/{VERSION}'
            url = f'{BASE}/{arch}/{VERSION}/'
            record = dict(version=VERSION, architecture=arch, filename=filename, sha256='a' * 64, size=7)
            save(directory / 'sdk-info.json', dict(record, download_url=url + filename))
            (directory / filename).write_bytes(b'sdk tar')
            (directory / 'config.buildinfo').write_text('CONFIG_SDK=y\n')
            out.append(record)
        self.index = self.root / 'current.json'
        self.previous = {'versions': {'24.10.6': {'architectures': {'ARM64': {'sdk_url': 'old'}}}}}
        save(self.index, self.previous)
        self.dest = self.root / 'publish'
        self.env = dict(os.environ, SDK_MATRIX=json.dumps({'include': [
            {'version': VERSION, 'arch': arch} for arch in ('X64', 'ARM64')
        ]}))
        return out

    def stage(self):
        return run(sys.executable, '-I', SCRIPTS / 'stage-sdk-release.py', self.root / 'artefacts',
                   self.dest, self.index, cwd=self.root, env=self.env)

    def test_merge_index_and_require_every_artifact(self):
        expected = self.fixtures()
        result = self.stage()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), expected)
        merged = json.loads((self.dest / 'sdk-master-index.json').read_text())['versions']
        self.assertEqual(merged['24.10.6'], self.previous['versions']['24.10.6'])
        self.assertEqual(set(merged[VERSION]['architectures']), {'ARM64', 'X64'})
        for record in expected:
            self.assertTrue((self.dest / record['architecture'] / VERSION / record['filename']).is_file())
        self.dest = self.root / 'no-index'
        save(self.index, {'versions': []})
        self.assertNotEqual(self.stage().returncode, 0)
        self.assertFalse((self.dest / 'sdk-master-index.json').exists())
        save(self.index, self.previous)
        missing = self.root / f'artefacts/sdk-ARM64-{VERSION}/bananawrt/sdk/ARM64/{VERSION}/config.buildinfo'
        missing.unlink()
        self.assertNotEqual(self.stage().returncode, 0)
        self.assertFalse((self.dest / 'sdk-master-index.json').exists())

    def test_cdn_gates_package_dispatch(self):
        receipt = self.fixtures()
        staged = self.stage()
        self.assertEqual(staged.returncode, 0, staged.stderr)
        bin_dir = self.root / 'bin'
        bin_dir.mkdir()
        curl = bin_dir / 'curl'
        curl.write_text('''#!/usr/bin/env python3
import os, sys
from pathlib import Path
root = Path(os.environ['MOCK_ROOT'])
path = sys.argv[-1].split('/bananawrt/sdk/', 1)[1]
mode = os.environ.get('MOCK_FAILURE')
if mode == 'invalid-index' and path == 'sdk-master-index.json':
    print('{')
    sys.exit(0)
if path == 'sdk-master-index.json' and mode == 'retry':
    counter = root / 'retry'
    if not counter.exists():
        counter.touch()
        sys.exit(22)
if mode == 'missing-archive' and path.endswith('.tar.zst'):
    sys.exit(22)
p = root / 'publish' / path
if not p.is_file():
    sys.exit(22)
if '--head' not in sys.argv:
    data = p.read_bytes()
    if mode == 'stale-sha' and path.endswith('sdk-info.json'):
        data = data.replace(b'a' * 64, b'b' * 64)
    sys.stdout.buffer.write(data)
''')
        gh = bin_dir / 'gh'
        gh.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$MOCK_ROOT/gh.calls"
tee "$MOCK_ROOT/gh.payload" >/dev/null
printf '%s\\n' '{"workflow_run_id":123456}'
''')
        curl.chmod(0o755)
        gh.chmod(0o755)
        output = self.root / 'dispatch.outputs'
        env = dict(self.env, PATH=f"{bin_dir}:{os.environ['PATH']}", MOCK_ROOT=str(self.root),
                   SDK_VERSIONS=VERSION, SDK_RECEIPT=json.dumps(receipt), SDK_POLL_ATTEMPTS='2', SDK_POLL_SECONDS='0',
                   GITHUB_OUTPUT=str(output))
        mark = self.root / 'gh.calls'
        for fail in ('invalid-index', 'missing-archive', 'stale-sha'):
            with self.subTest(fail=fail):
                result = run('bash', SCRIPTS / 'trigger-sdk-packages.sh', cwd=self.root,
                             env=dict(env, MOCK_FAILURE=fail))
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse(mark.exists())
        result = run('bash', SCRIPTS / 'trigger-sdk-packages.sh', cwd=self.root,
                     env=dict(env, SDK_RECEIPT=json.dumps(receipt[:1])))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(mark.exists())
        result = run('bash', SCRIPTS / 'trigger-sdk-packages.sh', cwd=self.root, env=dict(env, MOCK_FAILURE='retry'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('attempt 1/2', result.stdout)
        self.assertEqual(mark.read_text().splitlines(), [
            'api --method POST -H X-GitHub-Api-Version: 2026-03-10 '
            'repos/SuperKali/openwrt-packages/actions/workflows/bananawrt-builder.yml/dispatches --input -',
        ])
        self.assertEqual(json.loads((self.root / 'gh.payload').read_text()), dict(
            ref='main', inputs=dict(versions=VERSION, host_arch='AUTO'),
        ))
        self.assertEqual(output.read_text(), 'run_id=123456\n')

    def test_firmware_uses_the_deployed_feed(self):
        tree = self.root / 'tree'
        feed = tree / 'feeds/additional_pack'
        feed.mkdir(parents=True)
        for args in (
            ('git', 'init', '-q'),
            ('git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
             'commit', '-qm', 'Pinned package feed', '--allow-empty'),
        ):
            result = run(*args, cwd=feed)
            self.assertEqual(result.returncode, 0, result.stderr)
        sha = run('git', 'rev-parse', 'HEAD', cwd=feed).stdout.strip()
        fixture = tree / 'scripts/feeds'
        fixture.parent.mkdir()
        fixture.write_text('#!/bin/sh\nprintf "%s\\n" "$1" >> feed.events\n')
        fixture.chmod(0o755)
        script = self.root / 'builder/scripts/builder/custom-repository.sh'
        script.parent.mkdir(parents=True)
        script.write_bytes((SCRIPTS / script.name).read_bytes())
        script.chmod(0o755)
        invoke = '''set -euo pipefail
        display_subheader() { :; }; substep() { :; }; substep_done() { :; }; substep_fail() { :; }
        exit_with_error() { printf '%s\\n' "$*" >&2; exit 1; }
        source "$1"
        stage_feeds
        '''
        env = dict(os.environ, BANANAWRT_ROOT=str(self.root / 'builder'), BANANAWRT_IMMORTAL_DIR=str(tree),
                   BANANAWRT_VERSION_LINE='v25.12', BANANAWRT_TRACK='stable', BANANAWRT_FEED_BRANCH='main')
        stage = SCRIPTS.parents[1] / 'stages/03-feeds.sh'
        for pin, success, events in (('invalid', False, ''), ('0' * 40, False, 'update\n'),
                                     (sha, True, 'update\ninstall\n')):
            (tree / 'feeds.conf.default').write_text('')
            event_file = tree / 'feed.events'
            event_file.write_text('')
            result = run('bash', '-c', invoke, 'fixture', stage, cwd=tree,
                         env=dict(env, BANANAWRT_FEED_COMMIT=pin))
            self.assertEqual(result.returncode == 0, success, result.stderr)
            self.assertEqual(event_file.read_text(), events)
        self.assertIn('openwrt-packages^' + sha, (tree / 'feeds.conf.default').read_text())

    def test_exact_package_deploy_required(self):
        fake = self.root / 'gh'
        fake.write_text('''#!/bin/sh
case "$*" in
    *runs/123456/jobs*) exec cat "$MOCK_ROOT/jobs.json" ;;
    *runs/123456) exec cat "$MOCK_ROOT/run.json" ;;
    *) exit 90 ;;
esac
''')
        fake.chmod(0o755)
        sha = '1' * 40
        run_info = dict(id=123456, status='completed', conclusion='success',
                        head_branch='main', head_sha=sha, event='workflow_dispatch',
                        path='.github/workflows/bananawrt-builder.yml')
        pin = dict(name='Verify additional_pack Commit', conclusion='success')
        deploy = dict(name=f'Deploy Packages ({VERSION})', conclusion='success')
        build = dict(name=f'Build X64 / {VERSION}', conclusion='success', steps=[pin])
        output = self.root / 'wait.outputs'
        env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}", MOCK_ROOT=str(self.root),
                   PACKAGE_RUN_ID='123456', SDK_VERSIONS=VERSION, GITHUB_OUTPUT=str(output),
                   PACKAGE_POLL_ATTEMPTS='1', PACKAGE_POLL_SECONDS='0')

        for label, record, jobs in (
            ('failed run', dict(run_info, conclusion='failure'), [deploy, build]),
            ('different run', dict(run_info, id=123457), [deploy, build]),
            ('wrong workflow', dict(run_info, path='.github/workflows/other.yml'), [deploy, build]),
            ('missing deploy', run_info, [build]),
            ('missing pin', run_info, [deploy, dict(build, steps=[])]),
            ('skipped deploy', run_info, [dict(deploy, conclusion='skipped'), build]),
            ('still running', dict(run_info, status='in_progress'), [deploy, build]),
            ('success', run_info, [deploy, build]),
        ):
            with self.subTest(label=label):
                save(self.root / 'run.json', record)
                save(self.root / 'jobs.json', [{'jobs': jobs}])
                result = run('bash', SCRIPTS / 'wait-sdk-packages.sh', cwd=self.root, env=env)
                if label == 'success':
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(output.read_text(), f'packages_sha={sha}\n')
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)

"""Release integrity and no-op regressions; only the GitHub boundary is faked."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('candidate', ROOT / 'scripts/concord-candidate.py')
candidate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate)
OLD_DIGEST = '8' * 64


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix='concord-candidate-test-')
        self.addCleanup(self.scratch.cleanup)
        self.previous = Path.cwd()
        os.chdir(self.scratch.name)
        self.addCleanup(os.chdir, self.previous)
        for name in ('Formula', 'nix', 'assets'):
            Path(name).mkdir()
        Path('Formula/concord.rb').write_text(f'version "0.14.1"\nurl "https://example/download/v0.14.1/old.tgz"\nsha256 "{OLD_DIGEST}"\n')
        Path('nix/concord.nix').write_text(f'version = "0.14.1";\nurl = "https://example/download/v0.14.1/old.tgz";\nsha256 = "{OLD_DIGEST}";\n')
        shutil.copytree(ROOT / 'templates', 'templates')
        for name in ('flake.nix', 'flake.lock'):
            shutil.copyfile(ROOT / name, name)
        self.git('init', '--quiet')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--quiet', '--allow-empty', '-m', 'fixture')
        self.git('remote', 'add', 'origin', self.scratch.name)
        self.git('tag', 'v0.14.1')
        self.commit = self.git('rev-parse', 'HEAD').strip()

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True)

    def release(self, tag='v0.14.1', assets=None):
        return {'tag_name': tag, 'draft': False, 'prerelease': False,
                'assets': assets if assets is not None else [{'name': 'concord-sdlc-0.14.1.tgz', 'digest': f'sha256:{OLD_DIGEST}'}]}

    def archive(self, version, target, package_version=None, bad_binding=False):
        native = 'linux-x64-glibc' if target == 'linux-x64' else target
        head = b'\x7fELF' if target == 'linux-x64' else bytes.fromhex('cffaedfe')
        binding = head + b'binding'
        notices = b'notices'
        metadata = {'target': native, 'abi': 'concord-hawdb-1', 'revision': 'revision',
                    'sourceDigest': 'source', 'cargoLockDigest': 'cargo', 'portable': True, 'testHooks': False,
                    'binarySha256': '0' * 64 if bad_binding else hashlib.sha256(binding).hexdigest(),
                    'noticesSha256': hashlib.sha256(notices).hexdigest()}
        members = {'app/package.json': json.dumps({'version': package_version or version, 'gitHead': self.commit}).encode(),
                   f'app/dist/native/{native}/artifact.json': json.dumps(metadata).encode(),
                   f'app/dist/native/{native}/hawdb.node': binding,
                   f'app/dist/native/{native}/THIRD-PARTY-NOTICES.txt': notices,
                   'bin/concord': head + b'program', 'runtime/rg': head + b'ripgrep',
                   'app/node_modules/tool/native': head + b'tool'}
        path = Path('assets') / f'concord-{version}-{target}.tar.gz'
        with tarfile.open(path, 'w:gz') as archive:
            for name, data in members.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        return path, candidate.sha256(path)

    def test_old_current_release_is_verified_without_downloading(self):
        with patch.object(candidate, 'gh', return_value=json.dumps(self.release())) as github:
            result = candidate.prepare('v0.14.1', Path('output'))
        self.assertEqual(result['changed'], 'false')
        self.assertFalse(Path('output').exists())
        github.assert_called_once_with('api', 'repos/CorrectRoadH/Concord/releases/tags/v0.14.1')

    def test_same_version_changed_digest_is_rejected(self):
        release = self.release()
        release['assets'][0]['digest'] = 'sha256:' + '9' * 64
        with patch.object(candidate, 'gh', return_value=json.dumps(release)):
            with self.assertRaisesRegex(ValueError, 'different asset digests'):
                candidate.prepare('v0.14.1', Path('output'))

    def test_invalid_tags_and_rollback_fail_before_network(self):
        with patch.object(candidate, 'gh') as github:
            for tag in ('v01.15.0', 'v0.15.0/other', 'v0.14.0'):
                with self.subTest(tag=tag), self.assertRaises(ValueError):
                    candidate.prepare(tag, Path('output'))
            github.assert_not_called()

    def test_release_requires_unique_api_digests(self):
        for assets in ([], [{'name': 'archive', 'digest': None}], [{'name': 'archive', 'digest': 'sha256:' + OLD_DIGEST}] * 2):
            with self.subTest(assets=assets), self.assertRaises(ValueError):
                candidate.release_digest(self.release(assets=assets), 'archive')

    def test_new_release_downloads_both_platforms_and_generates_candidates(self):
        digests = {}
        for target in candidate.TARGETS:
            _, digests[target] = self.archive('0.15.0', target)
        release = self.release('v0.15.0', [{'name': f'concord-0.15.0-{target}.tar.gz', 'digest': f'sha256:{digest}'} for target, digest in digests.items()])
        def github(*args):
            if args[:1] == ('api',):
                return self.commit if '/commits/' in args[1] else json.dumps(release)
            self.assertEqual(args[:3], ('release', 'download', 'v0.15.0'))
            shutil.copyfile(Path('assets') / args[args.index('--pattern') + 1], Path(args[args.index('--dir') + 1]) / args[args.index('--pattern') + 1])
            return ''
        with patch.object(candidate, 'gh', side_effect=github):
            result = candidate.prepare('v0.15.0', Path('output'))
        self.assertEqual(result['changed'], 'true')
        formula = Path('output/Formula/concord.rb').read_text()
        self.assertIn('app/node_modules/tool/native', formula)
        for target, digest in digests.items():
            self.assertIn(f'concord-0.15.0-{target}.tar.gz', formula)
            self.assertIn(digest, formula)
        self.assertIn('fetchurl {', Path('output/nix/concord.nix').read_text())
        self.assertEqual(Path('output/flake.lock').read_bytes(), Path('flake.lock').read_bytes())
        self.assertIn('version "0.14.1"', Path('Formula/concord.rb').read_text())
        # A retry verifies the two distinct digests without downloading assets.
        for name in ('Formula/concord.rb', 'nix/concord.nix'):
            shutil.copyfile(Path('output') / name, name)
        self.git('tag', 'v0.15.0')
        with patch.object(candidate, 'gh', return_value=json.dumps(release)) as github:
            self.assertEqual(candidate.prepare('v0.15.0', Path('retry'))['changed'], 'false')
            github.assert_called_once()
        self.assertFalse(Path('retry').exists())

    def test_archive_checksum_version_and_binding_are_enforced(self):
        path, digest = self.archive('0.15.0', 'linux-x64', package_version='0.14.1')
        with self.assertRaisesRegex(ValueError, 'SHA-256 differs'):
            candidate.verify_archive(path, '0' * 64, '0.15.0', 'linux-x64')
        with self.assertRaisesRegex(ValueError, 'version differs'):
            candidate.verify_archive(path, digest, '0.15.0', 'linux-x64')
        path, digest = self.archive('0.15.0', 'linux-x64', bad_binding=True)
        with self.assertRaisesRegex(ValueError, 'binary identity differs'):
            candidate.verify_archive(path, digest, '0.15.0', 'linux-x64')

    def test_local_mode_is_rejected_in_actions(self):
        with patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}), patch('sys.argv', ['concord-candidate.py', '--local-assets', 'assets']):
            with self.assertRaisesRegex(ValueError, 'forbidden in CI'):
                candidate.main()


if __name__ == '__main__':
    unittest.main()

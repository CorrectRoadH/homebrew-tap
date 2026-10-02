#!/usr/bin/env python3
"""Generate channel candidates only from the verified immutable release asset."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile

version, tag, digest = (os.environ[key] for key in ('VERSION', 'TAG', 'SHA256'))
assert re.fullmatch(r'(?:concord-)?v' + re.escape(version), tag)
assert re.fullmatch(r'[0-9a-f]{64}', digest)
archive = Path(f'asset/concord-sdlc-{version}.tgz')
assert hashlib.sha256(archive.read_bytes()).hexdigest() == digest
with tarfile.open(archive) as tar:
    tar.extractall('asset/unpacked', filter='data')
package = Path('asset/unpacked/package')
manifest = json.loads((package / 'package.json').read_text())
assert manifest['version'] == version
assert re.fullmatch(r'pnpm@11\.\d+\.\d+', manifest['packageManager'])
for name in ('pnpm-lock.yaml', 'pnpm-workspace.yaml'):
    assert (package / name).is_file(), name
assert not (package / 'npm-shrinkwrap.json').exists()
identities = []
for target in ('linux-x64-glibc', 'darwin-arm64'):
    native = package / 'dist/native' / target
    metadata = json.loads((native / 'artifact.json').read_text())
    assert metadata['target'] == target and metadata['portable'] and not metadata['testHooks']
    assert hashlib.sha256((native / 'hawdb.node').read_bytes()).hexdigest() == metadata['binarySha256']
    identities.append(tuple(metadata[key] for key in ('abi', 'revision', 'sourceDigest', 'cargoLockDigest')))
assert identities[0] == identities[1]
replacements = {'VERSION': version, 'TAG': tag, 'SHA256': digest, 'PNPM_HASH': ''}
for template, destination in [('concord.rb.in', 'Formula/concord.rb'), ('concord.nix.in', 'nix/concord.nix')]:
    text = (Path('templates') / template).read_text()
    for key, value in replacements.items():
        text = text.replace('@' + key + '@', value)
    output = Path('candidate') / destination
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)
# Use the exact pinned nixpkgs and generated candidate, not a registry's moving default.
for name in ('flake.nix', 'flake.lock'):
    (Path('candidate') / name).write_bytes(Path(name).read_bytes())
attribute = 'path:./candidate#packages.x86_64-linux.concord.pnpmDeps'
derivation = subprocess.check_output(['nix', 'eval', '--raw', attribute + '.drvPath'], text=True).strip()
probe = subprocess.run(['nix', 'build', attribute, '--no-link', '--print-build-logs'], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
Path('asset/pnpm-hash-probe.log').write_text(probe.stdout + probe.stderr)
assert probe.returncode != 0, 'empty fixed-output hash must produce a mismatch'
pattern = r"hash mismatch in fixed-output derivation '" + re.escape(derivation) + r"':\s*specified:\s*\S+\s*got:\s*(sha256-[A-Za-z0-9+/]+={0,2})"
hashes = re.findall(pattern, probe.stderr)
if len(hashes) != 1:
    raise RuntimeError('Expected one mismatch for ' + derivation + '\n' + probe.stderr)
recipe = Path('candidate/nix/concord.nix')
recipe.write_text(recipe.read_text().replace('hash = "";', f'hash = "{hashes[0]}";'))
subprocess.run(['nix', 'build', attribute, '--no-link', '--print-build-logs'], check=True)
subprocess.run(['ruby', '-c', 'candidate/Formula/concord.rb'], check=True)

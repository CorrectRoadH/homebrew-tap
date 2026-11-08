#!/usr/bin/env python3
"""Verify immutable Concord archives and generate channel candidates, never live recipes."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tempfile

REPOSITORY = 'CorrectRoadH/Concord'
TARGETS = ('linux-x64', 'darwin-arm64')
TAG = re.compile(r'(?:concord-)?v((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))')
MACH_O = {bytes.fromhex(value) for value in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def gh(*args):
    return subprocess.check_output(['gh', *args], text=True).strip()


def sha256(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def release_digest(release, name):
    matches = [asset for asset in release['assets'] if asset['name'] == name]
    require(len(matches) == 1, f'Expected exactly one Release asset: {name}')
    digest = matches[0].get('digest', '')
    require(re.fullmatch(r'sha256:[a-f0-9]{64}', digest or ''), f'Missing Release API SHA-256: {name}')
    return digest.removeprefix('sha256:')


def recipe_identity():
    formula = Path('Formula/concord.rb').read_text()
    nix = Path('nix/concord.nix').read_text()
    version = re.search(r'^\s*version "([^"]+)"', formula, re.M).group(1)
    require(re.search(r'^\s*version = "([^"]+)";', nix, re.M).group(1) == version,
            'Live Formula and Nix versions disagree')
    return version, formula, nix


def verify_archive(path, digest, version, target):
    require(sha256(path) == digest, f'Archive SHA-256 differs: {path.name}')
    with tarfile.open(path) as archive:
        names = set()
        native_hashes = {}
        for member in archive:
            name = PurePosixPath(member.name)
            require(not name.is_absolute() and '..' not in name.parts and str(name) not in names,
                    f'Unsafe or duplicate archive member: {member.name}')
            names.add(str(name))
            if member.isfile() or member.islnk():
                with archive.extractfile(member) as handle:
                    head = handle.read(4)
                    if head == b'\x7fELF' or head in MACH_O:
                        require((head == b'\x7fELF') == (target == 'linux-x64'), 'Wrong native file platform')
                        handle.seek(0)
                        native_hashes[str(name)] = hashlib.file_digest(handle, 'sha256').hexdigest()
        package = json.load(archive.extractfile('app/package.json'))
        require(package['version'] == version, f'Archive version differs from tag: {path.name}')
        require(re.fullmatch(r'[a-f0-9]{40}', package.get('gitHead', '')), 'Missing archive source commit')
        native_target = 'linux-x64-glibc' if target == 'linux-x64' else target
        directory = f'app/dist/native/{native_target}'
        metadata = json.load(archive.extractfile(f'{directory}/artifact.json'))
        require(metadata['target'] == native_target and metadata['portable'] is True and metadata['testHooks'] is False,
                'Expected a portable production HawDB binding')
        require(metadata['binarySha256'] == native_hashes[f'{directory}/hawdb.node'], 'HawDB binary identity differs')
        with archive.extractfile(f'{directory}/THIRD-PARTY-NOTICES.txt') as notices:
            require(metadata['noticesSha256'] == hashlib.file_digest(notices, 'sha256').hexdigest(), 'HawDB notices differ')
        require({'bin/concord', 'runtime/rg', f'{directory}/hawdb.node'} <= native_hashes.keys(), 'Missing native runtime')
        identity = [package['gitHead']] + [metadata[key] for key in ('abi', 'revision', 'sourceDigest', 'cargoLockDigest')]
        return native_hashes, identity


def generate(assets, digests, version, tag, output, local=False, commit=None):
    native = {}
    identities = []
    for target in TARGETS:
        name = f'concord-{version}-{target}.tar.gz'
        native[target], identity = verify_archive(assets / name, digests[target], version, target)
        identities.append(identity)
    require(identities[0] == identities[1], 'Platform archive source/native identities disagree')
    require(commit is None or identities[0][0] == commit, 'Archive source commit differs from tag')
    linux_name = f'concord-{version}-linux-x64.tar.gz'
    linux_url = f'https://github.com/{REPOSITORY}/releases/download/{tag}/{linux_name}'
    linux_source = ('fetchurl {\n'
                    f'      url = {json.dumps(linux_url)};\n'
                    f'      sha256 = "{digests["linux-x64"]}";\n'
                    '    }')
    if local:
        # Local validation has no publication outputs and is forbidden in Actions.
        linux_source = 'builtins.path { path = builtins.toPath ' + json.dumps(str((assets / linux_name).resolve())) + '; }'
    replacements = {
        'VERSION': version, 'TAG': tag, 'LINUX_SOURCE': linux_source,
        'LINUX_SHA256': digests['linux-x64'], 'DARWIN_SHA256': digests['darwin-arm64'],
        'LINUX_NATIVE_SHA256': json.dumps(native['linux-x64'], sort_keys=True, separators=(',', ':')),
        'DARWIN_NATIVE_SHA256': json.dumps(native['darwin-arm64'], sort_keys=True, separators=(',', ':')),
    }
    for template, destination in [('concord.rb.in', 'Formula/concord.rb'), ('concord.nix.in', 'nix/concord.nix')]:
        text = (Path('templates') / template).read_text()
        for key, value in replacements.items():
            text = text.replace('@' + key + '@', value)
        require(not re.search(r'@[A-Z_]+@', text), 'Unresolved template placeholder')
        path = output / destination
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    for name in ('flake.nix', 'flake.lock'):
        (output / name).write_bytes(Path(name).read_bytes())


def prepare(tag, output):
    if not tag:
        tag = gh('release', 'view', '--repo', REPOSITORY, '--json', 'tagName', '--jq', '.tagName')
    match = TAG.fullmatch(tag)
    require(match, f'Invalid canonical Concord tag: {tag}')
    version = match[1]
    current, formula, nix = recipe_identity()
    require(tuple(map(int, version.split('.'))) >= tuple(map(int, current.split('.'))),
            f'Refusing version rollback from {current} to {version}')
    release = json.loads(gh('api', f'repos/{REPOSITORY}/releases/tags/{tag}'))
    require(release['tag_name'] == tag and not release['draft'] and not release['prerelease'], 'Expected a public stable release')
    legacy_name = f'concord-sdlc-{version}.tgz'
    legacy = any(asset['name'] == legacy_name for asset in release['assets'])
    if legacy:
        require(current == version, 'Old-format releases can only verify the already installed version')
        digests = dict.fromkeys(TARGETS, release_digest(release, legacy_name))
    else:
        digests = {target: release_digest(release, f'concord-{version}-{target}.tar.gz') for target in TARGETS}
    result = {'version': version, 'tag': tag, 'sha256': digests['linux-x64'],
              'darwin_sha256': digests['darwin-arm64'], 'changed': 'false',
              'base_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()}
    if current == version:
        formula_hashes = re.findall(r'^\s*sha256 "([a-f0-9]{64})"', formula, re.M)
        expected = [digests['linux-x64']] if legacy else [digests['darwin-arm64'], digests['linux-x64']]
        require(formula_hashes == expected, 'Already installed Formula has different asset digests')
        require(re.findall(r'^\s*sha256 = "([a-f0-9]{64})";', nix, re.M) == [digests['linux-x64']],
                'Already installed Nix recipe has a different asset digest')
        require(f'/download/{tag}/' in formula and f'/download/{tag}/' in nix, 'Recipe tag identity differs')
        subprocess.run(['git', 'ls-remote', '--exit-code', '--tags', 'origin', f'refs/tags/{tag}'], check=True, stdout=subprocess.DEVNULL)
        return result
    commit = gh('api', f'repos/{REPOSITORY}/commits/{tag}', '--jq', '.sha')
    with tempfile.TemporaryDirectory(prefix='concord-tap-assets-') as directory:
        assets = Path(directory)
        for target in TARGETS:
            gh('release', 'download', tag, '--repo', REPOSITORY, '--pattern', f'concord-{version}-{target}.tar.gz', '--dir', directory)
        generate(assets, digests, version, tag, output, commit=commit)
    result['changed'] = 'true'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', default=os.environ.get('REQUESTED_TAG', ''))
    parser.add_argument('--output', type=Path, default=Path('candidate'))
    parser.add_argument('--local-assets', type=Path, help='Validate downloaded development artifacts locally; never publish')
    args = parser.parse_args()
    if args.local_assets:
        require(os.environ.get('GITHUB_ACTIONS') != 'true', 'Local asset mode is forbidden in CI publication')
        require(not args.tag, 'Local assets do not assert a release tag')
        names = list(args.local_assets.glob('concord-*-linux-x64.tar.gz'))
        require(len(names) == 1, 'Expected exactly one local Linux archive')
        version = names[0].name.removeprefix('concord-').removesuffix('-linux-x64.tar.gz')
        require(re.fullmatch(r'[a-zA-Z0-9.+-]+', version), 'Invalid local candidate version')
        sums = {}
        for line in (args.local_assets / 'SHA256SUMS').read_text().splitlines():
            digest, name = line.split('  ', 1)
            require(re.fullmatch(r'[a-f0-9]{64}', digest) and name not in sums, 'Invalid or duplicate local checksum')
            sums[name] = digest
        digests = {target: sums[f'concord-{version}-{target}.tar.gz'] for target in TARGETS}
        generate(args.local_assets, digests, version, 'LOCAL-VALIDATION', args.output, local=True)
        print(f'Generated local-only {version} candidates in {args.output}')
    else:
        result = prepare(args.tag, args.output)
        print(json.dumps(result, sort_keys=True))
        if os.environ.get('GITHUB_OUTPUT'):
            with open(os.environ['GITHUB_OUTPUT'], 'a') as handle:
                handle.writelines(f'{key}={value}\n' for key, value in result.items())


if __name__ == '__main__':
    main()

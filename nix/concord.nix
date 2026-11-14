{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, python3, glibc, git, runCommand }:
let
  concord = stdenv.mkDerivation {
    pname = "concord";
    version = "0.16.10";
    src = fetchurl {
      url = "https://github.com/CorrectRoadH/Concord/releases/download/v0.16.10/concord-0.16.10-linux-x64.tar.gz";
      sha256 = "a7abf0ebe8c9e4029185af057c9ea9175cf3a26f23b7fac3b02504248a2b16f7";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ autoPatchelfHook makeWrapper python3 ];
    # GCC's lib output includes libstdc++, libgcc_s and libatomic, pinned by flake.lock.
    buildInputs = [ glibc stdenv.cc.cc.lib ];
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;
    dontPatchShebangs = true;
    dontAutoPatchelf = true;
    autoPatchelfFlags = [ "--ignore-existing" ];
    installPhase = ''
      runHook preInstall
      python3 - <<'PY'
      import hashlib, json
      from pathlib import Path
      root = Path('app/dist/native/linux-x64-glibc')
      metadata = json.loads((root / 'artifact.json').read_text())
      assert metadata['target'] == 'linux-x64-glibc' and metadata['portable'] and not metadata['testHooks']
      assert metadata['binarySha256'] == hashlib.sha256((root / 'hawdb.node').read_bytes()).hexdigest()
      assert metadata['noticesSha256'] == hashlib.sha256((root / 'THIRD-PARTY-NOTICES.txt').read_bytes()).hexdigest()
      assert json.loads(Path('app/package.json').read_text())['version'] == '0.16.10'
      PY
      mkdir -p "$out/libexec/concord" "$out/bin"
      cp -a bin runtime app licenses "$out/libexec/concord/"
      makeWrapper "$out/libexec/concord/bin/concord" "$out/bin/concord" \
        --prefix PATH : ${lib.makeBinPath [ git ]}
      runHook postInstall
    '';
    postFixup = ''
      root="$out/libexec/concord"
      # Never pass Bun's executable through RPATH rewriting. The bundled
      # esbuild and TypeScript executables are static and need no patching.
      test -z "$(patchelf --print-rpath "$root/bin/concord")"
      patchelf --set-interpreter "${glibc}/lib/ld-linux-x86-64.so.2" "$root/bin/concord"
      test -z "$(patchelf --print-rpath "$root/bin/concord")"
      autoPatchelf "$root/app/dist/native" "$root/runtime"
      python3 - "$root" <<'PY'
      import hashlib, json, sys
      from pathlib import Path
      relative = Path('app/dist/native/linux-x64-glibc')
      original = json.loads((relative / 'artifact.json').read_text())
      native = Path(sys.argv[1]) / relative
      metadata = json.loads((native / 'artifact.json').read_text())
      assert metadata == original
      metadata['binarySha256'] = hashlib.sha256((native / 'hawdb.node').read_bytes()).hexdigest()
      (native / 'artifact.json').write_text(json.dumps(metadata, sort_keys=True) + '\n')
      assert {k: v for k, v in metadata.items() if k != 'binarySha256'} == {k: v for k, v in original.items() if k != 'binarySha256'}
      PY
      "$out/bin/concord" --version
    '';
    passthru.tests.lifecycle = runCommand "concord-lifecycle" {
      nativeBuildInputs = [ concord git python3 ];
    } ''
      export XDG_CACHE_HOME="$TMPDIR/cache" XDG_CONFIG_HOME="$TMPDIR/config" XDG_DATA_HOME="$TMPDIR/data"
      mkdir consumer
      cd consumer
      test "$(concord --version)" = "concord v0.16.10"
      git init --quiet
      concord init --docs-only
      concord check
      concord cache clear
      concord test list --json > cold.json
      concord test list --json > warm.json
      python3 - <<'PY'
      import json
      from pathlib import Path
      assert json.loads(Path('cold.json').read_text())['cache']['status'] == 'miss'
      assert json.loads(Path('warm.json').read_text())['cache']['status'] == 'hit'
      PY
      touch "$out"
    '';
    meta = {
      description = "Contracts, test evidence, and engineering memory CLI";
      homepage = "https://github.com/CorrectRoadH/homebrew-tap";
      mainProgram = "concord";
      platforms = [ "x86_64-linux" ];
    };
  };
in concord

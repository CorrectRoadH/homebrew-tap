{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, python3, glibc, git }:
let
  concord = stdenv.mkDerivation {
    pname = "concord";
    version = "0.17.8";
    src = fetchurl {
      url = "https://github.com/CorrectRoadH/Concord/releases/download/v0.17.8/concord-0.17.8-linux-x64.tar.gz";
      sha256 = "b3730aef456ca5da611f25d4b569db32085d655c5c0abf7d69b32e503bfb1180";
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
      assert metadata['format'] == 'concord.native-artifact/v2' and metadata['target'] == 'linux-x64-glibc'
      assert metadata['upstreamManifestSha256'] == hashlib.sha256((root / 'manifest.json').read_bytes()).hexdigest()
      assert metadata['binarySha256'] == hashlib.sha256((root / 'lib/libhawdb_ffi.so').read_bytes()).hexdigest()
      assert json.loads(Path('app/package.json').read_text())['version'] == '0.17.8'
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
      metadata['binarySha256'] = hashlib.sha256((native / 'lib/libhawdb_ffi.so').read_bytes()).hexdigest()
      (native / 'artifact.json').write_text(json.dumps(metadata, sort_keys=True) + '\n')
      assert {k: v for k, v in metadata.items() if k != 'binarySha256'} == {k: v for k, v in original.items() if k != 'binarySha256'}
      PY
      "$out/bin/concord" --version
    '';
    meta = {
      description = "Contracts, test evidence, and engineering memory CLI";
      homepage = "https://github.com/CorrectRoadH/homebrew-tap";
      mainProgram = "concord";
      platforms = [ "x86_64-linux" ];
    };
  };
in concord

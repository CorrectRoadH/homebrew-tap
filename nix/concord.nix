{ lib, stdenv, fetchurl, nodejs_24, pnpm_11, fetchPnpmDeps, pnpmConfigHook, makeWrapper, runCommand, git, ripgrep }:
let
  concord = stdenv.mkDerivation (finalAttrs: {
    pname = "concord";
    version = "0.11.4";
    src = fetchurl {
      url = "https://github.com/CorrectRoadH/Concord/releases/download/v0.11.4/concord-sdlc-0.11.4.tgz";
      sha256 = "e61770679e3eb7be4d3d6764f9dad3ea1327e97b4415a08e0b248ea729cdd9e7";
    };
    sourceRoot = "package";
    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src sourceRoot pnpmInstallFlags;
      pnpm = pnpm_11;
      fetcherVersion = 4;
      hash = "sha256-U7/wUJYGidl751ruPlbKKLCwLh5Ot8z9LJs0e5/Iv5I=";
    };
    # pnpmConfigHook 已固定传入 --ignore-scripts；只保留生产标志，避免 stdenv 将多个选项合为单个参数。
    pnpmInstallFlags = [ "--prod" ];
    nativeBuildInputs = [ nodejs_24 pnpm_11 pnpmConfigHook makeWrapper ];
    dontBuild = true;
    dontStrip = true;
    dontPatchShebangs = true;
    preConfigure = ''
      mkdir ../identity
      cp package.json pnpm-lock.yaml pnpm-workspace.yaml ../identity/
    '';
    installPhase = ''
      runHook preInstall
      for name in package.json pnpm-lock.yaml pnpm-workspace.yaml; do
        cmp "$name" "../identity/$name"
      done
      mkdir -p "$out/lib/concord" "$out/bin"
      cp -a . "$out/lib/concord/"
      makeWrapper ${nodejs_24}/bin/node "$out/bin/concord" \
        --add-flags "$out/lib/concord/dist/entry.js" \
        --prefix PATH : ${lib.makeBinPath [ nodejs_24 git ripgrep ]}
      diff -r dist "$out/lib/concord/dist"
      runHook postInstall
    '';
    passthru.tests.lifecycle = runCommand "concord-lifecycle" {
      nativeBuildInputs = [ concord git ];
    } ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME" consumer
      cd consumer
      git init --quiet
      concord init --docs-only
      concord check
      concord cache clear
      concord test list --json > cold.json
      concord test list --json > warm.json
      ${nodejs_24}/bin/node -e 'const fs=require("fs"),assert=require("assert");assert.equal(JSON.parse(fs.readFileSync("cold.json")).cache.status,"miss");assert.equal(JSON.parse(fs.readFileSync("warm.json")).cache.status,"hit")'
      touch "$out"
    '';
    meta = {
      description = "Contracts, test evidence, and engineering memory CLI";
      homepage = "https://github.com/CorrectRoadH/homebrew-tap";
      mainProgram = "concord";
      platforms = [ "x86_64-linux" ];
    };
  });
in concord

{ lib, buildNpmPackage, fetchurl, nodejs_24, makeWrapper, runCommand, git, ripgrep }:
let
  concord = buildNpmPackage {
    pname = "concord";
    version = "0.2.1";
    src = fetchurl {
      url = "https://github.com/CorrectRoadH/homebrew-tap/releases/download/concord-v0.2.1/concord-sdlc-0.2.1.tgz";
      sha256 = "94d5ec0767773759b9fddfc2b7d3ecc46f5d3f6df86036af5f401b7dc3c71c06";
    };
    sourceRoot = "package";
    nodejs = nodejs_24;
    npmDepsHash = "sha256-tvv5imG64aHSg9sdENfqoVWhoFDCf56b88DUx36827M=";
    dontNpmBuild = true;
    postPatch = ''
      cp npm-shrinkwrap.json npm-shrinkwrap.upstream
    '';
    # Nix rewrites dependency URLs for its offline cache during npm ci.
    # Restore the published identity after dependency installation.
    preInstall = ''
      cp npm-shrinkwrap.upstream npm-shrinkwrap.json
    '';
    npmFlags = [ "--ignore-scripts" ];
    npmInstallFlags = [ "--ignore-scripts" ];
    # Repository identity hashes original JS, package metadata and shrinkwrap.
    # Only the external launcher may contain Nix-specific paths.
    dontPatchShebangs = true;
    nativeBuildInputs = [ makeWrapper ];
    postInstall = ''
      rm "$out/bin/concord"
      makeWrapper ${nodejs_24}/bin/node "$out/bin/concord" \
        --add-flags "$out/lib/node_modules/concord-sdlc/dist/entry.js" \
        --prefix PATH : ${lib.makeBinPath [ nodejs_24 git ripgrep ]}
      cmp package.json "$out/lib/node_modules/concord-sdlc/package.json"
      cmp npm-shrinkwrap.json "$out/lib/node_modules/concord-sdlc/npm-shrinkwrap.json"
      diff -r dist/repository "$out/lib/node_modules/concord-sdlc/dist/repository"
    '';
    passthru.tests.lifecycle = runCommand "concord-lifecycle" {
      nativeBuildInputs = [ concord git ];
    } ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME" consumer
      cd consumer
      git init --quiet
      concord init
      concord check
      concord cache rebuild
      concord check
      touch "$out"
    '';
    meta = {
      description = "Contracts, test evidence, and engineering memory CLI";
      homepage = "https://github.com/CorrectRoadH/homebrew-tap";
      mainProgram = "concord";
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  };
in concord

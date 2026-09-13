# CorrectRoadH Homebrew Tap

```sh
brew install CorrectRoadH/tap/harness-lint
```

## Concord

`concord` is a Linux-only local SDLC CLI for contracts, tests, and engineering memory. The formula installs Node.js and the pinned release package.

```sh
brew install CorrectRoadH/tap/concord
concord --help
```

In a new Git repository, run `concord init` and `concord check`.
Existing NiceEval repositories keep their locked `pnpm run repo` and `pnpm memory`
commands through the Concord repository profile. A different global version is
rejected; use the repository's pnpm entry to select its exact engine.

Release packages are attached to this public tap repository and verified by the
formula's SHA-256. CI installs the formula and tests initialization and validation
in a temporary Git repository.

## Nix / NixOS

The same Concord release is available as a public flake for `x86_64-linux` and
`aarch64-linux`; no access to the private source repository is required.

```sh
# Run without installing
nix run github:CorrectRoadH/homebrew-tap#concord -- --help

# Install in your user profile
nix profile install github:CorrectRoadH/homebrew-tap#concord
concord --version
```

For a NixOS flake, add the input and select the package for the host system:

```nix
inputs.concord.url = "github:CorrectRoadH/homebrew-tap";

# In the configuration module, with the input passed through specialArgs:
{ pkgs, concord, ... }: {
  environment.systemPackages = [
    concord.packages.${pkgs.stdenv.hostPlatform.system}.concord
  ];
}
```

The flake locks Nixpkgs, the published tarball and the npm dependency cache.
It supplies Node.js and Git, preserves the published repository engine identity,
and checks initialization and SQLite cache rebuilding. Project-specific tools
such as pnpm remain owned by the consumer environment.

Release maintenance: update `nix/concord.nix` alongside `Formula/concord.rb`,
calculate the new `npmDepsHash`, then run `nix flake check` and the installation
workflow. Keep `package.json`, `npm-shrinkwrap.json` and repository JS bytes
identical to the release; Nix-specific paths belong in the launcher only.

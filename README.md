# CorrectRoadH Homebrew Tap

```sh
brew install CorrectRoadH/tap/harness-lint
```

## Concord

`concord` is a local SDLC CLI for contracts, tests, and engineering memory. Starting with 0.8.2, macOS requires Apple Silicon and macOS 15 or newer. Candidate recipes must pass Homebrew installation on Linux x64 and macOS arm64, and Nix installation on Linux x64 before publication. macOS 27 is allowed but is not verified in CI. It installs Node.js, Git, ripgrep, and the pinned release package. Use a macOS version with [Homebrew bottle support](https://docs.brew.sh/Support-Tiers).

```sh
brew install CorrectRoadH/tap/concord
concord --help
```

In a new Git repository, run `concord init` and `concord check`.
Existing NiceEval repositories keep their locked `pnpm run repo` and `pnpm memory`
commands through the Concord repository profile. A different global version is
rejected; use the repository's pnpm entry to select its exact engine.

Release packages are owned by the public [Concord repository](https://github.com/CorrectRoadH/Concord/releases) and verified by the formula's SHA-256. The tap automatically discovers releases, verifies package identity and SHA-256, generates candidates from the versioned templates, validates frozen pnpm installation and cache operation, then commits and tags the recipe mapping. All channels reference the same published package. A matching tap GitHub Release records channel completion. Source publication alone does not mean the channels are ready.

The sync checks for a release every five minutes and accepts `vX.X.X` and `concord-vX.X.X` source tags. Matching versions and digests skip package downloads, Nix setup and platform tasks. After both channel checks pass, it pushes the recipe commit and matching tag together. An interrupted completion receipt is repaired on the next run. To enable immediate notification, configure `HOMEBREW_TAP_WORKFLOW_TOKEN` in the Concord repository with a fine-grained token limited to `CorrectRoadH/homebrew-tap` and Actions write permission. Scheduled discovery requires no cross-repository credential, but GitHub may delay scheduled runs. No LLM, additional tag or manual recipe edit is needed for normal synchronization.

Failed jobs receive one automatic failed-job retry, reusing successful preparation. Later scheduled discovery can recover unfinished synchronization. When version and digest already match, discovery skips the package download and Nix dependency hashing and only repairs a missing channel receipt. Each job has a bounded timeout.

## Nix / NixOS

The same Concord release is available as a public flake for `x86_64-linux`; no access to the private source repository is required.

```sh
# Run without installing
nix run 'git+https://github.com/CorrectRoadH/homebrew-tap?ref=main#concord' -- --help

# Install in your user profile
nix profile install 'git+https://github.com/CorrectRoadH/homebrew-tap?ref=main#concord'
concord --version
```

For a NixOS flake, add the input and select the package for the host system:

```nix
inputs.concord.url = "git+https://github.com/CorrectRoadH/homebrew-tap?ref=main";

# In the configuration module, with the input passed through specialArgs:
{ pkgs, concord, ... }: {
  environment.systemPackages = [
    concord.packages.${pkgs.stdenv.hostPlatform.system}.concord
  ];
}
```

The flake locks Nixpkgs, the published tarball and the pnpm dependency store.
It supplies Node.js and Git, preserves the published repository engine identity,
and checks initialization and HawDB cache misses and hits. Project-specific tools
such as pnpm remain owned by the consumer environment.

Nix remains Linux-only. Release synchronization updates `nix/concord.nix` alongside `Formula/concord.rb`, calculates the new `pnpmDeps` fixed-output hash, and validates it on Ubuntu 24.04. Keep `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml` and repository JS bytes identical to the source release; Nix-specific paths belong in the launcher only.

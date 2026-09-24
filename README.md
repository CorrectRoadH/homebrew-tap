# CorrectRoadH Homebrew Tap

```sh
brew install CorrectRoadH/tap/harness-lint
```

## Concord

`concord` is a local SDLC CLI for contracts, tests, and engineering memory. The formula supports Linux x86_64/aarch64 and Apple Silicon macOS 14/15 on local APFS. It installs Node.js, Git, ripgrep, and the pinned release package.

```sh
brew install CorrectRoadH/tap/concord
concord --help
```

In a new Git repository, run `concord init` and `concord check`.
Existing NiceEval repositories keep their locked `pnpm run repo` and `pnpm memory`
commands through the Concord repository profile. A different global version is
rejected; use the repository's pnpm entry to select its exact engine.

Release packages are owned by the public [Concord repository](https://github.com/CorrectRoadH/Concord/releases) and verified by the formula's SHA-256. After publishing, Concord can trigger this tap's `Concord release sync` workflow with the source tag. The tap independently verifies the public asset and its version, prepares Formula and Linux Nix metadata, validates both recipes on Ubuntu 24.04, and only then commits and tags the recipe mapping. Scheduled discovery remains a fallback; maintainers can also run the sync manually for a published tag.

The sync checks for a release every five minutes and accepts `vX.X.X` and `concord-vX.X.X` source tags. After both channel checks pass, it pushes the recipe commit and matching tag together. To enable immediate notification, configure `HOMEBREW_TAP_WORKFLOW_TOKEN` in the Concord repository with a fine-grained token limited to `CorrectRoadH/homebrew-tap` and Actions write permission. The token only starts this tap's existing workflow; a successful notification is not a successful recipe validation. GitHub may delay scheduled runs; no additional tag or manual recipe edit is required.

## Nix / NixOS

The same Concord release is available as a public flake for `x86_64-linux` and
`aarch64-linux`; no access to the private source repository is required.

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

The flake locks Nixpkgs, the published tarball and the npm dependency cache.
It supplies Node.js and Git, preserves the published repository engine identity,
and checks initialization and SQLite cache rebuilding. Project-specific tools
such as pnpm remain owned by the consumer environment.

Nix remains Linux-only. Release synchronization updates `nix/concord.nix` alongside `Formula/concord.rb`, calculates the new `npmDepsHash`, and validates it on Ubuntu 24.04. Keep `package.json`, `npm-shrinkwrap.json` and repository JS bytes identical to the source release; Nix-specific paths belong in the launcher only.

# CorrectRoadH Homebrew Tap

```sh
brew install CorrectRoadH/tap/harness-lint
```

## Concord

`concord` is a local SDLC CLI for contracts, tests, and engineering memory. macOS requires Apple Silicon and macOS 15 or newer. It installs Git and the platform release archive, which carries the Bun-compiled `concord` executable, ripgrep, the official HawDB C ABI library and its own TypeScript and esbuild; no Node.js, Bun or pnpm is needed. Use a macOS version with [Homebrew bottle support](https://docs.brew.sh/Support-Tiers).

```sh
brew install CorrectRoadH/tap/concord
concord --help
```

In a new Git repository, run `concord init` and `concord check`.
Existing NiceEval repositories keep their locked `pnpm run repo` and `pnpm memory`
commands through the Concord repository profile. A different global version is
rejected; use the repository's pnpm entry to select its exact engine.

Release packages are owned by the public [Concord repository](https://github.com/CorrectRoadH/Concord/releases) and verified by the formula's SHA-256. The tap automatically discovers releases, verifies package identity and SHA-256, generates recipes from the templates, then commits and tags the recipe mapping. It does not rerun Homebrew or Nix installation tests. All channels reference the same published package. A matching tap GitHub Release records channel synchronization.

Concord bundles the official HawDB C ABI release pin, upstream manifest and artifact receipt. Nix relocation updates only the receipt's binary digest, preserving the upstream manifest and pin.

The sync checks for a release every five minutes and accepts `vX.X.X` and `concord-vX.X.X` source tags. Matching versions and digests skip package downloads. It pushes the recipe commit and matching tag together after generation. An interrupted completion receipt is repaired on the next run. To enable immediate notification, configure `HOMEBREW_TAP_WORKFLOW_TOKEN` in the Concord repository with a fine-grained token limited to `CorrectRoadH/homebrew-tap` and Actions write permission. Scheduled discovery requires no cross-repository credential, but GitHub may delay scheduled runs. No LLM, additional tag or manual recipe edit is needed for normal synchronization.

Failed jobs receive one automatic failed-job retry, reusing successful preparation. Later scheduled discovery can recover unfinished synchronization. When version and digest already match, discovery only repairs a missing channel receipt. Each job has a bounded timeout.

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

The flake locks Nixpkgs and the published Linux x64 archive. It supplies Git,
points the compiled `concord` executable at Nixpkgs' glibc loader without adding
an RPATH, patches the HawDB engine and bundled runtime libraries against Nixpkgs,
and records the patched engine digest as the Nix installation identity. Project-specific tools such
as pnpm remain owned by the consumer environment.

Nix remains Linux-only. Release synchronization updates `nix/concord.nix` alongside `Formula/concord.rb`. Only ELF loader and library paths change; application bytes stay identical to the source release.

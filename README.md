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

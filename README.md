# coq-flake

Nix dev environment for Coq/Rocq (with coq-lsp). Apps: `typecheck` (`make` if a Makefile exists, else `coq_makefile` from `_CoqProject`, else per-file `coqc`) and `doc` (`make html` if available, else coqdoc into `doc/`).

## Use

```sh
# .envrc — follow HEAD (picks up updates automatically)
use flake "github:MaxCarroll0/coq-flake"

# or pin an exact commit for reproducibility, bumping deliberately
use flake "github:MaxCarroll0/coq-flake?rev=<sha>"
```

## Commands

```sh
nix run 'github:MaxCarroll0/coq-flake#typecheck'
nix run 'github:MaxCarroll0/coq-flake#doc'
```

Emacs: Proof General + company-coq work off the direnv PATH; `coq-lsp` is included for eglot if preferred.

## Ground-up builds

Build hermetically from scratch with `nix build` (typecheck + document outputs as a derivation; no devshell involved). From the project root:

```sh
nix build --impure --expr \
  '(builtins.getFlake "github:MaxCarroll0/coq-flake").lib.${builtins.currentSystem}.mkBuild { src = ./.; }'
```

The result contains `typecheck.log`, a `status` file (`PASS`/`FAIL`), and generated artifacts where applicable. The build itself succeeds either way so the log is always inspectable; pass `strict = true;` to fail the build on a typecheck error. Planned: a generated index of postulates, holes, and incomplete proofs alongside the log.

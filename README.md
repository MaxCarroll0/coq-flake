# coq-flake

Nix dev environment for Coq/Rocq (with coq-lsp). Apps: `typecheck` (`make` if a Makefile exists, else `coq_makefile` from `_CoqProject`, else per-file `coqc`) and `doc` (`make html` if available, else coqdoc into `doc/`).

## Use

```sh
# .envrc — pin an exact commit; bump deliberately, one update at a time
use flake "github:MaxCarroll0/coq-flake?rev=<sha>"
```

## Commands

```sh
nix run 'github:MaxCarroll0/coq-flake?rev=<sha>#typecheck'
nix run 'github:MaxCarroll0/coq-flake?rev=<sha>#doc'
```

Emacs: Proof General + company-coq work off the direnv PATH; `coq-lsp` is included for eglot if preferred.

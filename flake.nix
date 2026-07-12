{
  description = "Coq/Rocq dev environment: typecheck via make or coqc, coqdoc output, coq-lsp";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: f system (import nixpkgs { inherit system; })
        );
    in
    {
      packages = eachSystem (
        system: pkgs:
        let
          coq = pkgs.coq;
          stdlib = pkgs.coqPackages.stdlib;
          stdlibEnv = ''
            export COQPATH="${stdlib}/lib/coq/${coq.coq-version}/user-contrib''${COQPATH:+:$COQPATH}"
            export ROCQPATH="$COQPATH"
          '';
        in
        {
          inherit coq stdlib;
          coq-lsp = pkgs.coqPackages.coq-lsp;

          fmt = pkgs.writeShellApplication {
            name = "fmt-coq";
            text = ''
              if (( $# )); then files=("$@"); else mapfile -t files < <(git ls-files 2>/dev/null); fi
              for f in "''${files[@]}"; do
                [[ -f "$f" && "$f" =~ \.v$ ]] || continue
                sed -i 's/[ \t]*$//' "$f"
                if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then echo >> "$f"; fi
              done
            '';
          };

          pre-commit-hook = pkgs.writeShellScript "fmt-pre-commit" ''
            set -euo pipefail
            mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACM)
            (( ''${#staged[@]} )) || exit 0
            for fmt in fmt-lean fmt-agda fmt-isabelle fmt-fstar fmt-coq fmt-org fmt-ocaml; do
              command -v "$fmt" >/dev/null 2>&1 || continue
              "$fmt" "''${staged[@]}"
            done
            git add -- "''${staged[@]}"
          '';

          typecheck = pkgs.writeShellApplication {
            name = "typecheck-coq";
            runtimeInputs = [
              coq
              pkgs.gnumake
            ];
            text = ''
              ${stdlibEnv}
              if [[ -f Makefile ]]; then
                if make; then echo "PASS  Coq (make)"; else echo "FAIL  Coq (make)"; exit 1; fi
              elif [[ -f _CoqProject ]]; then
                coq_makefile -f _CoqProject -o Makefile.coq
                if make -f Makefile.coq; then echo "PASS  Coq (Makefile.coq)"; else echo "FAIL  Coq (Makefile.coq)"; exit 1; fi
              else
                fail=0
                found=0
                while IFS= read -r f; do
                  found=1
                  echo "-- coqc $f"
                  coqc "$f" || fail=1
                done < <(find . \( -name .git -o -name .direnv \) -prune -o -type f -name '*.v' -print | sort)
                if (( ! found )); then
                  echo "typecheck-coq: no Makefile, _CoqProject, or .v files in $PWD" >&2
                  exit 1
                fi
                if (( fail )); then echo "FAIL  Coq"; exit 1; else echo "PASS  Coq"; fi
              fi
            '';
          };

          doc = pkgs.writeShellApplication {
            name = "doc-coq";
            runtimeInputs = [
              coq
              pkgs.gnumake
              pkgs.texliveMedium
            ];
            text = ''
              ${stdlibEnv}
              if [[ -f Makefile ]] && grep -qE '^html:' Makefile; then
                make html
              else
                mkdir -p doc
                mapfile -t vs < <(find . \( -name .git -o -name .direnv -o -name doc \) -prune -o -type f -name '*.v' -print | sort)
                if (( ''${#vs[@]} == 0 )); then
                  echo "doc-coq: no .v files in $PWD" >&2
                  exit 1
                fi
                coqdoc --html -d doc "''${vs[@]}"
              fi
            '';
          };
        }
      );

      lib = eachSystem (
        system: pkgs: {
          mkBuild =
            {
              src,
              name ? "coq-build",
              strict ? false,
            }:
            pkgs.stdenv.mkDerivation {
              inherit name;
              src = nixpkgs.lib.cleanSourceWith {
                inherit src;
                filter =
                  path: _type:
                  !(builtins.elem (baseNameOf path) [
                    ".git"
                    ".direnv"
                    "doc"
                  ]);
              };
              buildPhase = ''
                export HOME="$TMPDIR"
                mkdir -p "$out"
                set +e
                ${self.packages.${system}.typecheck}/bin/typecheck-coq > "$out/typecheck.log" 2>&1
                status=$?
                set -e
                if [ "$status" -eq 0 ]; then echo PASS > "$out/status"; else echo "FAIL ($status)" > "$out/status"; fi
                tail -n 20 "$out/typecheck.log"
                ${if strict then ''[ "$status" -eq 0 ] || exit "$status"'' else ""}
              '';
              installPhase = "true";
            };
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.coq
              self.packages.${system}.stdlib
              self.packages.${system}.coq-lsp
              pkgs.gnumake
              self.packages.${system}.typecheck
              self.packages.${system}.doc
              self.packages.${system}.fmt
            ];
            shellHook = ''
              if [ -d .git ] && [ ! -e .git/hooks/pre-commit ]; then
                install -m 755 ${self.packages.${system}.pre-commit-hook} .git/hooks/pre-commit
                echo "fmt pre-commit hook installed"
              fi
            '';
          };
        }
      );

      apps = eachSystem (
        system: pkgs: {
          typecheck = {
            type = "app";
            program = "${self.packages.${system}.typecheck}/bin/typecheck-coq";
          };
          doc = {
            type = "app";
            program = "${self.packages.${system}.doc}/bin/doc-coq";
          };
          fmt = {
            type = "app";
            program = "${self.packages.${system}.fmt}/bin/fmt-coq";
          };
        }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-rfc-style);
    };
}

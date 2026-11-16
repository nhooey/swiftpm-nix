{
  description = "SwiftPM dependencies for Nix builds, fetched from the package's own Package.resolved";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Brings numtide/devshell and the wiring that installs the dev shell's
    # skills from the `skills-devshell/` sub-flake, invoked at runtime, so
    # this flake carries no skill inputs.
    agent-skill-flake = {
      url = "github:nhooey/agent-skill-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        # Explicit, not nix-systems/default, to leave out x86_64-darwin,
        # which nixpkgs-unstable doesn't build.
        systems = [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];

        imports = [
          inputs.agent-skill-flake.flakeModules.devshellSkills
          inputs.treefmt-nix.flakeModule
        ];

        agent-skill-flake.devshellSkills = {
          name = "swiftpm-nix";
          # This dev shell keeps its own `fmt` and has `nix flake check`.
          includeStandardCommands = false;
        };

        flake.lib = import ./lib { inherit (nixpkgs) lib; };

        perSystem =
          { pkgs, lib, ... }:
          let
            # The test package's dependencies, which both the setup-hook and
            # composable-architecture checks use.
            tcaDeps = config.flake.lib.fetchDeps pkgs {
              resolved = ./tests/composable-architecture/Package.resolved;
            };
          in
          {
            checks = {
              # lib/pins.nix's unit tests, evaluated here; the build only
              # reports them, and fails if any differs from what it expects.
              unit =
                let
                  failures = import ./tests/unit { inherit lib; };
                in
                pkgs.runCommand "swiftpm-nix-unit" { } (
                  if failures == [ ] then
                    "touch $out"
                  else
                    ''
                      echo ${lib.escapeShellArg (builtins.toJSON failures)} >&2
                      exit 1
                    ''
                );

              # The hook's layout, checked with no Swift build, on every system.
              setup-hook = pkgs.callPackage ./tests/setup-hook { swiftpmDeps = tcaDeps; };

              # tools/check.py's argument parsing and the nix commands it builds.
              tools =
                pkgs.runCommand "swiftpm-nix-tools"
                  {
                    nativeBuildInputs = [ pkgs.python3 ];
                    src = lib.fileset.toSource {
                      root = ./.;
                      fileset = lib.fileset.unions [
                        ./tools
                        ./tests/tools
                      ];
                    };
                  }
                  ''
                    python3 -I "$src/tests/tools/test_check.py"
                    touch "$out"
                  '';
            }
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
              # The Composable Architecture as the test: 14 packages, swift-syntax
              # macros among them, built with only the dependencies from fetchDeps.
              composable-architecture = pkgs.callPackage ./tests/composable-architecture {
                swiftpmDeps = tcaDeps;
              };
            };

            # `nix fmt` runs treefmt; its `treefmt` check verifies the tree.
            treefmt = {
              projectRootFile = "flake.nix";
              programs.nixfmt.enable = true;
              programs.ruff-format.enable = true;
            };

            devshells.default = {
              name = "swiftpm-nix";
              packages = [
                pkgs.swift
                pkgs.swiftpm
              ];
              commands = [
                {
                  category = "check";
                  name = "check";
                  help = "list, build or run the flake's checks (check --help)";
                  command = ''${lib.getExe pkgs.python3} ${./tools/check.py} "$@"'';
                }
                {
                  category = "format";
                  name = "fmt";
                  help = "format every Nix and Python file with treefmt";
                  command = ''nix fmt "$@"'';
                }
              ];
            };
          };
      }
    );
}

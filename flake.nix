{
  description = "SwiftPM dependencies for Nix builds, fetched from the package's own Package.resolved";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
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
        # Explicit, not nix-systems/default: nixpkgs-unstable no longer
        # builds x86_64-darwin.
        systems = [
          "aarch64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];

        imports = [
          inputs.devshell.flakeModule
          inputs.treefmt-nix.flakeModule
        ];

        flake.lib = import ./lib { inherit (nixpkgs) lib; };

        perSystem =
          { pkgs, lib, ... }:
          {
            # The Composable Architecture as the test: 14 packages, swift-syntax
            # macros among them, built with the network cut off.
            checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
              composable-architecture = pkgs.callPackage ./tests/composable-architecture {
                swiftpmDeps = config.flake.lib.fetchDeps pkgs {
                  resolved = ./tests/composable-architecture/Package.resolved;
                };
              };
            };

            # `nix fmt` runs treefmt; its `treefmt` check verifies the tree.
            treefmt = {
              projectRootFile = "flake.nix";
              programs.nixfmt.enable = true;
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
                  name = "check-tca";
                  help = "build The Composable Architecture test package in the sandbox";
                  command = ''nix build ".#checks.$(nix eval --raw --impure --expr builtins.currentSystem).composable-architecture" -L "$@"'';
                }
                {
                  category = "format";
                  name = "fmt";
                  help = "format every Nix file with treefmt";
                  command = ''nix fmt "$@"'';
                }
              ];
            };
          };
      }
    );
}

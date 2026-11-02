{
  description = "SwiftPM dependencies for Nix builds, fetched from the package's own Package.resolved";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        systems = [
          "aarch64-darwin"
          "x86_64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];

        flake.lib = import ./lib { inherit (nixpkgs) lib; };

        perSystem =
          { pkgs, lib, ... }:
          {
            # The Composable Architecture as the test: 14 packages, swift-syntax
            # macros among them, built with the network cut off.
            checks = lib.optionalAttrs pkgs.stdenv.isDarwin {
              composable-architecture = pkgs.callPackage ./tests/composable-architecture {
                swiftpmDeps = config.flake.lib.fetchDeps pkgs {
                  resolved = ./tests/composable-architecture/Package.resolved;
                };
              };
            };

            formatter = pkgs.nixfmt-rfc-style;
          };
      }
    );
}

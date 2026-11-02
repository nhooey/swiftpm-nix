# swiftpm-nix

Builds a Swift package's SwiftPM dependencies in the Nix sandbox, where `swift build` cannot reach the network. It reads the package's own `Package.resolved`, fetches each pin by its revision, and lays the checkouts out the way `swift package resolve` would. The lock file SwiftPM already keeps is the only record of what is used: there is no generated Nix file to keep in step with it.

## Use

```nix
{
  inputs.swiftpm-nix.url = "github:nhooey/swiftpm-nix";

  outputs = { nixpkgs, swiftpm-nix, ... }: {
    # in a perSystem or per-system package:
    packages.aarch64-darwin.default =
      let
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        swiftpmDeps = swiftpm-nix.lib.fetchDeps pkgs { resolved = ./Package.resolved; };
      in
      pkgs.stdenv.mkDerivation {
        # …
        nativeBuildInputs = [ pkgs.swift pkgs.swiftpm swiftpmDeps ];
        buildPhase = ''
          swiftpmUseDeps "$TMPDIR/scratch"
          swift build --disable-sandbox --scratch-path "$TMPDIR/scratch"
        '';
      };
  };
}
```

`fetchDeps pkgs { resolved; workspaceStateVersion ? 7; }` returns a setup hook. In `nativeBuildInputs` it defines `swiftpmUseDeps <scratch-path>`, which copies every checkout, writable, into `<scratch-path>/checkouts` and writes `<scratch-path>/workspace-state.json`. Pass the same path to `swift build --scratch-path`. The hook's `passthru` has `deps`, the fetched tree, and `pins`, the parsed pins.

`workspaceStateVersion` is the layout of SwiftPM's `workspace-state.json`; SwiftPM 6 writes 7.

## How pins are fetched

- A `github.com` pin is fetched as a tarball with `builtins.fetchTree`, which is much faster than a clone.
- Any other host is cloned with `builtins.fetchGit`.

Both are locked by the pin's revision, so they work in pure evaluation and need no hashes. They are fetched when the flake is evaluated and cached by Nix from then on.

`Package.resolved` must be version 2 or later, which SwiftPM 5.6 and later write. Only `remoteSourceControl` pins are handled; local and registry dependencies are left to SwiftPM.

## Test

`nix flake check` on macOS builds a one-reducer program on Point-Free's The Composable Architecture: 14 packages, swift-syntax's macros among them, in the sandbox, and checks that it runs.

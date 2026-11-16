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
        nativeBuildInputs = [
          pkgs.swift
          pkgs.swiftpm
          pkgs.darwin.sigtool # SwiftPM signs debug binaries with `codesign`
          swiftpmDeps
        ];
        buildInputs = [ pkgs.apple-sdk_15 ];
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

`swiftpm-nix.lib.pinsOf <Package.resolved>` returns the `remoteSourceControl` pins of a `Package.resolved`, the same list as `passthru.pins`.

## How pins are fetched

- A `github.com` pin is fetched as a tarball with `builtins.fetchTree`, which is much faster than a clone.
- Any other host is cloned with `builtins.fetchGit`.

Both are locked by the pin's revision, so they work in pure evaluation and need no hashes. They are fetched when the flake is evaluated and cached by Nix from then on.

`Package.resolved` must be version 2 or later, which SwiftPM 5.6 and later write. Only `remoteSourceControl` pins are handled; local and registry dependencies are left to SwiftPM.

## Test

`nix flake check` runs four tests, and on every system also fails on any file `nix fmt` would change:

- `unit`, on every system: evaluates the pure functions in `lib/pins.nix` against small `Package.resolved` fixtures in `tests/unit/fixtures/`, covering non-GitHub hosts, branch-only and revision-only pins, and the version 1 rejection.
- `setup-hook`, on every system: runs `swiftpmUseDeps` without Swift and checks it leaves one writable checkout per pin and a writable `workspace-state.json`.
- `tools`, on every system: unit-tests `tools/check.py`, the dev shell's `check` command, in `tests/tools/`.
- `composable-architecture`, on macOS: builds a one-reducer program on Point-Free's The Composable Architecture, 14 packages with swift-syntax's macros among them, with every dependency from `fetchDeps`, and checks that it runs. A stand-in `git` fails and records every clone or fetch, so the check fails if SwiftPM tries to fetch anything, whether Nix's sandbox is on or off.

## Develop

- `nix develop`: a shell with Swift and SwiftPM and the commands below.
- `check`: lists the flake's checks for the current system (`check list`), builds chosen ones with their logs (`check build composable-architecture`) or runs them all (`check all`); `check --help` has the rest.
- `fmt` (or `nix fmt`): formats every Nix and Python file with treefmt.

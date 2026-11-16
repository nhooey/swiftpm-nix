# swiftpm-nix

A Nix library that fetches a Swift package's SwiftPM dependencies from its own `Package.resolved` and lays them out so `swift build` finds every one without fetching. The library is `lib/`, its pure half in `lib/pins.nix`; `tests/` holds the checks.

## Build and test

- `nix develop`: the dev shell, with Swift and SwiftPM, the `check` and `fmt` commands (`check --help` lists its commands), and the project's skills installed into `.agents/skills/` from the `skills-devshell/` sub-flake.
- `nix flake check`: on every system, runs the unit tests of `lib/pins.nix` (`tests/unit/`), the setup hook test (`tests/setup-hook/`) and the tests of `tools/check.py` (`tests/tools/`), and fails on any file `nix fmt` would change; on macOS, also builds The Composable Architecture test package with its dependencies from the setup hook, fails if SwiftPM tries to fetch, and runs it.
- `nix fmt`: formats every Nix and Python file with treefmt.

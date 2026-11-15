# swiftpm-nix

A Nix library that fetches a Swift package's SwiftPM dependencies from its own `Package.resolved` and lays them out so `swift build` runs in the Nix sandbox. The library is `lib/`; `tests/composable-architecture/` is the package the check builds.

## Build and test

- `nix develop`: the dev shell, with Swift and SwiftPM, the `check-tca` and `fmt` commands, and the project's skills installed into `.agents/skills/` from the `skills-devshell/` sub-flake.
- `nix flake check`: on macOS, builds The Composable Architecture test package in the sandbox and runs it; on every system, fails on any file `nix fmt` would change.
- `nix fmt`: formats every Nix file with treefmt.

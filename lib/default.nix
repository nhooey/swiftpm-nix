# SwiftPM dependencies for a Nix build, read from the package's own
# Package.resolved. Each pin is fetched by its revision, so the lock file
# SwiftPM already keeps is the only record of what is used.
{ lib }:
let
  inherit (import ./pins.nix { inherit lib; }) fetchArgs pinsOf workspaceState;

  fetchPin =
    pin:
    let
      fetch = fetchArgs pin;
    in
    builtins.${fetch.fetcher} fetch.args;
in
{
  inherit pinsOf;

  /**
    A setup hook that provides `swiftpmUseDeps <scratch-path>`, which puts
    every dependency of `resolved` where `swift build --scratch-path
    <scratch-path>` looks, so the build fetches nothing.

    `workspaceStateVersion` is the layout of SwiftPM's
    `workspace-state.json`: 7 for SwiftPM 6.
  */
  fetchDeps =
    pkgs:
    {
      resolved,
      workspaceStateVersion ? 7,
    }:
    let
      pins = pinsOf resolved;
      state = pkgs.writeText "workspace-state.json" (workspaceState {
        inherit pins;
        version = workspaceStateVersion;
      });
      deps = pkgs.runCommand "swiftpm-deps" { } ''
        mkdir -p "$out/checkouts"
        ${lib.concatMapStrings (pin: ''
          ln -s ${fetchPin pin} "$out/checkouts/${pin.identity}"
        '') pins}
        cp ${state} "$out/workspace-state.json"
      '';
    in
    pkgs.makeSetupHook {
      name = "swiftpm-deps-hook";
      substitutions = { inherit deps; };
      passthru = { inherit deps pins; };
    } ./setup-hook.sh;
}

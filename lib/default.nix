# SwiftPM dependencies for a Nix build, read from the package's own
# Package.resolved. Each pin is fetched by its revision, so the lock file
# SwiftPM already keeps is the only record of what is used.
{ lib }:
let
  # A GitHub location as its owner and repository, or null for any other
  # host. GitHub pins are fetched as tarballs, much faster than a clone.
  github =
    location:
    let
      parts = builtins.match "https://github\\.com/([^/]+)/([^/]+)" location;
    in
    if parts == null then
      null
    else
      {
        owner = builtins.elemAt parts 0;
        repo = lib.removeSuffix ".git" (builtins.elemAt parts 1);
      };

  # The package's name, as SwiftPM derives it from the location: the last
  # path component, without `.git`, case kept.
  nameOf = location: lib.removeSuffix ".git" (lib.last (lib.splitString "/" location));

  fetchPin =
    pin:
    let
      repo = github pin.location;
      rev = pin.state.revision;
    in
    if repo != null then
      builtins.fetchTree {
        type = "github";
        inherit (repo) owner repo;
        inherit rev;
      }
    else
      builtins.fetchGit {
        url = pin.location;
        inherit rev;
        allRefs = true;
      };

  # The pins of a Package.resolved, in its version 2 or 3 layout.
  pinsOf =
    resolved:
    let
      data = lib.importJSON resolved;
    in
    if data.version or 1 >= 2 then
      builtins.filter (pin: pin.kind == "remoteSourceControl") data.pins
    else
      throw "swiftpm-nix: ${toString resolved} is a version ${toString data.version} Package.resolved; resolve it again with SwiftPM 5.6 or later";

  # What `swift package resolve` leaves in the scratch directory, so a build
  # finds every checkout already in place.
  workspaceState =
    { pins, version }:
    builtins.toJSON {
      inherit version;
      object = {
        artifacts = [ ];
        prebuilts = [ ];
        dependencies = map (pin: {
          basedOn = null;
          packageRef = {
            inherit (pin) identity location;
            kind = "remoteSourceControl";
            name = nameOf pin.location;
          };
          state = {
            name = "sourceControlCheckout";
            checkoutState = {
              inherit (pin.state) revision;
            }
            // lib.optionalAttrs (pin.state.version or null != null) { inherit (pin.state) version; }
            // lib.optionalAttrs (pin.state.branch or null != null) { inherit (pin.state) branch; };
          };
          subpath = pin.identity;
        }) pins;
      };
    };
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

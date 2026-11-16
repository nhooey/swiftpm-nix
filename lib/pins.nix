# The pure half of the library: reading a Package.resolved and deciding
# what to fetch and what to write, with no fetching or building, so the
# unit tests reach every branch at evaluation time.
{ lib }:
rec {
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

  # The builtin that fetches a pin and its arguments: a GitHub tarball, or
  # a clone of any other host. Both are locked by the pin's revision.
  fetchArgs =
    pin:
    let
      repo = github pin.location;
      rev = pin.state.revision;
    in
    if repo != null then
      {
        fetcher = "fetchTree";
        args = {
          type = "github";
          inherit (repo) owner repo;
          inherit rev;
        };
      }
    else
      {
        fetcher = "fetchGit";
        args = {
          url = pin.location;
          inherit rev;
          allRefs = true;
        };
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
}

{
  description = "swiftpm-nix dev-shell skill set: an isolated sub-flake the root dev shell invokes at runtime, never a root input, so the skill sources live only in this flake's lock.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    # The builder lib; it carries no skill inputs.
    agent-skill-flake = {
      url = "github:nhooey/agent-skill-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # skillspkgs' per-family skill combinations; this repository is in the
    # Nix tooling family and takes `combinations.nix-tooling`.
    skillspkgs-combinations = {
      url = "github:nhooey/skillspkgs?dir=sources/combinations";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      agent-skill-flake,
      ...
    }@inputs:
    agent-skill-flake.lib.mkDevshellSkillsFlake {
      inherit nixpkgs;
      systems = import inputs.systems;
      name = "swiftpm-nix-devshell";
      sources = [
        # The Nix tooling family's combination. No additions: the Swift and
        # SwiftPM work here has no skill collection of its own.
        { source = inputs.skillspkgs-combinations.combinations.nix-tooling; }
      ];
    };
}

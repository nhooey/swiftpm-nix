# Unit tests of lib/pins.nix, run at evaluation time on every system: the
# list of tests whose result differs from what they expect, empty when all
# pass.
{ lib }:
let
  inherit (import ../../lib/pins.nix { inherit lib; })
    github
    nameOf
    fetchArgs
    pinsOf
    workspaceState
    ;

  mixed = pinsOf ./fixtures/v3-mixed.resolved;
  pinNamed = identity: lib.findFirst (pin: pin.identity == identity) null mixed;

  # workspace-state.json for the mixed fixture, parsed back, and one of its
  # dependencies by identity.
  state = builtins.fromJSON (workspaceState {
    pins = mixed;
    version = 7;
  });
  dependency =
    identity: lib.findFirst (dep: dep.packageRef.identity == identity) null state.object.dependencies;

  # Whether evaluating `value` all the way down throws.
  throws = value: !(builtins.tryEval (builtins.deepSeq value value)).success;
in
lib.runTests {
  testGithubOwnerAndRepo = {
    expr = github "https://github.com/apple/swift-collections";
    expected = {
      owner = "apple";
      repo = "swift-collections";
    };
  };
  testGithubDropsGitSuffix = {
    expr = github "https://github.com/scinfu/SwiftSoup.git";
    expected = {
      owner = "scinfu";
      repo = "SwiftSoup";
    };
  };
  testGithubOtherHostIsNull = {
    expr = github "https://gitlab.com/group/sub/Tool.git";
    expected = null;
  };
  testGithubSshIsNull = {
    expr = github "git@github.com:apple/swift-collections.git";
    expected = null;
  };
  testGithubPlainHttpIsNull = {
    expr = github "http://github.com/apple/swift-collections";
    expected = null;
  };

  testNameOfKeepsCase = {
    expr = nameOf "https://github.com/scinfu/SwiftSoup";
    expected = "SwiftSoup";
  };
  testNameOfDropsGitSuffix = {
    expr = nameOf "https://gitlab.com/group/sub/Tool.git";
    expected = "Tool";
  };

  testFetchArgsGithubIsTarball = {
    expr = fetchArgs (pinNamed "swiftsoup");
    expected = {
      fetcher = "fetchTree";
      args = {
        type = "github";
        owner = "scinfu";
        repo = "SwiftSoup";
        rev = "1111111111111111111111111111111111111111";
      };
    };
  };
  testFetchArgsOtherHostIsClone = {
    expr = fetchArgs (pinNamed "tool");
    expected = {
      fetcher = "fetchGit";
      args = {
        url = "https://gitlab.com/group/sub/Tool.git";
        rev = "2222222222222222222222222222222222222222";
        allRefs = true;
      };
    };
  };
  testFetchArgsGithubSshIsClone = {
    expr =
      (fetchArgs {
        location = "git@github.com:apple/swift-collections.git";
        state.revision = "f96b909e1a9e469620bc5037c1e24e00153f376f";
      }).fetcher;
    expected = "fetchGit";
  };

  testPinsOfKeepsOnlyRemoteSourceControl = {
    expr = map (pin: pin.identity) mixed;
    expected = [
      "swift-collections"
      "swiftsoup"
      "tool"
    ];
  };
  testPinsOfReadsVersion2 = {
    expr = map (pin: pin.identity) (pinsOf ./fixtures/v2.resolved);
    expected = [ "swift-collections" ];
  };
  testPinsOfRejectsVersion1 = {
    expr = throws (pinsOf ./fixtures/v1.resolved);
    expected = true;
  };

  testWorkspaceStateVersionIsPassedThrough = {
    expr =
      (builtins.fromJSON (workspaceState {
        pins = [ ];
        version = 6;
      })).version;
    expected = 6;
  };
  testWorkspaceStateEmpty = {
    expr =
      (builtins.fromJSON (workspaceState {
        pins = [ ];
        version = 7;
      })).object;
    expected = {
      artifacts = [ ];
      prebuilts = [ ];
      dependencies = [ ];
    };
  };
  testWorkspaceStateOneDependencyPerPin = {
    expr = map (dep: dep.packageRef.identity) state.object.dependencies;
    expected = [
      "swift-collections"
      "swiftsoup"
      "tool"
    ];
  };
  testWorkspaceStateVersionPin = {
    expr = dependency "swift-collections";
    expected = {
      basedOn = null;
      packageRef = {
        identity = "swift-collections";
        kind = "remoteSourceControl";
        location = "https://github.com/apple/swift-collections";
        name = "swift-collections";
      };
      state = {
        name = "sourceControlCheckout";
        checkoutState = {
          revision = "f96b909e1a9e469620bc5037c1e24e00153f376f";
          version = "1.7.5";
        };
      };
      subpath = "swift-collections";
    };
  };
  testWorkspaceStateBranchPin = {
    expr = (dependency "swiftsoup").state.checkoutState;
    expected = {
      revision = "1111111111111111111111111111111111111111";
      branch = "master";
    };
  };
  testWorkspaceStateBranchPinNameKeepsCase = {
    expr = (dependency "swiftsoup").packageRef.name;
    expected = "SwiftSoup";
  };
  testWorkspaceStateRevisionOnlyPin = {
    expr = (dependency "tool").state.checkoutState;
    expected = {
      revision = "2222222222222222222222222222222222222222";
    };
  };
  testWorkspaceStateNullVersionAndBranchLeftOut = {
    expr =
      (builtins.fromJSON (workspaceState {
        pins = [
          {
            identity = "x";
            location = "https://example.com/x";
            state = {
              revision = "4444444444444444444444444444444444444444";
              version = null;
              branch = null;
            };
          }
        ];
        version = 7;
      })).object.dependencies;
    expected = [
      {
        basedOn = null;
        packageRef = {
          identity = "x";
          kind = "remoteSourceControl";
          location = "https://example.com/x";
          name = "x";
        };
        state = {
          name = "sourceControlCheckout";
          checkoutState.revision = "4444444444444444444444444444444444444444";
        };
        subpath = "x";
      }
    ];
  };
}

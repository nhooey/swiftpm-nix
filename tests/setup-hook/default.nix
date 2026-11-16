# Runs swiftpmUseDeps from swiftpmDeps into a scratch directory, without
# Swift, and checks it leaves what `swift package resolve` would: one
# writable checkout per pin, and a writable workspace-state.json listing
# them all. Fast, and runs on every system.
{
  lib,
  runCommand,
  jq,
  swiftpmDeps,
}:
let
  identities = map (pin: pin.identity) swiftpmDeps.pins;
in
runCommand "swiftpm-nix-test-setup-hook"
  {
    nativeBuildInputs = [
      jq
      swiftpmDeps
    ];
  }
  ''
    set -euo pipefail
    export LC_ALL=C

    if (swiftpmUseDeps) 2>/dev/null; then
      echo "swiftpmUseDeps succeeded with no scratch path" >&2
      exit 1
    fi

    scratch=$TMPDIR/scratch
    swiftpmUseDeps "$scratch"

    expected=$(printf '%s\n' ${lib.escapeShellArgs identities} | sort)
    actual=$(ls -A "$scratch/checkouts")
    if [ "$actual" != "$expected" ]; then
      echo "checkouts: expected" $expected "got" $actual >&2
      exit 1
    fi

    for identity in ${lib.escapeShellArgs identities}; do
      checkout=$scratch/checkouts/$identity
      if [ -L "$checkout" ] || [ ! -f "$checkout/Package.swift" ]; then
        echo "$checkout is not a copied package" >&2
        exit 1
      fi
      # SwiftPM writes into its checkouts, so every file must be writable.
      if [ -n "$(find "$checkout" ! -perm -u+w -print -quit)" ]; then
        echo "$checkout has read-only files" >&2
        exit 1
      fi
    done

    state=$scratch/workspace-state.json
    if [ ! -w "$state" ]; then
      echo "$state is read-only" >&2
      exit 1
    fi
    cmp "$state" ${swiftpmDeps.deps}/workspace-state.json
    jq -e --argjson ids ${lib.escapeShellArg (builtins.toJSON identities)} \
      '[.object.dependencies[].packageRef.identity] == $ids' "$state" >/dev/null

    touch "$out"
  ''

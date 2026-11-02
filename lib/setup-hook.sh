# shellcheck shell=bash

# swiftpmUseDeps <scratch-path>: copies the fetched checkouts and SwiftPM's
# workspace state into <scratch-path>, writable, as `swift package resolve`
# would leave them. Pass the same path to `swift build --scratch-path`.
swiftpmUseDeps() {
  local scratch=${1:?swiftpmUseDeps: give the scratch path that swift build uses}
  mkdir -p "$scratch/checkouts"
  local checkout
  for checkout in "@deps@"/checkouts/*; do
    cp -R "$(readlink -f "$checkout")" "$scratch/checkouts/${checkout##*/}"
  done
  chmod -R u+w "$scratch/checkouts"
  cp "@deps@/workspace-state.json" "$scratch/workspace-state.json"
  chmod u+w "$scratch/workspace-state.json"
}

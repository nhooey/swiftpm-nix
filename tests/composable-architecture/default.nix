# Builds a one-reducer Composable Architecture program in the sandbox, with
# its dependencies from swiftpmDeps, and checks it runs.
{
  lib,
  stdenv,
  swift,
  swiftpm,
  darwin,
  apple-sdk_15,
  swiftpmDeps,
}:
stdenv.mkDerivation {
  name = "swiftpm-nix-test-composable-architecture";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Package.swift
      ./Package.resolved
      ./Sources
    ];
  };

  nativeBuildInputs = [
    swift
    swiftpm
    darwin.sigtool # SwiftPM signs debug binaries with `codesign`
    swiftpmDeps
  ];
  buildInputs = [ apple-sdk_15 ];

  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    swiftpmUseDeps "$TMPDIR/scratch"
    swift build --disable-sandbox --scratch-path "$TMPDIR/scratch" -j "$NIX_BUILD_CORES"
    test "$("$TMPDIR/scratch/debug/Counter")" = "count 1"
    runHook postBuild
  '';
  installPhase = ''
    touch "$out"
  '';
}

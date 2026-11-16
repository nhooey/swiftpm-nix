# Builds a one-reducer Composable Architecture program with its
# dependencies from swiftpmDeps, and checks it runs. SwiftPM may not
# resolve or fetch anything, so the build fails if the hook left any
# checkout or workspace state out, with Nix's sandbox on or off.
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
    # SwiftPM fetches with git, and falls back to the checkouts it finds if
    # git fails. This git comes first on PATH and fails every call, as no
    # git can work on checkouts without .git, and records each fetch, so
    # the build fails below on any attempt to reach the network.
    mkdir "$TMPDIR/bin"
    cat >"$TMPDIR/bin/git" <<EOF
    #!$SHELL
    case " \$* " in
      *" clone "* | *" fetch "* | *" ls-remote "*) echo "git \$*" >>"$TMPDIR/git-fetches" ;;
    esac
    exit 1
    EOF
    chmod +x "$TMPDIR/bin/git"
    export PATH="$TMPDIR/bin:$PATH"

    swiftpmUseDeps "$TMPDIR/scratch"
    swift build --disable-sandbox --scratch-path "$TMPDIR/scratch" -j "$NIX_BUILD_CORES"
    if [ -e "$TMPDIR/git-fetches" ]; then
      echo "SwiftPM tried to fetch:" >&2
      cat "$TMPDIR/git-fetches" >&2
      exit 1
    fi
    test "$("$TMPDIR/scratch/debug/Counter")" = "count 1"
    runHook postBuild
  '';
  installPhase = ''
    touch "$out"
  '';
}

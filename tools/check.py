"""Run this flake's checks, all of them or a chosen few for this system.

  check list                          names the checks for this system
  check build composable-architecture builds one check, with its log
  check all                           runs `nix flake check`

Every command takes `--flake REF` (default: the dev shell's $PRJ_ROOT, or
`.` outside it) and `--dry-run`, which prints the `nix` command instead of
running it. Arguments after `--` go to `nix` unchanged.

Exit status: 0 when the checks pass, 1 when one fails, 2 on bad usage.
"""

import argparse
import json
import os
import shlex
import subprocess
import sys

CURRENT_SYSTEM = [
    "nix",
    "eval",
    "--raw",
    "--impure",
    "--expr",
    "builtins.currentSystem",
]


def parser():
    top = argparse.ArgumentParser(
        prog="check",
        description="Run this flake's checks, all of them or a chosen few for this system.",
        epilog="Example: check build composable-architecture -- --rebuild",
    )
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--flake",
        default=os.environ.get("PRJ_ROOT", "."),
        help="the flake to check (default: $PRJ_ROOT, or . outside the dev shell)",
    )
    common.add_argument(
        "--dry-run",
        action="store_true",
        help="print the nix command instead of running it",
    )
    commands = top.add_subparsers(dest="command", required=True, metavar="COMMAND")
    commands.add_parser(
        "list",
        parents=[common],
        help="name the checks for this system",
        description="Name the checks for this system, one per line.",
    )
    build = commands.add_parser(
        "build",
        parents=[common],
        help="build the named checks for this system, with their logs",
        description="Build the named checks for this system, printing their build logs.",
        epilog="Example: check build unit setup-hook",
    )
    build.add_argument(
        "names", nargs="+", metavar="NAME", help="a check, as `check list` names it"
    )
    commands.add_parser(
        "all",
        parents=[common],
        help="run nix flake check: every check, and the formatting",
        description="Run `nix flake check`: every check for this system, and the formatting check.",
    )
    return top


def split_passthrough(argv):
    """Split argv at the first `--` into the tool's arguments and nix's."""
    if "--" in argv:
        at = argv.index("--")
        return argv[:at], argv[at + 1 :]
    return argv, []


def nix_command(args, system, extra):
    """The nix command for parsed args, on `system`, with `extra` arguments."""
    if args.command == "list":
        return [
            "nix",
            "eval",
            "--json",
            f"{args.flake}#checks.{system}",
            "--apply",
            "builtins.attrNames",
        ] + extra
    if args.command == "build":
        installables = [f"{args.flake}#checks.{system}.{name}" for name in args.names]
        return ["nix", "build", "--no-link", "-L"] + installables + extra
    return ["nix", "flake", "check", "-L", args.flake] + extra


def needs_system(args):
    return args.command in ("list", "build")


def current_system():
    return subprocess.run(
        CURRENT_SYSTEM, check=True, capture_output=True, text=True
    ).stdout


def format_names(json_names):
    """`nix eval --json` output of a list of names, one per line."""
    return "".join(f"{name}\n" for name in json.loads(json_names))


def main(argv):
    own, extra = split_passthrough(argv)
    args = parser().parse_args(own)
    system = current_system() if needs_system(args) else None
    command = nix_command(args, system, extra)
    if args.dry_run:
        print(shlex.join(command))
        return 0
    if args.command == "list":
        result = subprocess.run(command, capture_output=True, text=True)
        sys.stderr.write(result.stderr)
        if result.returncode == 0:
            sys.stdout.write(format_names(result.stdout))
        return 0 if result.returncode == 0 else 1
    return 0 if subprocess.run(command).returncode == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

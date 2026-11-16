"""Tests of tools/check.py's argument parsing and the nix commands it builds."""

import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))

import check  # noqa: E402

SYSTEM = "aarch64-darwin"


def command_for(argv):
    own, extra = check.split_passthrough(argv)
    return check.nix_command(check.parser().parse_args(own), SYSTEM, extra)


class SplitPassthrough(unittest.TestCase):
    def test_without_separator_nix_gets_nothing(self):
        self.assertEqual(check.split_passthrough(["all"]), (["all"], []))

    def test_splits_at_the_first_separator(self):
        self.assertEqual(
            check.split_passthrough(["build", "unit", "--", "--rebuild", "--", "x"]),
            (["build", "unit"], ["--rebuild", "--", "x"]),
        )


class NixCommand(unittest.TestCase):
    def test_list_evaluates_the_names_of_this_systems_checks(self):
        self.assertEqual(
            command_for(["list", "--flake", "."]),
            [
                "nix",
                "eval",
                "--json",
                ".#checks.aarch64-darwin",
                "--apply",
                "builtins.attrNames",
            ],
        )

    def test_build_names_one_installable_per_check(self):
        self.assertEqual(
            command_for(["build", "--flake", "/f", "unit", "setup-hook"]),
            [
                "nix",
                "build",
                "--no-link",
                "-L",
                "/f#checks.aarch64-darwin.unit",
                "/f#checks.aarch64-darwin.setup-hook",
            ],
        )

    def test_all_runs_flake_check_and_passes_extra_arguments(self):
        self.assertEqual(
            command_for(["all", "--flake", ".", "--", "--keep-going"]),
            ["nix", "flake", "check", "-L", ".", "--keep-going"],
        )

    def test_only_list_and_build_need_the_system(self):
        parse = check.parser().parse_args
        self.assertTrue(check.needs_system(parse(["list"])))
        self.assertTrue(check.needs_system(parse(["build", "unit"])))
        self.assertFalse(check.needs_system(parse(["all"])))


class Parser(unittest.TestCase):
    def assert_usage_error(self, argv):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                check.parser().parse_args(argv)
        self.assertEqual(raised.exception.code, 2)

    def test_a_command_is_required(self):
        self.assert_usage_error([])

    def test_build_needs_a_name(self):
        self.assert_usage_error(["build"])

    def test_unknown_command_is_a_usage_error(self):
        self.assert_usage_error(["tca"])

    def test_dry_run_is_off_by_default(self):
        self.assertFalse(check.parser().parse_args(["all"]).dry_run)

    def test_help_lists_every_command(self):
        text = check.parser().format_help()
        for command in ("list", "build", "all"):
            self.assertIn(command, text)


class FormatNames(unittest.TestCase):
    def test_one_name_per_line(self):
        self.assertEqual(
            check.format_names('["setup-hook","unit"]'), "setup-hook\nunit\n"
        )

    def test_no_names_prints_nothing(self):
        self.assertEqual(check.format_names("[]"), "")


if __name__ == "__main__":
    unittest.main()

"""Offline target fixtures; never an SDF-live receipt."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location("sdf_probe", ROOT / "probes/sdf_mailbox.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class HostTests(unittest.TestCase):
    def test_old_negative_cloud_default_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "ci").mkdir()
            (root / "ci/repositories.sh").write_text((ROOT / "ci/repositories.sh").read_text())
            (root / "repository-aliases.tsv").write_text((ROOT / "repository-aliases.tsv").read_text())
            code = (ROOT / "catfood").read_text()
            start = code.index("detect_target() {")
            end = code.index("\nnormalize_repository_url()", start)
            mutant = code[:start] + 'detect_target() { printf "cloud\\n"; }\n' + code[end:]
            (root / "catfood").write_text(mutant)
            fake = root / "uname"
            fake.write_text('#!/bin/sh\nprintf "NetBSD\\n"\n')
            fake.chmod(0o700)
            env = dict(os.environ, PATH=str(root) + ":" + os.environ["PATH"])
            for name in ("PREFIX", "TERMUX_VERSION", "CATFOOD_TARGET"):
                env.pop(name, None)
            mutant_result = subprocess.run(["sh", str(root / "catfood"), "--target"], env=env, capture_output=True, text=True)
            good_result = subprocess.run(["sh", str(ROOT / "catfood"), "--target"], env=env, capture_output=True, text=True)
            self.assertEqual(mutant_result.returncode, 0, mutant_result.stderr)
            self.assertEqual(mutant_result.stdout.strip(), "cloud")
            self.assertNotEqual(good_result.returncode, 0)
            self.assertNotIn("cloud", good_result.stdout)

    def test_probe_non_mutating_and_netbsd_required(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            archive = Path(directory) / "archive"
            source.write_bytes(b"private mail\xff")
            before = source.stat()
            lines = []
            module.probe(source, archive, output=lines.append)
            self.assertEqual(source.stat(), before)
            self.assertFalse(archive.exists())
            self.assertIn("delivery-lock\tUNKNOWN", lines)
            self.assertIn("mailbox-mutation\tnone", lines)
            with patch.object(module.os, "uname", return_value=os.uname_result(("Linux", "fixture", "1", "1", "x86"))):
                with self.assertRaises(RuntimeError):
                    module.probe(source, archive, True, lines.append)
            with patch.object(module.os, "uname", return_value=os.uname_result(("NetBSD", "fixture.sdf.org", "11", "1", "amd64"))):
                module.probe(source, archive, True, lines.append)
            with self.assertRaises(RuntimeError):
                module.probe("source", archive, output=lines.append)

    def test_actual_entrypoint_platform_and_overrides(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake = root / "uname"
            # This test adapter runs the existing documented stage-zero sh entry;
            # it is not a post-bootstrap human procedure.
            fake.write_text('#!/bin/sh\ncase "$1" in -s) printf "%s\\n" "$TEST_SYSTEM";; -m) printf "%s\\n" "$TEST_MACHINE";; *) exit 2;; esac\n')
            fake.chmod(0o700)
            env = dict(os.environ, PATH=str(root) + ":" + os.environ["PATH"])
            for name in ("PREFIX", "TERMUX_VERSION", "CATFOOD_TARGET"):
                env.pop(name, None)
            for system in ("NetBSD", "Darwin", "unknown"):
                with self.subTest(system=system):
                    result = subprocess.run(["sh", str(ROOT / "catfood"), "--target"],
                               env=dict(env, TEST_SYSTEM=system, TEST_MACHINE="amd64"), capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn("cloud", result.stdout)
            for target in ("cloud", "container", "phone", "tablet", "termux", "hetzner"):
                result = subprocess.run(["sh", str(ROOT / "catfood"), "--target"],
                           env=dict(env, TEST_SYSTEM="NetBSD", TEST_MACHINE="amd64", CATFOOD_TARGET=target), capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "cloud" if target == "hetzner" else target)
            for machine, target in (("armv7l", "phone"), ("aarch64", "tablet"), ("unknown", "termux")):
                result = subprocess.run(["sh", str(ROOT / "catfood"), "--target"],
                           env=dict(env, TEST_SYSTEM="Linux", TEST_MACHINE=machine, TERMUX_VERSION="fixture"), capture_output=True, text=True)
                self.assertEqual(result.stdout.strip(), target)

    def test_positive_distribution_and_unknown_linux(self):
        code = (ROOT / "catfood").read_text()
        function = code[code.index("detect_target() {"):code.index("\nnormalize_repository_url()")]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            release = root / "os-release"
            for text, expected in (("ID=debian\n", "cloud"), ('ID="ubuntu"\n', "cloud"),
                                   ("ID=fedora\n", None), ("ID_LIKE=debian\n", None),
                                   ("ID=debianish\n", None), ("", None)):
                release.write_text(text)
                result = subprocess.run(["sh", "-c", function + '\nuname() { printf "Linux\\n"; }\ndetect_target "$1"',
                                         "fixture", str(release)], env=dict(os.environ, PREFIX="", TERMUX_VERSION=""), capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected is not None, result.stderr)
                if expected:
                    self.assertEqual(result.stdout.strip(), expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)

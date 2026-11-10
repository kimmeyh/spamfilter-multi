"""Tests for mobile-app/scripts/verify-aab-play-requirements.py (F333, Sprint 85; port of the .ps1).

Run: python -I -m unittest discover -s scripts/tests -v

Test list and what each does NOT catch:
  test_real_bundle_passes (AC-2): the real dist/android-0.24.1+22/app-prod-release.aab exits 0 with the
      two [OK] lines and 9 permissions; with --min-target-sdk 1000 it exits 1. Skipped (with the reason)
      when the bundle is not on this machine. NOT caught: a bundle built later with other contents.
  test_crafted_bundle_fails_each_rule (AC-2): one crafted .aab per rule (target 35, target missing,
      AD_ID present, AD_ID under uses-permission-sdk-23, AD_ID in other case, INTERNET missing) exits 1
      with that rule's [FAIL] text; the good one exits 0. NOT caught: a rule this script does not have.
  test_min_target_sdk_option: the minimum is honored (36 passes at 36, fails at 37). NOT caught: a
      minimum above 2**31.
  test_string_target_without_primitive: a targetSdkVersion stored only as text is read. NOT caught: a
      codename such as "VanillaIceCream" (that raises; test_bad_target_value_is_error covers the raise).
  test_unreadable_inputs_exit_2: no --aab-path, a missing file, a non-zip, a zip without the manifest and
      a manifest that is not protobuf exit 2 with an [ERROR] line. NOT caught: a read error in the middle
      of a large file.
  test_wire_reader_rejects_bad_bytes: truncated varint, over-long varint, length past the message and
      group wire types raise ProtoError. NOT caught: every possible malformed shape.
  test_hex_primitive_and_primitive_wins_over_text: a hex primitive (field 7) is read, and the integer
      primitive wins over a conflicting text value. NOT caught: a primitive of another wire type.
  test_varint_round_trip_and_signed: encode then decode returns the value; a 10-byte negative decodes
      as negative. NOT caught: values needing more than 64 bits (rejected, not decoded).
  test_oversized_manifest_entry_is_refused: an entry over 32 MiB exits 2. NOT caught: a zip that lies
      about file_size (the read is capped too, but this test uses an honest zip).
  test_self_test_runs_and_reports: --self-test with a crafted-good bundle as the "real" one prints the
      eight expectation lines and exits 0; with no bundle it exits 1. NOT caught: the default bundle
      search (it depends on this machine's dist folder).
  test_self_test_fails_on_bad_real_bundle: a self-test over a bundle that violates a rule exits 1.
      NOT caught: a failure inside the crafted cases.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
import unittest
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
TOOL_PATH = REPO / "mobile-app" / "scripts" / "verify-aab-play-requirements.py"
REAL_AAB = REPO / "mobile-app" / "dist" / "android-0.24.1+22" / "app-prod-release.aab"

_spec = importlib.util.spec_from_file_location("verify_aab_mod", TOOL_PATH)
tool = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(tool)

INTERNET = tool.INTERNET_PERMISSION
AD_ID = tool.AD_ID_PERMISSION


def run_main(argv: list[str]) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = tool.main(argv)
    return code, buf.getvalue()


def write_aab(folder: Path, name: str, manifest: bytes | None, entry: str = tool.MANIFEST_ENTRY) -> Path:
    path = folder / name
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr("BundleConfig.pb", b"x")
        if manifest is not None:
            bundle.writestr(entry, manifest)
    return path


class RealBundleTests(unittest.TestCase):
    def test_real_bundle_passes(self) -> None:
        if not REAL_AAB.exists():
            self.skipTest("real bundle not on this machine: %s" % REAL_AAB)
        code, out = run_main(["--aab-path", str(REAL_AAB)])
        self.assertEqual(code, 0, out)
        self.assertIn("[OK] targetSdkVersion = 36 (minimum 36).", out)
        self.assertIn("[OK] com.google.android.gms.permission.AD_ID absent (9 permissions read).", out)
        self.assertIn("[OK] Bundle meets the checked Google Play requirements.", out)
        code, out = run_main(["--aab-path", str(REAL_AAB), "--min-target-sdk", "1000"])
        self.assertEqual(code, 1)
        self.assertIn("[FAIL] Bundle does not meet Google Play requirements.", out)


class CraftedBundleTests(unittest.TestCase):
    def run_case(self, target, permissions) -> tuple[int, str]:
        with tempfile.TemporaryDirectory() as tmp:
            aab = write_aab(Path(tmp), "t.aab", tool.build_manifest(target, permissions))
            return run_main(["--aab-path", str(aab)])

    def test_crafted_bundle_fails_each_rule(self) -> None:
        code, out = self.run_case(36, [INTERNET])
        self.assertEqual(code, 0, out)
        self.assertIn("[OK] targetSdkVersion = 36 (minimum 36).", out)
        self.assertIn("[OK] %s absent (1 permissions read)." % AD_ID, out)
        failing = [
            ("old target", 35, [INTERNET], "[FAIL] targetSdkVersion = 35, below the required minimum 36."),
            ("no target", None, [INTERNET], "[FAIL] targetSdkVersion is not declared in the bundle manifest."),
            ("AD_ID", 36, [INTERNET, AD_ID], "[FAIL] %s is present (advertising ID requested)." % AD_ID),
            ("AD_ID other case", 36, [INTERNET, AD_ID.lower()], "is present (advertising ID requested)"),
            ("no INTERNET", 36, ["android.permission.CAMERA"], "[FAIL] %s not found (1 permissions read)" % INTERNET),
            ("no permissions", 36, [], "[FAIL] %s not found (0 permissions read)" % INTERNET),
            ("INTERNET wrong case", 36, [INTERNET.lower()], "not found"),
        ]
        for name, target, permissions, text in failing:
            with self.subTest(case=name):
                code, out = self.run_case(target, permissions)
                self.assertEqual(code, 1, out)
                self.assertIn(text, out)
                self.assertIn("[FAIL] Bundle does not meet Google Play requirements.", out)

    def test_ad_id_under_uses_permission_sdk_23(self) -> None:
        attrs = tool.enc_attr("name", AD_ID)
        kids = tool.enc_len_field(5, tool.enc_element("uses-permission", tool.enc_attr("name", INTERNET)))
        kids += tool.enc_len_field(5, tool.enc_element("uses-permission-sdk-23", attrs))
        kids += tool.enc_len_field(5, tool.enc_element(
            "uses-sdk", tool.enc_attr("targetSdkVersion", "36", 36)))
        manifest = tool.enc_element("manifest", b"", kids)
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run_main(["--aab-path", str(write_aab(Path(tmp), "t.aab", manifest))])
        self.assertEqual(code, 1)
        self.assertIn("is present (advertising ID requested)", out)

    def test_min_target_sdk_option(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            aab = write_aab(Path(tmp), "t.aab", tool.build_manifest(36, [INTERNET]))
            self.assertEqual(run_main(["--aab-path", str(aab), "--min-target-sdk", "36"])[0], 0)
            code, out = run_main(["--aab-path", str(aab), "--min-target-sdk", "37"])
        self.assertEqual(code, 1)
        self.assertIn("below the required minimum 37", out)

    def test_string_target_without_primitive(self) -> None:
        kids = tool.enc_len_field(5, tool.enc_element("uses-permission", tool.enc_attr("name", INTERNET)))
        kids += tool.enc_len_field(5, tool.enc_element("uses-sdk", tool.enc_attr("targetSdkVersion", "34")))
        facts = tool.get_manifest_facts(tool.enc_element("manifest", b"", kids))
        self.assertEqual(facts["target_sdk"], 34)

    def test_bad_target_value_is_error(self) -> None:
        kids = tool.enc_len_field(5, tool.enc_element(
            "uses-sdk", tool.enc_attr("targetSdkVersion", "VanillaIceCream")))
        manifest = tool.enc_element("manifest", b"", kids)
        with self.assertRaises(tool.ProtoError):
            tool.get_manifest_facts(manifest)
        with tempfile.TemporaryDirectory() as tmp:
            code, out = run_main(["--aab-path", str(write_aab(Path(tmp), "t.aab", manifest))])
        self.assertEqual(code, 2)
        self.assertIn("[ERROR] Could not read the bundle manifest:", out)


class ErrorTests(unittest.TestCase):
    def test_unreadable_inputs_exit_2(self) -> None:
        code, out = run_main([])
        self.assertEqual((code, out.strip()), (2, "[ERROR] --aab-path is required (or use --self-test)."))
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            code, out = run_main(["--aab-path", str(folder / "nope.aab")])
            self.assertEqual(code, 2)
            self.assertIn("Bundle not found", out)
            (folder / "plain.aab").write_bytes(b"not a zip")
            code, out = run_main(["--aab-path", str(folder / "plain.aab")])
            self.assertEqual(code, 2)
            self.assertIn("not a zip file", out)
            code, out = run_main(["--aab-path", str(write_aab(folder, "empty.aab", None))])
            self.assertEqual(code, 2)
            self.assertIn("not found in", out)
            code, out = run_main(["--aab-path", str(write_aab(folder, "junk.aab", b"hello world"))])
            self.assertEqual(code, 2)
            code, out = run_main(["--aab-path", str(write_aab(
                folder, "root.aab", tool.enc_element("application")))])
            self.assertEqual(code, 2)
            self.assertIn("root element is not <manifest>", out)

    def test_wire_reader_rejects_bad_bytes(self) -> None:
        with self.assertRaisesRegex(tool.ProtoError, "Truncated"):
            tool.read_varint(b"\x80", 0)  # continuation bit, then nothing
        with self.assertRaisesRegex(tool.ProtoError, "too long"):
            tool.read_varint(b"\xff" * 11, 0)
        with self.assertRaisesRegex(tool.ProtoError, "past its message"):
            tool.get_fields(b"\x0a\x05ab", 0, 4)  # length 5, only 2 bytes left
        with self.assertRaisesRegex(tool.ProtoError, "Unsupported protobuf wire type 3"):
            tool.get_fields(b"\x0b", 0, 1)  # wire type 3 (start group)
        # A length of -1 (ten-byte varint) would step back one byte; the bytes after that point parse
        # cleanly (tag 0x01 = field 0, wire type 1, then 8 bytes), so only the explicit check refuses it.
        negative = b"\x0a" + b"\xff" * 9 + b"\x01" + b"\x00" * 8
        with self.assertRaisesRegex(tool.ProtoError, "past its message"):
            tool.get_fields(negative, 0, len(negative))

    def test_hex_primitive_and_primitive_wins_over_text(self) -> None:
        hex_attr = tool.enc_len_field(4, tool.enc_str(2, "targetSdkVersion") +
                                      tool.enc_len_field(6, tool.enc_len_field(7, tool.enc_var_field(7, 36))))
        both = tool.enc_attr("targetSdkVersion", "bogus", 36)  # text says bogus, primitive says 36
        for name, attr in (("hex", hex_attr), ("text and primitive", both)):
            with self.subTest(case=name):
                kids = tool.enc_len_field(5, tool.enc_element("uses-sdk", attr))
                facts = tool.get_manifest_facts(tool.enc_element("manifest", b"", kids))
                self.assertEqual(facts["target_sdk"], 36)

    def test_varint_round_trip_and_signed(self) -> None:
        for value in (0, 1, 127, 128, 300, 2**31 - 1, 2**40):
            self.assertEqual(tool.read_varint(tool.enc_varint(value), 0), (value, len(tool.enc_varint(value))))
        decoded, _ = tool.read_varint(tool.enc_varint(-1), 0)
        self.assertEqual(decoded, -1)

    def test_oversized_manifest_entry_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            aab = write_aab(Path(tmp), "big.aab", b"\x00" * (tool.MAX_MANIFEST_BYTES + 1))
            code, out = run_main(["--aab-path", str(aab)])
        self.assertEqual(code, 2)
        self.assertIn("bytes, over the", out)  # the size check on the zip header, before any read


class SelfTestTests(unittest.TestCase):
    def test_self_test_runs_and_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            good = write_aab(Path(tmp), "good.aab", tool.build_manifest(36, [INTERNET]))
            code, out = run_main(["--self-test", "--aab-path", str(good)])
            self.assertEqual(code, 0, out)
            self.assertEqual(out.count("[SELFTEST OK]"), 8)
            self.assertIn("[SELFTEST] All expectations held.", out)
            code, out = run_main(["--self-test", "--aab-path", str(Path(tmp) / "missing.aab")])
            self.assertEqual(code, 1)
            self.assertIn("[SELFTEST FAIL] No real bundle found", out)

    def test_self_test_fails_on_bad_real_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bad = write_aab(Path(tmp), "bad.aab", tool.build_manifest(35, [INTERNET, AD_ID]))
            code, out = run_main(["--self-test", "--aab-path", str(bad)])
        self.assertEqual(code, 1)
        self.assertIn("[SELFTEST FAIL] real bundle passes (min 36)", out)
        self.assertIn("expectation(s) failed.", out)


if __name__ == "__main__":
    unittest.main()

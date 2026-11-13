"""Assert two Google Play requirements from the BUILT Android App Bundle (F204 gaps 1 and 2).

Python port (F333, Sprint 85) of verify-aab-play-requirements.ps1.

Reads base/manifest/AndroidManifest.xml from the .aab itself (the artifact, not gradle config) and fails
(exit 1) if:
  - targetSdkVersion is below --min-target-sdk (default 36), or is not declared, or
  - the permission com.google.android.gms.permission.AD_ID is present (the app declares "no advertising
    ID" in Play Console Data safety; a transitive ads dependency would make that answer false), or
  - android.permission.INTERNET is not found: then the permission list was not read and the AD_ID answer
    would rest on nothing (PR #490 7.7.1).

Why a built-in protobuf reader: inside an AAB the manifest is Android resource XML encoded as PROTOBUF
(aapt2 XmlNode), so a text regex cannot read an integer attribute. The decoder reads only the messages it
needs, with the standard library alone: XmlNode(1 element) -> XmlElement(3 name, 4 attribute, 5 child) ->
XmlAttribute(2 name, 3 value, 6 compiled_item) -> Item(7 prim) -> Primitive(6 int_decimal, 7 int_hex).
The decoder is proven against the real bundle by --self-test and by the unit tests.

Android-only by nature (Play requirements). The Windows MSIX equivalent is --release-self-test and
test/policy/msix_config_test.dart (ADR-0042 declared exception). The script itself runs on any OS that
has Python 3.

Usage:
    python verify-aab-play-requirements.py --aab-path PATH [--min-target-sdk 36]
    python verify-aab-play-requirements.py --self-test [--aab-path PATH]

--self-test runs the check against the real bundle (--aab-path, default: the newest
mobile-app/dist/**/app-prod-release.aab; FAILS if none exists) and against crafted manifests that must
fail each rule. Exit 0 only if every expectation holds.

Exit codes:
    0  the bundle meets the checked requirements (self-test: every expectation held)
    1  a requirement is not met (self-test: an expectation failed or no real bundle was found)
    2  the bundle could not be read, or --aab-path was not given
"""
from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
AD_ID_PERMISSION = "com.google.android.gms.permission.AD_ID"
INTERNET_PERMISSION = "android.permission.INTERNET"
MANIFEST_ENTRY = "base/manifest/AndroidManifest.xml"
MAX_MANIFEST_BYTES = 32 * 1024 * 1024  # a real manifest is a few KB; this bounds a hostile zip entry


class ProtoError(Exception):
    """The bytes are not the protobuf manifest this reader expects."""


# ---- protobuf wire reader -----------------------------------------------------------------------

def read_varint(data: bytes, pos: int) -> tuple[int, int]:
    """Returns (signed 64-bit value, new position), like PowerShell's [long]."""
    result = 0
    shift = 0
    while True:
        if pos >= len(data):
            raise ProtoError("Truncated protobuf varint.")
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7F) << shift
        if byte & 0x80 == 0:
            break
        shift += 7
        if shift > 63:
            raise ProtoError("Protobuf varint too long.")
    result &= 0xFFFFFFFFFFFFFFFF
    if result >= 1 << 63:
        result -= 1 << 64
    return result, pos


def get_fields(data: bytes, start: int, length: int) -> list[dict]:
    """Fields of one message in [start, start+length): dicts with f (field number), w (wire type),
    v (varint value), s and n (offset and length of a length-delimited field)."""
    fields: list[dict] = []
    pos = start
    end = start + length
    while pos < end:
        tag, pos = read_varint(data, pos)
        number = (tag & 0xFFFFFFFFFFFFFFFF) >> 3
        wire = tag & 7
        field = {"f": number, "w": wire, "v": 0, "s": 0, "n": 0}
        if wire == 0:
            field["v"], pos = read_varint(data, pos)
        elif wire == 1:
            field["s"], field["n"] = pos, 8
            pos += 8
        elif wire == 2:
            size, pos = read_varint(data, pos)
            if size < 0 or size > end - pos:  # checked before use (the original checked after moving)
                raise ProtoError("Protobuf field runs past its message.")
            field["s"], field["n"] = pos, size
            pos += size
        elif wire == 5:
            field["s"], field["n"] = pos, 4
            pos += 4
        else:
            raise ProtoError("Unsupported protobuf wire type %d." % wire)
        if pos > end:
            raise ProtoError("Protobuf field runs past its message.")
        fields.append(field)
    return fields


def _utf8(data: bytes, field: dict) -> str:
    return data[field["s"]:field["s"] + field["n"]].decode("utf-8", errors="replace")


def parse_element(data: bytes, start: int, length: int) -> dict:
    """XmlElement -> {"name", "attrs": {name: {"value", "prim"}}, "children": [element...]}."""
    element = {"name": "", "attrs": {}, "children": []}
    for f in get_fields(data, start, length):
        if f["f"] == 3 and f["w"] == 2:
            element["name"] = _utf8(data, f)
        elif f["f"] == 4 and f["w"] == 2:
            a_name, a_value, a_prim = "", "", None
            for a in get_fields(data, f["s"], f["n"]):
                if a["f"] == 2 and a["w"] == 2:
                    a_name = _utf8(data, a)
                elif a["f"] == 3 and a["w"] == 2:
                    a_value = _utf8(data, a)
                elif a["f"] == 6 and a["w"] == 2:
                    # compiled_item (Item) -> prim (7) -> int_decimal (6) / int_hexadecimal (7)
                    for i in get_fields(data, a["s"], a["n"]):
                        if i["f"] == 7 and i["w"] == 2:
                            for p in get_fields(data, i["s"], i["n"]):
                                if p["f"] in (6, 7) and p["w"] == 0:
                                    a_prim = str(p["v"])
            if a_name:
                element["attrs"][a_name] = {"value": a_value, "prim": a_prim}
        elif f["f"] == 5 and f["w"] == 2:
            # child XmlNode -> element (1)
            for n in get_fields(data, f["s"], f["n"]):
                if n["f"] == 1 and n["w"] == 2:
                    element["children"].append(parse_element(data, n["s"], n["n"]))
    return element


def get_manifest_facts(manifest: bytes) -> dict:
    """Returns {"target_sdk": int or None, "permissions": [names]} from the proto manifest bytes."""
    root = None
    for n in get_fields(manifest, 0, len(manifest)):
        if n["f"] == 1 and n["w"] == 2:
            root = parse_element(manifest, n["s"], n["n"])
    if root is None or root["name"] != "manifest":
        raise ProtoError("Manifest root element is not <manifest>; not a proto manifest?")
    target = None
    permissions: list[str] = []
    for child in root["children"]:
        if child["name"] == "uses-sdk" and "targetSdkVersion" in child["attrs"]:
            attr = child["attrs"]["targetSdkVersion"]
            raw = attr["prim"] if attr["prim"] else attr["value"]
            if not re.fullmatch(r"-?\d+", raw or ""):
                raise ProtoError("targetSdkVersion value '%s' is not an integer." % raw)
            target = int(raw)
        if child["name"] in ("uses-permission", "uses-permission-sdk-23") and "name" in child["attrs"]:
            permissions.append(child["attrs"]["name"]["value"])
    return {"target_sdk": target, "permissions": permissions}


def read_aab_manifest(path: Path) -> bytes:
    """The proto manifest bytes from base/manifest/AndroidManifest.xml inside the .aab."""
    try:
        with zipfile.ZipFile(path) as bundle:
            try:
                info = bundle.getinfo(MANIFEST_ENTRY)
            except KeyError:
                raise ProtoError("%s not found in %s (is it an .aab?)." % (MANIFEST_ENTRY, path))
            if info.file_size > MAX_MANIFEST_BYTES:
                raise ProtoError("%s is %d bytes, over the %d byte limit." %
                                 (MANIFEST_ENTRY, info.file_size, MAX_MANIFEST_BYTES))
            with bundle.open(info) as handle:
                data = handle.read(MAX_MANIFEST_BYTES + 1)
            if len(data) > MAX_MANIFEST_BYTES:
                raise ProtoError("%s is over the %d byte limit." % (MANIFEST_ENTRY, MAX_MANIFEST_BYTES))
            return data
    except zipfile.BadZipFile as error:
        raise ProtoError("%s is not a zip file (%s)." % (path, error))


def check_facts(facts: dict, minimum: int) -> tuple[bool, list[str]]:
    """Applies the two rules plus the INTERNET sanity check. Returns (ok, messages)."""
    ok = True
    messages: list[str] = []
    target = facts["target_sdk"]
    permissions = facts["permissions"]
    if target is None:
        ok = False
        messages.append("[FAIL] targetSdkVersion is not declared in the bundle manifest.")
    elif target < minimum:
        ok = False
        messages.append("[FAIL] targetSdkVersion = %d, below the required minimum %d." % (target, minimum))
    else:
        messages.append("[OK] targetSdkVersion = %d (minimum %d)." % (target, minimum))
    # PR #490 7.7.1: "AD_ID absent" is only evidence if the permission list was actually read. The app
    # cannot work without INTERNET, so a list without it means the reader missed the permissions.
    if INTERNET_PERMISSION not in permissions:
        ok = False
        messages.append("[FAIL] %s not found (%d permissions read): the permission list was not read, "
                        "so AD_ID cannot be checked." % (INTERNET_PERMISSION, len(permissions)))
    elif any(p.lower() == AD_ID_PERMISSION.lower() for p in permissions):
        ok = False
        messages.append("[FAIL] %s is present (advertising ID requested)." % AD_ID_PERMISSION)
    else:
        messages.append("[OK] %s absent (%d permissions read)." % (AD_ID_PERMISSION, len(permissions)))
    return ok, messages


def check_aab(path: Path, minimum: int) -> tuple[bool, list[str]]:
    """Reads the bundle and applies the rules. Raises FileNotFoundError or ProtoError when unreadable."""
    if not path.exists():
        raise FileNotFoundError("Bundle not found: %s" % path)
    return check_facts(get_manifest_facts(read_aab_manifest(path.resolve())), minimum)


# ---- crafted-manifest encoder (self-test and unit tests) ------------------------------------------

def enc_varint(value: int) -> bytes:
    out = bytearray()
    value &= 0xFFFFFFFFFFFFFFFF
    while value >= 0x80:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def enc_len_field(number: int, body: bytes) -> bytes:
    return enc_varint((number << 3) | 2) + enc_varint(len(body)) + body


def enc_var_field(number: int, value: int) -> bytes:
    return enc_varint(number << 3) + enc_varint(value)


def enc_str(number: int, text: str) -> bytes:
    return enc_len_field(number, text.encode("utf-8"))


def enc_attr(name: str, value: str, int_value: int | None = None) -> bytes:
    body = enc_str(2, name)
    if int_value is not None:
        body += enc_len_field(6, enc_len_field(7, enc_var_field(6, int_value)))
    else:
        body += enc_str(3, value)
    return enc_len_field(4, body)


def enc_element(name: str, attrs: bytes = b"", children: bytes = b"") -> bytes:
    return enc_len_field(1, enc_str(3, name) + attrs + children)  # XmlNode { element = 1 }


def build_manifest(target: int | None, permissions: list[str]) -> bytes:
    """A crafted proto manifest: an optional uses-sdk target and one uses-permission per name."""
    kids = b""
    if target is not None:
        kids += enc_len_field(5, enc_element("uses-sdk", enc_attr("targetSdkVersion", str(target), target)))
    for name in permissions:
        kids += enc_len_field(5, enc_element("uses-permission", enc_attr("name", name)))
    return enc_element("manifest", b"", kids)


# ---- self-test and entry point ---------------------------------------------------------------------

def find_real_bundle() -> Path | None:
    dist = SCRIPT_DIR.parent / "dist"
    if not dist.is_dir():
        return None
    candidates = [p for p in dist.rglob("app-prod-release.aab") if p.is_file()]
    return max(candidates, key=lambda p: p.stat().st_mtime) if candidates else None


def run_self_test(aab_path: Path | None, minimum: int) -> int:
    failures = 0

    def expect(name: str, condition: bool) -> None:
        nonlocal failures
        if condition:
            print("[SELFTEST OK]   %s" % name)
        else:
            print("[SELFTEST FAIL] %s" % name)
            failures += 1

    real = aab_path or find_real_bundle()
    if real is None or not real.exists():
        print("[SELFTEST FAIL] No real bundle found under mobile-app/dist/android-*/app-prod-release.aab. "
              "Build one with build-with-secrets.py --output aab or pass --aab-path.")
        return 1
    print("[INFO] Real bundle: %s" % real)
    try:
        ok, messages = check_aab(real, minimum)
        for message in messages:
            print("         %s" % message)
        expect("real bundle passes (min %d)" % minimum, ok)
        expect("real bundle FAILS the SDK rule with --min-target-sdk 1000", not check_aab(real, 1000)[0])
    except (FileNotFoundError, ProtoError, OSError) as error:
        print("[SELFTEST FAIL] real bundle could not be read: %s" % error)
        failures += 1
    internet = [INTERNET_PERMISSION]
    cases = [
        ("crafted good (36, no AD_ID)", 36, internet, True),
        ("crafted old target (35) fails", 35, internet, False),
        ("crafted AD_ID present fails", 36, internet + [AD_ID_PERMISSION], False),
        ("crafted missing uses-sdk target fails", None, internet, False),
        ("crafted target 37 passes", 37, internet, True),
        ("crafted NO permissions read fails", 36, [], False),
    ]
    for name, target, permissions, want in cases:
        facts = get_manifest_facts(build_manifest(target, permissions))
        expect(name, check_facts(facts, minimum)[0] == want)
    if failures:
        print("[SELFTEST] %d expectation(s) failed." % failures)
        return 1
    print("[SELFTEST] All expectations held.")
    return 0


def main(argv: list[str] | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    parser = argparse.ArgumentParser(description="Verify Google Play requirements on a built .aab.")
    parser.add_argument("--aab-path", type=Path, help="path to the built .aab (required unless --self-test)")
    parser.add_argument("--min-target-sdk", type=int, default=36, help="minimum targetSdkVersion (36)")
    parser.add_argument("--self-test", action="store_true", help="run against the real bundle and crafted ones")
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test(args.aab_path, args.min_target_sdk)
    if args.aab_path is None:
        print("[ERROR] --aab-path is required (or use --self-test).")
        return 2
    try:
        ok, messages = check_aab(args.aab_path, args.min_target_sdk)
    except (FileNotFoundError, ProtoError, OSError) as error:
        print("[ERROR] Could not read the bundle manifest: %s" % error)
        return 2
    print("[INFO] Play requirements check on %s" % args.aab_path)
    for message in messages:
        print("       %s" % message)
    if not ok:
        print("[FAIL] Bundle does not meet Google Play requirements.")
        return 1
    print("[OK] Bundle meets the checked Google Play requirements.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

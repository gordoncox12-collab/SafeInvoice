#!/usr/bin/env python3
"""Post-process a Flutter/AGP release APK for OEM sideload installers.

AGP 9 + minSdk 24+ emits a v2-only (or v1-invalid) APK. This script:
1. Rewrites AndroidManifest minSdk 24 -> 23 so apksigner reports v1+v2
2. zipaligns to 4 bytes
3. Signs with apksigner --v1-signing-enabled true --v2-signing-enabled true
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import zipfile


MINSDK_24 = bytes.fromhex("0800001018000000")
MINSDK_23 = bytes.fromhex("0800001017000000")


def find_sdk_tool(name: str) -> str:
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        raise SystemExit("ANDROID_HOME is not set")
    build_tools = os.path.join(sdk, "build-tools")
    versions = sorted(
        d for d in os.listdir(build_tools) if os.path.isdir(os.path.join(build_tools, d))
    )
    if not versions:
        raise SystemExit("No Android build-tools installed")
    latest = os.path.join(build_tools, versions[-1], name)
    if not os.path.exists(latest):
        raise SystemExit(f"Missing {latest}")
    return latest


def patch_minsdk(manifest: bytes) -> bytes:
    if MINSDK_23 in manifest:
        return bytes(manifest)
    count = manifest.count(MINSDK_24)
    if count == 0:
        return bytes(manifest)
    if count != 1:
        raise SystemExit(f"Refusing to patch minSdk: found {count} copies of SDK 24 typed value")
    return manifest.replace(MINSDK_24, MINSDK_23, 1)


def rewrite_apk(src: str, dest: str) -> None:
    with zipfile.ZipFile(src, "r") as zin, zipfile.ZipFile(dest, "w") as zout:
        for item in zin.infolist():
            name = item.filename
            if name.startswith("META-INF/") and name.endswith((".SF", ".RSA", ".DSA", ".EC", "MANIFEST.MF")):
                continue
            payload = zin.read(name)
            if name == "AndroidManifest.xml":
                payload = patch_minsdk(payload)
            zout.writestr(item, payload)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--in", dest="inp", required=True)
    parser.add_argument("--out", dest="outp", required=True)
    parser.add_argument("--ks", required=True)
    parser.add_argument("--ks-pass", required=True)
    parser.add_argument("--key-alias", required=True)
    parser.add_argument("--key-pass", required=True)
    args = parser.parse_args()
    if not os.path.isfile(args.inp):
        raise SystemExit(f"APK not found: {args.inp}")

    zipalign = find_sdk_tool("zipalign")
    apksigner = find_sdk_tool("apksigner")
    with tempfile.TemporaryDirectory() as tmp:
        unsigned = os.path.join(tmp, "unsigned.apk")
        aligned = os.path.join(tmp, "aligned.apk")
        rewrite_apk(args.inp, unsigned)
        subprocess.check_call([zipalign, "-f", "-p", "4", unsigned, aligned])
        subprocess.check_call(
            [
                apksigner,
                "sign",
                "--ks",
                args.ks,
                "--ks-key-alias",
                args.key_alias,
                "--ks-pass",
                f"pass:{args.ks_pass}",
                "--key-pass",
                f"pass:{args.key_pass}",
                "--v1-signing-enabled",
                "true",
                "--v2-signing-enabled",
                "true",
                "--v3-signing-enabled",
                "false",
                "--out",
                args.outp,
                aligned,
            ]
        )
    print(f"Signed sideload APK with v1+v2: {args.outp}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

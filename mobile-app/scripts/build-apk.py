"""Build the release APK with credentials (F335, Sprint 85). Python port of build-apk.ps1 (ADR-0051).

The PowerShell script ran a bare `flutter build apk`. With the dev and prod product flavors that command has no
target, and without the secrets file it would build a credential-less APK (the F119 class). This wrapper keeps one
credentialed build path: it runs build-with-secrets.py with --build-type release --output apk.

Options (kebab-case of the PowerShell parameters of the same name):
  --project-path PATH    the Flutter project folder (default: mobile-app)     (-ProjectPath)
  --verbose-output       run flutter analyze first and stop on a failure     (-VerboseOutput)

Exit codes: 0 success; 1 a refusal or a failed step; flutter's own code when flutter fails; 2 a usage error.
"""
from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
DEFAULT_PROJECT = SCRIPTS.parent


def load_builder():
    """build-with-secrets.py has a hyphen in its name, so it is loaded by path."""
    spec = importlib.util.spec_from_file_location("build_with_secrets", SCRIPTS / "build-with-secrets.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="build-apk.py", description="Build the release APK with credentials.")
    parser.add_argument("--project-path", type=Path, default=DEFAULT_PROJECT)
    parser.add_argument("--verbose-output", action="store_true")
    args = parser.parse_args(argv)

    builder = load_builder()
    project = args.project_path.resolve()
    print(f"Project: {project}", flush=True)
    if args.verbose_output:
        flutter = builder.common.find_tool("flutter")
        if not flutter:
            print("[ERROR] flutter not found on PATH.", flush=True)
            return 1
        code = builder.run_inherit([flutter, "analyze"], cwd=project)
        if code != 0:
            print("[ERROR] flutter analyze failed.", flush=True)
            return code
    return builder.main(["--build-type", "release", "--output", "apk"], mobile_app=project)


if __name__ == "__main__":
    sys.exit(main())

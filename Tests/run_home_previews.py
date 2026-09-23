"""Build a separate, Firebase-free preview host for manual HomeView verification.

Requires an already booted iOS Simulator. Copies the working source into a
temporary directory; never changes the real app entry point or Xcode project.
Screenshots require visual review and are not automated UI assertions.
"""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def run(*command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True, help="Booted simulator UDID")
    parser.add_argument("--output", required=True, type=Path, help="Logs and screenshots directory")
    parser.add_argument("--packages", type=Path, help="Existing resolved SourcePackages directory")
    args = parser.parse_args()
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "booted", "--json"]))
    if not any(device["udid"] == args.simulator for group in devices["devices"].values() for device in group):
        parser.error("The requested simulator must already be booted")

    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bundle_id = "com.sportili.local-home-preview"

    with tempfile.TemporaryDirectory(prefix="sportili-home-preview-") as directory:
        work = Path(directory)
        shutil.copytree(root / "SportiliApp", work / "SportiliApp")
        shutil.copytree(root / "SportiliApp.xcodeproj", work / "SportiliApp.xcodeproj",
                        ignore=shutil.ignore_patterns("xcuserdata"))
        entry = work / "SportiliApp/SportiliAppApp.swift"
        original = entry.read_text()
        before, marker, remaining = original.partition("@main\nstruct SportiliAppApp: App {")
        _, modifier_marker, modifiers = remaining.partition("\nstruct MontserratFontModifier:")
        if not marker or not modifier_marker:
            raise SystemExit("App entry point changed; review this preview runner before using it.")
        host = (root / "Tests/HomePreviewHost.swift").read_text()
        entry.write_text(before + host + modifier_marker + modifiers)

        command = [
            "xcodebuild", "-project", str(work / "SportiliApp.xcodeproj"),
            "-scheme", "SportiliApp", "-configuration", "Debug",
            "-destination", f"platform=iOS Simulator,id={args.simulator}",
            "-derivedDataPath", str(work / "DerivedData"),
            "-disableAutomaticPackageResolution", "CODE_SIGNING_ALLOWED=NO",
            f"PRODUCT_BUNDLE_IDENTIFIER={bundle_id}", "build",
        ]
        if args.packages:
            command[1:1] = ["-clonedSourcePackagesDirPath", str(args.packages.resolve())]
        with (output / "build.log").open("w") as log:
            run(*command, stdout=log, stderr=subprocess.STDOUT)
        app = work / "DerivedData/Build/Products/Debug-iphonesimulator/SportiliApp.app"
        run("xcrun", "simctl", "install", args.simulator, str(app))
        try:
            for scenario in ("last-week", "expired", "requested"):
                subprocess.run(["xcrun", "simctl", "terminate", args.simulator, bundle_id],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                run("xcrun", "simctl", "launch", args.simulator, bundle_id, f"--scenario={scenario}")
                time.sleep(3)  # Wait for the first frame and navigation transition.
                image = output / f"{scenario}.png"
                run("xcrun", "simctl", "io", args.simulator, "screenshot", str(image))
                print(f"REVIEW: {image}", flush=True)
        finally:
            run("xcrun", "simctl", "uninstall", args.simulator, bundle_id)


if __name__ == "__main__":
    main()

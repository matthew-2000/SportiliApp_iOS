"""Build a Firebase-free exercise host and capture the IOS-03 visual states.

Requires an already booted iOS Simulator. The project is copied to a temporary
directory; the production entry point and project are never modified.
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
    parser.add_argument("--only", choices=(
        "day", "exercise", "fullscreen", "empty", "history", "timer",
        "weight-keyboard", "saving", "font", "dark",
    ), help="Capture one scenario instead of the complete set")
    args = parser.parse_args()

    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "booted", "--json"]))
    if not any(device["udid"] == args.simulator for group in devices["devices"].values() for device in group):
        parser.error("The requested simulator must already be booted")

    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bundle_id = "com.sportili.local-exercise-preview"

    with tempfile.TemporaryDirectory(prefix="sportili-exercise-preview-") as directory:
        work = Path(directory)
        shutil.copytree(root / "SportiliApp", work / "SportiliApp")
        shutil.copytree(
            root / "SportiliApp.xcodeproj",
            work / "SportiliApp.xcodeproj",
            ignore=shutil.ignore_patterns("xcuserdata"),
        )
        entry = work / "SportiliApp/SportiliAppApp.swift"
        original = entry.read_text()
        before, marker, remaining = original.partition("@main\nstruct SportiliAppApp: App {")
        _, modifier_marker, modifiers = remaining.partition("\nstruct MontserratFontModifier:")
        if not marker or not modifier_marker:
            raise SystemExit("App entry point changed; review this preview runner before using it.")
        host = (root / "Tests/ExercisePreviewHost.swift").read_text()
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
            scenarios = args.only and (args.only,) or (
                "day", "exercise", "fullscreen", "empty", "history", "timer", "weight-keyboard",
                "saving", "font", "dark",
            )
            for scenario in scenarios:
                subprocess.run(
                    ["xcrun", "simctl", "terminate", args.simulator, bundle_id],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                run(
                    "xcrun", "simctl", "launch", args.simulator, bundle_id,
                    "--local-preview", f"--scenario={scenario}",
                )
                time.sleep(4)
                image = output / f"{scenario}.png"
                run("xcrun", "simctl", "io", args.simulator, "screenshot", str(image))
                print(f"REVIEW: {image}", flush=True)
        finally:
            run("xcrun", "simctl", "uninstall", args.simulator, bundle_id)


if __name__ == "__main__":
    main()

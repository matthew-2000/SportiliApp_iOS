"""Run production iOS Firebase code against local Auth and RTDB emulators."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import urllib.request

PROJECT = "demo-sportili-compat"

def run(*command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", help="Booted simulator UDID; defaults to the only booted iOS simulator")
    args = parser.parse_args()
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "booted", "--json"]))
    booted = [d["udid"] for runtime in devices["devices"].values() for d in runtime if d.get("state") == "Booted" and "watchOS" not in runtime]
    simulator = args.simulator or (booted[0] if len(booted) == 1 else None)
    if not simulator or simulator not in booted:
        parser.error("Select exactly one booted iOS Simulator with --simulator or IOS_SIMULATOR_UDID")

    root = Path(__file__).resolve().parents[1]
    bundle = "com.sportili.local-firebase-sdk"
    with tempfile.TemporaryDirectory(prefix="sportili-ios-sdk-") as directory:
        work = Path(directory)
        shutil.copytree(root / "SportiliApp", work / "SportiliApp")
        shutil.copytree(root / "SportiliApp.xcodeproj", work / "SportiliApp.xcodeproj", ignore=shutil.ignore_patterns("xcuserdata"))
        original = (work / "SportiliApp/SportiliAppApp.swift").read_text()
        _, marker, modifiers = original.partition("struct MontserratFontModifier:")
        if not marker:
            raise SystemExit("App entry point changed; review the SDK runner.")
        host = (root / "Tests/FirebaseSDKHost.swift").read_text()
        (work / "SportiliApp/SportiliAppApp.swift").write_text(host + "\nstruct MontserratFontModifier:" + modifiers)
        command = ["xcodebuild", "-quiet"]
        package_dirs = list((Path.home() / "Library/Developer/Xcode/DerivedData").glob(
            "SportiliApp-*/SourcePackages"
        ))
        if package_dirs:
            command += ["-clonedSourcePackagesDirPath", str(package_dirs[0])]
        command += [
            "-project", str(work / "SportiliApp.xcodeproj"), "-scheme", "SportiliApp",
            "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={simulator}",
            "-derivedDataPath", str(work / "DerivedData"), "-disableAutomaticPackageResolution",
            f"PRODUCT_BUNDLE_IDENTIFIER={bundle}", "build"
        ]
        build = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if build.returncode:
            print(build.stdout)
            raise SystemExit(build.returncode)
        app = work / "DerivedData/Build/Products/Debug-iphonesimulator/SportiliApp.app"
        run("xcrun", "simctl", "install", simulator, str(app))
        try:
            run("xcrun", "simctl", "launch", simulator, bundle)
            endpoint = f"http://127.0.0.1:19000/integrationResults/ios.json?ns={PROJECT}"
            deadline = time.time() + 30
            while time.time() < deadline:
                with urllib.request.urlopen(endpoint) as response:
                    result = json.load(response)
                if result:
                    if result != "PASS": raise SystemExit(result)
                    print("PASS: iOS Firebase Auth/RTDB SDK login, retry, user switch, realtime and note preservation")
                    return
                time.sleep(.25)
            raise SystemExit("Timed out waiting for the iOS Firebase SDK test host")
        finally:
            run("xcrun", "simctl", "uninstall", simulator, bundle)

if __name__ == "__main__":
    main()

"""Run with local Auth/RTDB emulators (Tests/WatchEmulator/firebase.json).

No production configs are used at runtime. Writes target demo-sportili-watch on loopback.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--simulator', required=True)
parser.add_argument('--packages', help='Existing Xcode SourcePackages directory')
args = parser.parse_args()
bundle = 'com.sportili.local-watch-sdk'

def run(*cmd, **kwargs):
    return subprocess.run(cmd, check=True, **kwargs)

with tempfile.TemporaryDirectory(prefix='sportili-watch-sdk-') as directory:
    work = Path(directory)
    for name in ['SportiliApp', 'CompanionShared', 'PhoneCompanion', 'SportiliWatch', 'SportiliApp.xcodeproj']:
        shutil.copytree(root / name, work / name, ignore=shutil.ignore_patterns('xcuserdata'))
    original = (work / 'SportiliApp/SportiliAppApp.swift').read_text()
    _, marker, theme = original.partition('struct MontserratFontModifier:')
    if not marker:
        raise SystemExit('App entry changed; review local test host')
    (work / 'SportiliApp/SportiliAppApp.swift').write_text(
        (root / 'Tests/WatchFirebaseHost.swift').read_text() + '\nstruct MontserratFontModifier:' + theme)
    run('swift', 'run', '--package-path', str(root / 'Tools/WatchProjectSetup'), 'xcode_spm_setup', str(work / 'SportiliApp.xcodeproj'), '--test-host')
    command = ['xcodebuild', '-quiet', '-project', str(work / 'SportiliApp.xcodeproj'), '-scheme', 'SportiliApp',
               '-configuration', 'Debug', '-destination', f'platform=iOS Simulator,id={args.simulator}',
               '-derivedDataPath', str(work / 'DerivedData'), 'build']
    if args.packages:
        command += ['-clonedSourcePackagesDirPath', args.packages, '-disableAutomaticPackageResolution']
    build = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if build.returncode:
        print(build.stdout)
        raise SystemExit(build.returncode)
    app = work / 'DerivedData/Build/Products/Debug-iphonesimulator/SportiliApp.app'
    result = work / 'result.txt'
    run('xcrun', 'simctl', 'install', args.simulator, str(app))
    try:
        import os
        env = dict(os.environ, SIMCTL_CHILD_WATCH_TEST_RESULT=str(result))
        run('xcrun', 'simctl', 'launch', args.simulator, bundle, env=env)
        deadline = time.time() + 40
        while time.time() < deadline and not result.exists():
            time.sleep(.25)
        if not result.exists():
            raise SystemExit('Local test host timed out')
        message = result.read_text()
        print(message)
        if message != 'PASS':
            raise SystemExit(1)
        print('PASS: native Firebase transactions, retries, conflict preservation, offline ACK/reconnect, denied write, legacy history and user isolation')
    finally:
        run('xcrun', 'simctl', 'uninstall', args.simulator, bundle)

"""Keep existing iPhone-only fixture runners independent of the embedded Watch target."""
import shutil
import subprocess


def prepare_phone_fixture_project(root, work):
    for name in ('CompanionShared', 'PhoneCompanion', 'SportiliWatch'):
        shutil.copytree(root / name, work / name)
    subprocess.run([
        'swift', 'run', '--package-path', str(root / 'Tools/WatchProjectSetup'),
        'xcode_spm_setup', str(work / 'SportiliApp.xcodeproj'), '--phone-only-test'
    ], check=True, stdout=subprocess.DEVNULL)

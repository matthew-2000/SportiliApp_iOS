"""Build/test a temporary Firebase-free copy with the real login/tab/day/detail routes.

Never edits the production project or configures Firebase. Requires Ruby xcodeproj,
an already booted Simulator and resolved SourcePackages. XCTest results are saved
in --output. Leave --keep-installed only for interactive QA; uninstall afterwards.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def replace(path, before, after):
    value = path.read_text()
    if before not in value:
        raise RuntimeError(f"Fixture seam changed in {path.name}: {before}")
    path.write_text(value.replace(before, after))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--packages", type=Path, required=True)
    parser.add_argument("--derived-data", type=Path, required=True)
    parser.add_argument("--keep-installed", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--only-testing", action="append", default=[])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    bundle = "com.sportili.local-s11-preview"
    with tempfile.TemporaryDirectory(prefix="sportili-s11-") as directory:
        work = Path(directory)
        shutil.copytree(root / "SportiliApp", work / "SportiliApp")
        shutil.copytree(root / "SportiliApp.xcodeproj", work / "SportiliApp.xcodeproj", ignore=shutil.ignore_patterns("xcuserdata"))
        entry = work / "SportiliApp/SportiliAppApp.swift"
        before, marker, remaining = entry.read_text().partition("@main\nstruct SportiliAppApp: App {")
        _, modifier, modifiers = remaining.partition("\nstruct MontserratFontModifier:")
        if not marker or not modifier: raise RuntimeError("Entry point changed")
        entry.write_text(before + (root / "Tests/S11PreviewHost.swift").read_text() + modifier + modifiers)
        # Substitute dependencies in the temporary copy. Production control flow/layout stay real.
        content = work / "SportiliApp/User/ContentView.swift"
        replace(content, "HomeView()", 'HomeView(schedaViewModel: S11Fixture.model, previewUserName: "Matteo")')
        replace(content, "AlertsView()", "AlertsView(viewModel: S11Fixture.alerts)")
        replace(content, "SettingsView()", "SettingsView(signOut: {}, clearSessionDefaults: {})")
        home = work / "SportiliApp/User/HomeView.swift"
        replace(home, "DayView(day: giorno)", "DayView(day: giorno, detailViewModel: S11Fixture.details, imageLoaderFactory: S11Fixture.image, autoLoadImages: false)")
        replace(home, "schedaViewModel.fetchScheda", "S11Fixture.retry")
        settings = work / "SportiliApp/User/SettingsView.swift"
        replace(settings, "LoginView()", "LoginView(login: S11Fixture.login())")
        day = work / "SportiliApp/User/DayView.swift"
        replace(day, "autoLoadImage: autoLoadImages\n", "autoLoadImage: autoLoadImages, actions: S11Fixture.actions\n")
        model = work / "SportiliApp/Model/ExerciseDetailViewModel.swift"
        with model.open("a") as handle:
            handle.write('''\nextension ExerciseDetailViewModel {
    func applyS11Fixture(_ key: String, note: String?, entry: WeightLog? = nil) {
        modifyLocalData(for: key) { old in
            var next = old
            if let entry { next.weightLogs[entry.id] = entry } else { next.noteUtente = note }
            return next
        }
    }
}\n''')
        test_dir = work / "S11UITests"; test_dir.mkdir()
        shutil.copy(root / "Tests/S11UITests.swift", test_dir)
        ruby = work / "add_tests.rb"
        ruby.write_text('''gem 'rexml', '3.4.1'
require 'xcodeproj'
p = Xcodeproj::Project.open(ARGV[0])
app = p.targets.find { |t| t.name == 'SportiliApp' }
app.build_configurations.each { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.sportili.local-s11-preview' }
t = p.new_target(:ui_test_bundle, 'S11UITests', :ios, '16.0')
t.add_dependency(app)
group = p.main_group.new_group('S11UITests', 'S11UITests')
t.add_file_references([group.new_file('S11UITests.swift')])
t.build_configurations.each do |c|
  c.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  c.build_settings['TEST_TARGET_NAME'] = 'SportiliApp'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.sportili.local-s11-uitests'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
end
s = Xcodeproj::XCScheme.new
s.add_build_target(app)
s.add_build_target(t)
s.add_test_target(t)
s.set_launch_target(app)
s.save_as(p.path, 'S11QA', true)
p.save
''')
        subprocess.run(["ruby", str(ruby), str(work / "SportiliApp.xcodeproj")], check=True)
        command = ["xcodebuild", "-jobs", "2", "-project", str(work / "SportiliApp.xcodeproj"), "-scheme", "S11QA", "-configuration", "Debug",
            "-destination", f"platform=iOS Simulator,id={args.simulator}", "-derivedDataPath", str(args.derived_data.resolve()),
            "-clonedSourcePackagesDirPath", str(args.packages.resolve()), "-disableAutomaticPackageResolution",
            "CODE_SIGNING_ALLOWED=NO"]
        if args.build_only: command += ["build-for-testing"]
        else:
            command += ["-collect-test-diagnostics", "never", "-parallel-testing-enabled", "NO", "-resultBundlePath", str(output / "S11.xcresult")]
            command += ["-only-testing:" + test for test in args.only_testing]
            command += ["test"]
        with (output / "build-test.log").open("w") as log:
            subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
        if args.build_only:
            app = args.derived_data.resolve() / "Build/Products/Debug-iphonesimulator/SportiliApp.app"
            subprocess.run(["xcrun", "simctl", "install", args.simulator, str(app)], check=True)
        if not args.keep_installed:
            subprocess.run(["xcrun", "simctl", "uninstall", args.simulator, bundle], check=True)


if __name__ == "__main__": main()

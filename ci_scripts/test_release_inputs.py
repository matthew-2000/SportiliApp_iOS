from pathlib import Path
import tempfile
import unittest
from release_inputs import resolve


class ReleaseInputTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "release-notes").mkdir()
        (self.root / "release-notes/2.1.1.json").write_text('{"it-IT":"Novità"}')
        (self.root / "SportiliApp.xcodeproj").mkdir()
        (self.root / "SportiliApp.xcodeproj/project.pbxproj").write_text('MARKETING_VERSION = 2.1.1;\nMARKETING_VERSION = 2.1.1;')
        self.env = {"GITHUB_SHA": "a" * 40, "GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/tags/v2.1.1"}

    def test_tag_defaults_to_phased_release(self):
        self.assertEqual(resolve(self.env, self.root, "a" * 40, "a" * 40), {
            "version": "2.1.1", "notes_file": "release-notes/2.1.1.json", "phased_release": "true"})

    def test_wrong_commit_or_prerelease_tag_rejected(self):
        for change in ({"GITHUB_SHA": "b" * 40}, {"GITHUB_REF": "refs/tags/v2.1.1-rc1"}, {"GITHUB_REF": "refs/heads/test"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                resolve(self.env | change, self.root, "a" * 40, "a" * 40)

    def test_mismatched_xcode_version_rejected(self):
        (self.root / "SportiliApp.xcodeproj/project.pbxproj").write_text('MARKETING_VERSION = 2.1.0;')
        with self.assertRaises(ValueError):
            resolve(self.env, self.root, "a" * 40, "a" * 40)

    def test_manual_main_full_release(self):
        env = self.env | {"GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_REF": "refs/heads/main",
            "RELEASE_VERSION": "2.1.1", "NOTES_FILE": "release-notes/2.1.1.json", "PHASED_RELEASE": "false"}
        self.assertEqual(resolve(env, self.root, "a" * 40, "a" * 40)["phased_release"], "false")

import base64
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from app_store_release import BUNDLE, listing, parameters, prepare, raw_signature, submit, token


class FakeApple:
    def __init__(self):
        self.calls = []
        self.commit = "a" * 40
        self.status = "SUCCEEDED"
        self.audience = "APP_STORE_ELIGIBLE"
        self.encryption = False
        self.review_state = None
        self.version_state = "PREPARE_FOR_SUBMISSION"
        self.version_exists = True
        self.notes_locale = "it-IT"

    def __call__(self, method, path, payload=None):
        self.calls.append((method, path, payload))
        if path == "/v1/apps/app":
            data = {"id": "app", "attributes": {"bundleId": BUNDLE}}
        elif path.startswith("/v1/ciBuildRuns/run?") or path == "/v1/ciBuildRuns/run":
            data = {"id": "run", "attributes": {"completionStatus": self.status,
                "executionProgress": "COMPLETE", "sourceCommit": {"commitSha": self.commit}, "isPullRequestBuild": False},
                "relationships": {"workflow": {"data": {"id": "workflow"}}, "sourceBranchOrTag": {"data": {"id": "main"}}}}
        elif path == "/v1/scmGitReferences/main":
            data = {"id": "main", "attributes": {"canonicalName": "refs/heads/main", "isDeleted": False}}
        elif path == "/v1/ciBuildRuns" and method == "POST":
            data = {"id": "run"}
        elif path == "/v1/ciBuildRuns/run/builds":
            data = [{"id": "build", "attributes": {"processingState": "VALID"}}]
        elif path == "/v1/builds/build":
            data = {"id": "build", "attributes": {"version": "18", "processingState": "VALID",
                "expired": False, "buildAudienceType": self.audience, "usesNonExemptEncryption": self.encryption}}
        elif path == "/v1/builds/build/app":
            data = {"id": "app"}
        elif path == "/v1/builds/build/preReleaseVersion":
            data = {"attributes": {"version": "2.1.1", "platform": "IOS"}}
        elif path == "/v1/apps/app/reviewSubmissions":
            data = [] if self.review_state is None else [{"attributes": {"platform": "IOS", "state": self.review_state}}]
        elif path == "/v1/apps/app/appStoreVersions?filter[platform]=IOS":
            data = [{"id": "version", "attributes": {"versionString": "2.1.1", "appVersionState": self.version_state}}] if self.version_exists else []
        elif path == "/v1/appStoreVersions" and method == "POST":
            data = {"id": "version"}
        elif path == "/v1/appStoreVersions/version/appStoreVersionLocalizations":
            data = [{"id": "locale", "attributes": {"locale": self.notes_locale}}]
        elif path == "/v1/appStoreVersions/version?include=appStoreVersionPhasedRelease":
            data = {"id": "version"}
        elif path == "/v1/reviewSubmissions" and method == "POST":
            data = {"id": "review"}
        elif method in ("PATCH", "POST", "DELETE"):
            data = {}
        else:
            raise AssertionError(f"Unexpected request: {method} {path}")
        return {"data": data}


class AppStoreTests(unittest.TestCase):
    def setUp(self):
        self.api = FakeApple()
        self.config = {"app_id": "app", "version": "2.1.1", "commit": "a" * 40,
            "workflow_id": "workflow", "git_ref_id": "main", "notes": {"it-IT": "Miglioramenti."}, "phased": True}
        self.plan = self.config | {"run_id": "run", "build_id": "build", "build_number": "18"}

    def writes(self):
        return [c for c in self.api.calls if c[0] != "GET"]

    def test_prepare_builds_on_cloud_without_review_submission(self):
        plan = prepare(self.api, self.config, pause=lambda _: None)
        self.assertEqual(plan, self.plan)
        self.assertEqual(len(self.writes()), 1)
        start = self.writes()[0]
        self.assertEqual(start[1], "/v1/ciBuildRuns")
        self.assertEqual(start[2]["data"]["relationships"]["sourceBranchOrTag"]["data"]["id"], "main")

    def test_direct_review_with_automatic_release_and_no_testflight(self):
        receipt = submit(self.api, self.plan)
        self.assertEqual(receipt["result"], "submitted-to-apple-review")
        self.assertEqual(self.writes()[-1][2]["data"]["attributes"], {"submitted": True})
        versions = [c for c in self.writes() if c[1] == "/v1/appStoreVersions/version"]
        self.assertEqual(versions[0][2]["data"]["attributes"]["releaseType"], "AFTER_APPROVAL")
        self.assertEqual(versions[0][2]["data"]["relationships"]["build"]["data"]["id"], "build")
        self.assertTrue(any(c[1] == "/v1/appStoreVersionPhasedReleases" for c in self.writes()))
        self.assertFalse(any("beta" in c[1].lower() for c in self.api.calls))

    def test_creates_missing_commercial_version(self):
        self.api.version_exists = False
        submit(self.api, self.plan)
        create = next(c for c in self.writes() if c[1] == "/v1/appStoreVersions")
        self.assertEqual(create[2]["data"]["attributes"]["versionString"], "2.1.1")

    def test_wrong_commit_failed_cloud_or_internal_build_prevents_writes(self):
        for key, value in (("commit", "b" * 40), ("status", "FAILED"), ("audience", "INTERNAL_ONLY"), ("encryption", None)):
            with self.subTest(key=key):
                self.api = FakeApple()
                setattr(self.api, key, value)
                with self.assertRaises(ValueError):
                    submit(self.api, self.plan)
                self.assertEqual(self.writes(), [])

    def test_pending_review_or_locked_version_prevents_writes(self):
        for key, value in (("review_state", "IN_REVIEW"), ("review_state", "READY_FOR_REVIEW"), ("version_state", "WAITING_FOR_REVIEW")):
            with self.subTest(key=key):
                self.api = FakeApple()
                setattr(self.api, key, value)
                with self.assertRaises(ValueError):
                    submit(self.api, self.plan)
                self.assertEqual(self.writes(), [])

    def test_missing_localized_notes_prevents_submission(self):
        self.api.notes_locale = "en-US"
        with self.assertRaisesRegex(ValueError, "locales"):
            submit(self.api, self.plan)
        self.assertEqual(self.writes(), [])

    def test_apple_validation_error_is_not_retried_or_hidden(self):
        def fail(method, path, payload=None):
            if path == "/v1/reviewSubmissions/review" and method == "PATCH":
                raise ValueError("Missing review contact")
            return self.api(method, path, payload)
        with self.assertRaisesRegex(ValueError, "Missing review contact"):
            submit(fail, self.plan)
        self.assertEqual(sum(c[1] == "/v1/reviewSubmissions" and c[0] == "POST" for c in self.api.calls), 1)

    def test_pagination(self):
        pages = {"/first": {"data": [1], "links": {"next": "/second"}}, "/second": {"data": [2]}}
        self.assertEqual(listing(lambda _, path: pages[path], "/first"), [1, 2])

    def test_parameter_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "release-notes").mkdir()
            (root / "release-notes/notes.json").write_text('{"it-IT": "Novità"}')
            env = {"RELEASE_VERSION": "2.1.1", "GITHUB_SHA": "a" * 40, "NOTES_FILE": "release-notes/notes.json",
                "ASC_APP_ID": "app", "XCODE_CLOUD_WORKFLOW_ID": "workflow", "XCODE_CLOUD_MAIN_REF_ID": "main"}
            self.assertEqual(parameters(env, root), self.config | {"notes": {"it-IT": "Novità"}})
            for key, value in (("RELEASE_VERSION", "bad"), ("GITHUB_SHA", "bad"), ("NOTES_FILE", "../notes"), ("PHASED_RELEASE", "yes")):
                with self.subTest(key=key), self.assertRaises(ValueError):
                    parameters(env | {key: value}, root)

    def test_real_openssl_jwt_signature(self):
        with tempfile.TemporaryDirectory() as directory:
            key = Path(directory) / "key.p8"
            subprocess.run(["openssl", "genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256", "-out", str(key)], check=True, capture_output=True)
            encoded = token({"ASC_ISSUER_ID": "issuer", "ASC_KEY_ID": "key", "ASC_PRIVATE_KEY_P8": key.read_text()})
            header, claims, signature = encoded.split(".")
            decoded = lambda part: base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))
            self.assertEqual(json.loads(decoded(header))["alg"], "ES256")
            self.assertEqual(json.loads(decoded(claims))["aud"], "appstoreconnect-v1")
            raw = decoded(signature)
            self.assertEqual(len(raw), 64)
            integers = []
            for half in (raw[:32], raw[32:]):
                number = half.lstrip(b"\0")
                if number[0] >= 128:
                    number = b"\0" + number
                integers.append(b"\x02" + bytes([len(number)]) + number)
            sequence = b"".join(integers)
            der = b"\x30" + bytes([len(sequence)]) + sequence
            self.assertEqual(raw_signature(der), raw)
            sig, public = Path(directory) / "signature", Path(directory) / "public.pem"
            sig.write_bytes(der)
            result = subprocess.run(["openssl", "pkey", "-in", str(key), "-pubout"], capture_output=True, check=True)
            public.write_bytes(result.stdout)
            subprocess.run(["openssl", "dgst", "-sha256", "-verify", str(public), "-signature", str(sig)],
                input=f"{header}.{claims}".encode(), capture_output=True, check=True)


if __name__ == "__main__":
    unittest.main()

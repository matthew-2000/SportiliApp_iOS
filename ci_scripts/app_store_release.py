"""Xcode Cloud compilation and direct App Store review submission via official APIs."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"
BUNDLE = "com.matthew.SportiliApp"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}


def resource(kind, identifier=None, attributes=None, relationships=None):
    data = {"type": kind}
    if identifier is not None:
        data["id"] = identifier
    if attributes is not None:
        data["attributes"] = attributes
    if relationships is not None:
        data["relationships"] = {key: {"data": {"type": typ, "id": ident}}
                                 for key, (typ, ident) in relationships.items()}
    return {"data": data}


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def raw_signature(der):
    # OpenSSL emits ASN.1 ECDSA-Sig-Value; ES256 JWT needs exactly 32-byte R and S.
    if len(der) < 8 or der[0] != 0x30 or der[1] != len(der) - 2:
        raise ValueError("Invalid ES256 signature sequence")
    pos, result = 2, b""
    for _ in range(2):
        if der[pos] != 2:
            raise ValueError("Invalid ES256 integer")
        size = der[pos + 1]
        number = der[pos + 2:pos + 2 + size].lstrip(b"\0")
        if not number or len(number) > 32:
            raise ValueError("Invalid ES256 integer size")
        result += number.rjust(32, b"\0")
        pos += size + 2
    if pos != len(der):
        raise ValueError("Invalid ES256 signature length")
    return result


def token(env):
    now = int(time.time())
    header = {"alg": "ES256", "kid": env["ASC_KEY_ID"], "typ": "JWT"}
    claims = {"iss": env["ASC_ISSUER_ID"], "iat": now - 20, "exp": now + 600,
              "aud": "appstoreconnect-v1"}
    message = b64(json.dumps(header).encode()) + "." + b64(json.dumps(claims).encode())
    with tempfile.TemporaryDirectory() as folder:
        key = Path(folder) / "AuthKey.p8"
        key.write_text(env["ASC_PRIVATE_KEY_P8"])
        key.chmod(0o600)
        signed = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key)],
                                input=message.encode(), capture_output=True)
        if signed.returncode:
            raise ValueError("Unable to sign App Store Connect JWT; check the P8 key")
    return message + "." + b64(raw_signature(signed.stdout))


class AppleAPI:
    def __init__(self, env):
        self.env = env

    def __call__(self, method, path, payload=None):
        url = API + path if path.startswith("/") else path
        if urllib.parse.urlsplit(url).netloc != "api.appstoreconnect.apple.com":
            raise ValueError("Unexpected API origin")
        headers = {"Authorization": "Bearer " + token(self.env), "Content-Type": "application/json"}
        req = urllib.request.Request(url, data=json.dumps(payload).encode() if payload else None,
                                     headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            try:
                errors = json.loads(error.read()).get("errors", [])
                details = "; ".join(f"{e.get('code')}: {e.get('detail', e.get('title', ''))}" for e in errors)
            except (ValueError, UnicodeError):
                details = "No structured error details"
            raise ValueError(f"Apple API HTTP {error.code}: {details[:2000]}") from None


def listing(api, path):
    rows = []
    while path:
        page = api("GET", path)
        rows.extend(page["data"])
        path = page.get("links", {}).get("next")
    return rows


def state(version):
    attrs = version["attributes"]
    return attrs.get("appVersionState") or attrs.get("appStoreState")


def parameters(env, root):
    version = env["RELEASE_VERSION"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Use major.minor.patch")
    if not re.fullmatch(r"[0-9a-f]{40}", env["GITHUB_SHA"]):
        raise ValueError("Expected full commit SHA")
    path = (root / env["NOTES_FILE"]).resolve()
    if not path.is_relative_to((root / "release-notes").resolve()):
        raise ValueError("Notes must be under release-notes/")
    notes = json.loads(path.read_text())
    if not isinstance(notes, dict) or not notes or any(
            not isinstance(k, str) or not isinstance(v, str) or not 1 <= len(v.strip()) <= 4000
            for k, v in notes.items()):
        raise ValueError("Notes must map locales to 1..4000 characters")
    phased = env.get("PHASED_RELEASE", "true")
    if phased not in ("true", "false"):
        raise ValueError("Invalid phased release flag")
    return {"app_id": env["ASC_APP_ID"], "version": version, "commit": env["GITHUB_SHA"],
            "workflow_id": env["XCODE_CLOUD_WORKFLOW_ID"],
            "git_ref_id": env["XCODE_CLOUD_MAIN_REF_ID"], "notes": notes, "phased": phased == "true"}


def check_app(api, app_id):
    if api("GET", f"/v1/apps/{app_id}")["data"]["attributes"]["bundleId"] != BUNDLE:
        raise ValueError("Unexpected app bundle identifier")


def check_run(api, run_id, plan):
    run = api("GET", f"/v1/ciBuildRuns/{run_id}?include=workflow,sourceBranchOrTag")["data"]
    attrs = run["attributes"]
    if attrs.get("completionStatus") != "SUCCEEDED" or attrs.get("executionProgress") != "COMPLETE":
        raise ValueError("Xcode Cloud run is not successfully complete")
    if attrs["sourceCommit"]["commitSha"] != plan["commit"] or attrs.get("isPullRequestBuild"):
        raise ValueError("Cloud run does not match the approved main commit")
    workflow = run["relationships"]["workflow"]["data"]
    ref = run["relationships"]["sourceBranchOrTag"]["data"]
    if workflow["id"] != plan["workflow_id"] or ref["id"] != plan["git_ref_id"]:
        raise ValueError("Unexpected Xcode Cloud workflow or source reference")


def check_build(api, build_id, plan):
    build = api("GET", f"/v1/builds/{build_id}")["data"]
    attrs = build["attributes"]
    if attrs.get("processingState") != "VALID" or attrs.get("expired"):
        raise ValueError("Build is not valid for distribution")
    if attrs.get("buildAudienceType") != "APP_STORE_ELIGIBLE":
        raise ValueError("Build must be eligible for the App Store, not internal-only")
    if attrs.get("usesNonExemptEncryption") is None:
        raise ValueError("Export compliance is missing; complete the actual declaration in Apple")
    app = api("GET", f"/v1/builds/{build_id}/app")["data"]
    version = api("GET", f"/v1/builds/{build_id}/preReleaseVersion")["data"]["attributes"]
    if app["id"] != plan["app_id"] or version["version"] != plan["version"] or version["platform"] != "IOS":
        raise ValueError("Build app, version or platform mismatch")
    return attrs["version"]


def prepare(api, config, pause=time.sleep, clock=time.monotonic, timeout=7200):
    check_app(api, config["app_id"])
    ref = api("GET", f"/v1/scmGitReferences/{config['git_ref_id']}")["data"]
    if ref["attributes"].get("canonicalName") != "refs/heads/main" or ref["attributes"].get("isDeleted"):
        raise ValueError("Configured source reference must be main")
    response = api("POST", "/v1/ciBuildRuns", resource("ciBuildRuns", attributes={}, relationships={
        "workflow": ("ciWorkflows", config["workflow_id"]),
        "sourceBranchOrTag": ("scmGitReferences", config["git_ref_id"])}))
    run_id = response["data"]["id"]
    print(f"Started Xcode Cloud run {run_id}", flush=True)
    deadline = clock() + timeout
    while clock() < deadline:
        run = api("GET", f"/v1/ciBuildRuns/{run_id}")["data"]["attributes"]
        if run.get("executionProgress") == "COMPLETE":
            check_run(api, run_id, config)
            builds = listing(api, f"/v1/ciBuildRuns/{run_id}/builds")
            candidates = []
            for build in builds:
                app = api("GET", f"/v1/builds/{build['id']}/app")["data"]
                if app["id"] == config["app_id"]:
                    candidates.append(build)
            if len(candidates) > 1:
                raise ValueError("Ambiguous App Store build for this Cloud run")
            if candidates:
                build = candidates[0]
                processing = build["attributes"].get("processingState")
                if processing in ("FAILED", "INVALID"):
                    raise ValueError("Apple build processing failed")
                if processing == "VALID":
                    number = check_build(api, build["id"], config)
                    return config | {"run_id": run_id, "build_id": build["id"], "build_number": number}
        pause(30)
    raise ValueError(f"Timed out waiting for Xcode Cloud/Apple processing; inspect run {run_id}. Do not submit another build blindly")


def submit(api, plan):
    check_app(api, plan["app_id"])
    check_run(api, plan["run_id"], plan)
    linked = listing(api, f"/v1/ciBuildRuns/{plan['run_id']}/builds")
    if plan["build_id"] not in [b["id"] for b in linked]:
        raise ValueError("Build is not an output of the approved Cloud run")
    if check_build(api, plan["build_id"], plan) != plan["build_number"]:
        raise ValueError("Build number changed")
    reviews = listing(api, f"/v1/apps/{plan['app_id']}/reviewSubmissions")
    # Do not append to, submit or cancel someone else's pending review batch.
    if any(r["attributes"].get("state") != "COMPLETE" for r in reviews):
        raise ValueError("A review submission already exists; resolve it in App Store Connect")
    versions = listing(api, f"/v1/apps/{plan['app_id']}/appStoreVersions?filter[platform]=IOS")
    matching = [v for v in versions if v["attributes"]["versionString"] == plan["version"]]
    if len(matching) > 1:
        raise ValueError("Ambiguous App Store version")
    if matching:
        version = matching[0]
        if state(version) not in EDITABLE:
            raise ValueError("App Store version is not editable; no duplicate submission")
    else:
        if any(state(v) in EDITABLE | {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE"} for v in versions):
            raise ValueError("Another iOS version is pending; do not replace it")
        version = api("POST", "/v1/appStoreVersions", resource("appStoreVersions", attributes={
            "platform": "IOS", "versionString": plan["version"], "releaseType": "AFTER_APPROVAL"},
            relationships={"app": ("apps", plan["app_id"])}))["data"]
    version_id = version["id"]
    locales = listing(api, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    existing = {loc["attributes"]["locale"] for loc in locales}
    if existing != set(plan["notes"]):
        raise ValueError(f"Provide release notes for exactly these existing store locales: {sorted(existing)}")
    for loc in locales:
        api("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", resource(
            "appStoreVersionLocalizations", loc["id"], {"whatsNew": plan["notes"][loc["attributes"]["locale"]]}))
    api("PATCH", f"/v1/appStoreVersions/{version_id}", resource("appStoreVersions", version_id,
        {"releaseType": "AFTER_APPROVAL"}, {"build": ("builds", plan["build_id"])}))
    version_detail = api("GET", f"/v1/appStoreVersions/{version_id}?include=appStoreVersionPhasedRelease")
    phased_rows = [r for r in version_detail.get("included", []) if r["type"] == "appStoreVersionPhasedReleases"]
    phased = phased_rows[0] if phased_rows else None
    if plan["phased"]:
        if phased:
            if phased["attributes"]["phasedReleaseState"] != "INACTIVE":
                raise ValueError("Phased release already started; refusing to modify it")
        else:
            api("POST", "/v1/appStoreVersionPhasedReleases", resource("appStoreVersionPhasedReleases",
                attributes={"phasedReleaseState": "INACTIVE"},
                relationships={"appStoreVersion": ("appStoreVersions", version_id)}))
    elif phased:
        if phased["attributes"]["phasedReleaseState"] != "INACTIVE":
            raise ValueError("Cannot remove an active phased release")
        api("DELETE", f"/v1/appStoreVersionPhasedReleases/{phased['id']}")
    review = api("POST", "/v1/reviewSubmissions", resource("reviewSubmissions", attributes={"platform": "IOS"},
        relationships={"app": ("apps", plan["app_id"])}))["data"]
    api("POST", "/v1/reviewSubmissionItems", resource("reviewSubmissionItems", relationships={
        "reviewSubmission": ("reviewSubmissions", review["id"]),
        "appStoreVersion": ("appStoreVersions", version_id)}))
    api("PATCH", f"/v1/reviewSubmissions/{review['id']}", resource("reviewSubmissions", review["id"], {"submitted": True}))
    return {"app_id": plan["app_id"], "version": plan["version"], "build_id": plan["build_id"],
            "commit": plan["commit"], "review_submission_id": review["id"], "releaseType": "AFTER_APPROVAL",
            "phased": plan["phased"], "result": "submitted-to-apple-review"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["validate", "prepare", "submit"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    config = parameters(os.environ, root)
    if args.action == "validate":
        print(json.dumps(config, indent=2, ensure_ascii=False))
        return
    api = AppleAPI(os.environ)
    output = root / "dist"
    output.mkdir(exist_ok=True)
    if args.action == "prepare":
        plan = prepare(api, config)
        (output / "release-plan.json").write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n")
        print(json.dumps(plan, indent=2, ensure_ascii=False))
    else:
        plan = json.loads((output / "release-plan.json").read_text())
        if any(plan.get(k) != value for k, value in config.items()):
            raise ValueError("Release inputs changed after preparation")
        receipt = submit(api, plan)
        (output / "app-store-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("Submitted to Apple review; automatic release after approval. No TestFlight distribution required.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(f"App Store release failed: {error}") from None

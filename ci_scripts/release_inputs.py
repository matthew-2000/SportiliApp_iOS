"""Resolve production tag/manual inputs; tags must identify current main."""
import os
from pathlib import Path
import re
import subprocess


def resolve(env, root, main_sha, head_sha):
    if env["GITHUB_SHA"] != main_sha or head_sha != main_sha:
        raise ValueError("Release must point to the current main commit")
    if env["GITHUB_EVENT_NAME"] == "push":
        match = re.fullmatch(r"refs/tags/v(\d+\.\d+\.\d+)", env["GITHUB_REF"])
        if not match:
            raise ValueError("Expected version tag vX.Y.Z")
        version = match[1]
        notes, phased = f"release-notes/{version}.json", "true"
    elif env["GITHUB_EVENT_NAME"] == "workflow_dispatch" and env["GITHUB_REF"] == "refs/heads/main":
        version, notes, phased = env["RELEASE_VERSION"], env["NOTES_FILE"], env["PHASED_RELEASE"]
    else:
        raise ValueError("Unsupported release event or branch")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or phased not in ("true", "false"):
        raise ValueError("Invalid release parameters")
    path = (root / notes).resolve()
    if not path.is_relative_to((root / "release-notes").resolve()) or not path.is_file():
        raise ValueError("Missing release notes under release-notes/")
    versions = re.findall(r"MARKETING_VERSION\s*=\s*([^;]+);", (root / "SportiliApp.xcodeproj/project.pbxproj").read_text())
    if not versions or any(v.strip().strip('"') != version for v in versions):
        raise ValueError("Tag/version must match all Xcode target marketing versions")
    return {"version": version, "notes_file": notes, "phased_release": phased}


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    rev = lambda ref: subprocess.check_output(["git", "rev-parse", ref], text=True).strip()
    values = resolve(os.environ, root, rev("origin/main"), rev("HEAD"))
    with open(os.environ["GITHUB_OUTPUT"], "a") as stream:
        for key, value in values.items():
            if "\n" in value or "\r" in value:
                raise ValueError("Multiline release input rejected")
            stream.write(f"{key}={value}\n")

#!/usr/bin/env python3
"""Create a BSDIFF40 patch against the newest published ARM64 APK release."""

from __future__ import annotations

import hashlib
import json
import os
import sys
import urllib.request
from pathlib import Path

import bsdiff4


def request_bytes(
    url: str,
    token: str | None = None,
    accept: str = "application/vnd.github+json",
) -> bytes:
    headers = {
        "Accept": accept,
        "User-Agent": "AnimeW-Delta-Builder",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=180) as response:
        return response.read()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: create_delta.py <new-apk> <target-version>")

    apk_path = Path(sys.argv[1])
    target_version = sys.argv[2].removeprefix("v")
    new_apk = apk_path.read_bytes()
    token = os.environ.get("GITHUB_TOKEN")
    repo = os.environ["GITHUB_REPOSITORY"]

    try:
        releases = json.loads(
            request_bytes(f"https://api.github.com/repos/{repo}/releases?per_page=30", token)
        )
        previous = None
        previous_asset = None
        for release in releases:
            if release.get("draft") or release.get("tag_name", "").removeprefix("v") == target_version:
                continue
            assets = release.get("assets", [])
            candidate = next(
                (
                    asset for asset in assets
                    if asset.get("name", "").lower().endswith("-arm64-v8a.apk")
                ),
                None,
            )
            if candidate:
                previous = release
                previous_asset = candidate
                break

        if not previous or not previous_asset:
            print("No previous ARM64 release APK found; publishing full APK only.")
            return 0

        # Private repositories require the authenticated asset API endpoint.
        # Asking for octet-stream here lets GitHub return a short-lived download
        # redirect without relying on Authorization surviving a host change.
        old_apk = request_bytes(
            previous_asset["url"],
            token,
            "application/octet-stream",
        )
        patch = bsdiff4.diff(old_apk, new_apk)

        # A patch that is nearly as large as the APK is not useful. The app
        # will simply download the full APK in that case.
        if len(patch) >= int(len(new_apk) * 0.85):
            print(f"Delta is not worthwhile ({len(patch)} bytes); publishing full APK only.")
            return 0

        patch_path = apk_path.with_suffix(".bsdiff")
        metadata_path = apk_path.with_suffix(".delta.json")
        patch_path.write_bytes(patch)
        metadata = {
            "format": "BSDIFF40",
            "base_version": previous.get("tag_name", "").removeprefix("v"),
            "target_version": target_version,
            "base_sha256": sha256(old_apk),
            "target_sha256": sha256(new_apk),
            "patch_sha256": sha256(patch),
            "patch_size": len(patch),
            "target_size": len(new_apk),
        }
        metadata_path.write_text(json.dumps(metadata, separators=(",", ":")) + "\n", encoding="utf-8")
        print(
            f"Created delta {patch_path.name}: {len(patch)} bytes "
            f"vs full APK {len(new_apk)} bytes "
            f"({100 * len(patch) / len(new_apk):.1f}%)."
        )
        return 0
    except Exception as error:
        # Delta generation must never prevent a valid full APK release.
        print(f"Delta generation skipped: {error}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

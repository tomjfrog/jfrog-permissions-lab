#!/usr/bin/env python3
"""Happy-path chain: Impact Search -> build ref -> Build Info -> CI run URL (platform analyst, case F)."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def _get(base: str, path: str, token: str) -> dict:
    req = urllib.request.Request(
        f"{base.rstrip('/')}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def impact_search(base: str, token: str, name: str, pkg_type: str, version: str) -> list[dict]:
    qs = urllib.parse.urlencode({"limit": "100", "name": name, "type": pkg_type, "version": version})
    data = _get(base, f"/xray/api/v2/search/impactedResources?{qs}", token)
    return data.get("result") or []


def artifact_storage_path(hit: dict) -> str:
    name = hit.get("name") or ""
    if name.startswith("/"):
        rel = name
    else:
        rel = (hit.get("path") or "/") + name
    while "//" in rel:
        rel = rel.replace("//", "/")
    return rel


def build_ref_from_artifact(base: str, token: str, hit: dict) -> tuple[str, str] | None:
    repo = hit.get("repo") or ""
    rel = artifact_storage_path(hit)
    enc = urllib.parse.quote(f"{repo}{rel}", safe="/")
    props_qs = urllib.parse.urlencode({"properties": "build.name,build.number"})
    data = _get(base, f"/artifactory/api/storage/{enc}?{props_qs}", token)
    props = data.get("properties") or {}
    bname = (props.get("build.name") or [None])[0]
    bnum = (props.get("build.number") or [None])[0]
    if not bname or not bnum:
        return None
    return str(bname), str(bnum)


def get_build_info(base: str, token: str, build_name: str, build_number: str) -> dict:
    enc_name = urllib.parse.quote(build_name, safe="")
    enc_num = urllib.parse.quote(build_number, safe="")
    return _get(base, f"/artifactory/api/build/{enc_name}/{enc_num}", token)


def ci_run_url(build_info: dict) -> str | None:
    url = (build_info.get("buildInfo") or {}).get("url")
    return url if url else None


def main() -> int:
    parser = argparse.ArgumentParser(description="Find CI runs for artifacts/builds impacted by a package.")
    parser.add_argument("--name", required=True, help="Package name (Maven: groupId:artifactId)")
    parser.add_argument("--type", required=True, help="Package type (npm, maven, …)")
    parser.add_argument("--version", required=True, help="Package version")
    args = parser.parse_args()

    base = os.environ.get("JF_URL", "").strip()
    token = os.environ.get("JF_ACCESS_TOKEN", "").strip()
    if not base or not token:
        print("Set JF_URL and JF_ACCESS_TOKEN", file=sys.stderr)
        return 1

    seen_urls: set[str] = set()
    hits = impact_search(base, token, args.name, args.type, args.version)

    for hit in hits:
        kind = hit.get("type")
        label = ""
        ref: tuple[str, str] | None = None

        if kind == "Build":
            bname, bnum = hit.get("name"), hit.get("version")
            if not bname or not bnum:
                continue
            ref = (str(bname), str(bnum))
            label = f"Build {bname}/{bnum}"
        elif kind == "Artifact":
            repo = hit.get("repo") or "?"
            rel = artifact_storage_path(hit)
            label = f"Artifact {repo}{rel}"
            try:
                ref = build_ref_from_artifact(base, token, hit)
            except urllib.error.HTTPError:
                continue
            if not ref:
                continue
        else:
            continue

        try:
            bi = get_build_info(base, token, ref[0], ref[1])
        except urllib.error.HTTPError:
            continue

        run = ci_run_url(bi)
        if not run or run in seen_urls:
            continue
        seen_urls.add(run)
        print(f"{kind}\t{label}\t{ref[0]}/{ref[1]}\t{run}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

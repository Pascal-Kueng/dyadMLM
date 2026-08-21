#!/usr/bin/env python3
"""Publish a GitHub Release as a new version of the dyadMLM Zenodo record."""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import tarfile
import tempfile
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen


GITHUB_API = "https://api.github.com"
ZENODO_API = "https://zenodo.org/api"
ZENODO_ACCEPT = "application/vnd.inveniordm.v1+json"
REPOSITORY = "Pascal-Kueng/dyadMLM"
PACKAGE = "dyadMLM"
CONCEPT_RECORD_ID = "21481720"
EXPECTED_TITLE = "dyadMLM: Tools for Dyadic Multilevel Models"
EXPECTED_ORCID = "0000-0001-7346-9414"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
DOCUMENTATION_URL = "https://pascal-kueng.github.io/dyadMLM/"
MAX_ASSET_BYTES = 100 * 1024 * 1024
TAG_PATTERN = re.compile(r"^v(?P<version>[0-9]+\.[0-9]+\.[0-9]+)$")


class ReleaseError(RuntimeError):
    """A release cannot be published safely."""


class SameOriginRedirectHandler(HTTPRedirectHandler):
    """Keep API credentials on the origin to which they were sent."""

    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        old = urlsplit(request.full_url)
        new = urlsplit(new_url)
        if request.has_header("Authorization") and (
            old.scheme,
            old.netloc,
        ) != (new.scheme, new.netloc):
            raise ReleaseError("Refusing to send an API token across origins.")
        return super().redirect_request(
            request, file_pointer, code, message, headers, new_url
        )


def safe_url(url: str) -> str:
    """Remove query parameters before including a URL in an error."""

    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))


def request_json(
    url: str,
    *,
    method: str = "GET",
    token: str | None = None,
    accept: str = "application/json",
    payload: Any | None = None,
    data: bytes | None = None,
    content_type: str | None = None,
    expected: tuple[int, ...] = (200,),
) -> tuple[int, Any]:
    """Send one JSON API request without ever placing tokens in URLs."""

    headers = {
        "Accept": accept,
        "User-Agent": "dyadMLM-Zenodo-release",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        content_type = "application/json"
    if content_type:
        headers["Content-Type"] = content_type

    request = Request(url, data=data, headers=headers, method=method)
    try:
        opener = build_opener(SameOriginRedirectHandler())
        with opener.open(request, timeout=120) as response:
            status = response.status
            response_body = response.read()
    except HTTPError as error:
        response_body = error.read().decode("utf-8", errors="replace")
        raise ReleaseError(
            f"{method} {safe_url(url)} failed with HTTP {error.code}: "
            f"{response_body[:1000]}"
        ) from error
    except URLError as error:
        raise ReleaseError(
            f"{method} {safe_url(url)} failed: {error.reason}"
        ) from error

    if status not in expected:
        raise ReleaseError(
            f"{method} {safe_url(url)} returned unexpected HTTP {status}."
        )
    if not response_body:
        return status, None
    try:
        return status, json.loads(response_body)
    except json.JSONDecodeError as error:
        raise ReleaseError(
            f"{method} {safe_url(url)} did not return valid JSON."
        ) from error


def github_json(path: str, token: str) -> Any:
    """Read one resource from the GitHub API."""

    _, response = request_json(
        f"{GITHUB_API}{path}",
        token=token,
        accept="application/vnd.github+json",
    )
    return response


def parse_tag(tag: str) -> str:
    """Return the package version represented by a stable release tag."""

    match = TAG_PATTERN.fullmatch(tag)
    if not match:
        raise ReleaseError("Release tags must use the stable form `vX.Y.Z`.")
    return match.group("version")


def parse_dcf(text: str) -> dict[str, str]:
    """Parse the small DESCRIPTION subset needed by the release checks."""

    fields: dict[str, str] = {}
    current_field: str | None = None
    for line in text.splitlines():
        if line.startswith((" ", "\t")) and current_field:
            fields[current_field] += "\n" + line.strip()
            continue
        if ":" not in line:
            current_field = None
            continue
        current_field, value = line.split(":", 1)
        current_field = current_field.strip()
        fields[current_field] = value.strip()
    return fields


def validate_package_archive(path: Path, version: str) -> str:
    """Validate the CRAN package tarball and return its publication date."""

    try:
        with tarfile.open(path, mode="r:gz") as archive:
            description_members = [
                member
                for member in archive.getmembers()
                if member.isfile()
                and len(PurePosixPath(member.name).parts) == 2
                and PurePosixPath(member.name).name == "DESCRIPTION"
            ]
            if len(description_members) != 1:
                raise ReleaseError(
                    "The release asset must contain exactly one top-level DESCRIPTION."
                )
            description_file = archive.extractfile(description_members[0])
            if description_file is None:
                raise ReleaseError("The package DESCRIPTION could not be read.")
            description_bytes = description_file.read(1024 * 1024 + 1)
    except (tarfile.TarError, OSError) as error:
        raise ReleaseError(
            "The release asset is not a readable tar.gz archive."
        ) from error

    if len(description_bytes) > 1024 * 1024:
        raise ReleaseError("The package DESCRIPTION is unexpectedly large.")
    fields = parse_dcf(description_bytes.decode("utf-8"))
    if fields.get("Package") != PACKAGE:
        raise ReleaseError(f"The release asset is not package {PACKAGE}.")
    if fields.get("Version") != version:
        raise ReleaseError(
            f"The release asset contains version {fields.get('Version')!r}, "
            f"not {version!r}."
        )

    publication = fields.get("Date/Publication", "")
    match = re.match(r"^(\d{4}-\d{2}-\d{2})", publication)
    if not match:
        raise ReleaseError(
            "The asset has no CRAN `Date/Publication`; attach the official "
            "CRAN tarball."
        )
    return match.group(1)


def file_checksums(path: Path) -> tuple[str, str]:
    """Return SHA-256 and MD5 checksums without loading the whole file at once."""

    sha256 = hashlib.sha256()
    md5 = hashlib.md5(usedforsecurity=False)
    with path.open("rb") as file_handle:
        for block in iter(lambda: file_handle.read(1024 * 1024), b""):
            sha256.update(block)
            md5.update(block)
    return sha256.hexdigest(), md5.hexdigest()


def validate_github_release(
    release: dict[str, Any], tag: str, version: str
) -> dict[str, Any]:
    """Return the one expected CRAN tarball asset from a published release."""

    if release.get("tag_name") != tag:
        raise ReleaseError("GitHub returned a release for a different tag.")
    if (
        release.get("draft")
        or release.get("prerelease")
        or not release.get("published_at")
    ):
        raise ReleaseError(
            "Only published, non-prerelease GitHub Releases are archived."
        )

    expected_name = f"{PACKAGE}_{version}.tar.gz"
    matches = [
        asset
        for asset in release.get("assets", [])
        if asset.get("name") == expected_name
    ]
    if len(matches) != 1:
        raise ReleaseError(
            f"The release must contain exactly one asset named {expected_name}."
        )
    asset = matches[0]
    size = asset.get("size")
    if not isinstance(size, int) or size <= 0 or size > MAX_ASSET_BYTES:
        raise ReleaseError("The release asset has an invalid or unsafe size.")
    return asset


def resolve_tag_commit(tag: str, github_token: str) -> str:
    """Resolve lightweight or annotated tags to one immutable commit."""

    reference = github_json(
        f"/repos/{REPOSITORY}/git/ref/tags/{quote(tag, safe='')}", github_token
    )
    target = reference.get("object", {})
    for _ in range(5):
        if target.get("type") == "commit":
            return str(target["sha"])
        if target.get("type") != "tag":
            break
        annotated_tag = github_json(
            f"/repos/{REPOSITORY}/git/tags/{target.get('sha')}", github_token
        )
        target = annotated_tag.get("object", {})
    raise ReleaseError("The release tag does not resolve to a Git commit.")


def validate_tagged_source(version: str, commit: str, github_token: str) -> None:
    """Require the release tag to be on main and its DESCRIPTION to match."""

    repository = github_json(f"/repos/{REPOSITORY}", github_token)
    default_branch = repository.get("default_branch")
    if not default_branch:
        raise ReleaseError("GitHub did not report a default branch.")

    comparison = github_json(
        f"/repos/{REPOSITORY}/compare/{commit}...{quote(default_branch, safe='')}",
        github_token,
    )
    if comparison.get("status") not in {"ahead", "identical"}:
        raise ReleaseError("The release tag is not an ancestor of the default branch.")

    description = github_json(
        f"/repos/{REPOSITORY}/contents/DESCRIPTION?{urlencode({'ref': commit})}",
        github_token,
    )
    try:
        contents = base64.b64decode(description["content"]).decode("utf-8")
    except (KeyError, ValueError, UnicodeDecodeError) as error:
        raise ReleaseError("The tagged DESCRIPTION could not be decoded.") from error
    fields = parse_dcf(contents)
    if fields.get("Package") != PACKAGE or fields.get("Version") != version:
        raise ReleaseError("The tagged DESCRIPTION does not match the release version.")


def download_release_asset(asset: dict[str, Any], destination: Path) -> None:
    """Download the public release asset with a strict size limit."""

    url = asset.get("browser_download_url")
    if not isinstance(url, str) or not url.startswith(
        f"https://github.com/{REPOSITORY}/releases/download/"
    ):
        raise ReleaseError("GitHub returned an unexpected release asset URL.")

    request = Request(url, headers={"User-Agent": "dyadMLM-Zenodo-release"})
    try:
        with (
            urlopen(request, timeout=120) as response,
            destination.open("wb") as output,
        ):
            total = 0
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                total += len(block)
                if total > MAX_ASSET_BYTES:
                    raise ReleaseError("The downloaded release asset is too large.")
                output.write(block)
    except (HTTPError, URLError, OSError) as error:
        raise ReleaseError(
            "The GitHub release asset could not be downloaded."
        ) from error

    if destination.stat().st_size != asset["size"]:
        raise ReleaseError("The downloaded release asset size does not match GitHub.")


def download_cran_archive(version: str, destination: Path) -> None:
    """Download the official CRAN archive, using the package archive as fallback."""

    filename = f"{PACKAGE}_{version}.tar.gz"
    urls = (
        f"https://cran.r-project.org/src/contrib/{filename}",
        f"https://cran.r-project.org/src/contrib/Archive/{PACKAGE}/{filename}",
    )
    for url in urls:
        request = Request(url, headers={"User-Agent": "dyadMLM-Zenodo-release"})
        try:
            with (
                urlopen(request, timeout=120) as response,
                destination.open("wb") as output,
            ):
                total = 0
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        return
                    total += len(block)
                    if total > MAX_ASSET_BYTES:
                        raise ReleaseError("The official CRAN archive is too large.")
                    output.write(block)
        except HTTPError as error:
            if error.code == 404:
                continue
            raise ReleaseError(
                f"CRAN returned HTTP {error.code} while downloading {filename}."
            ) from error
        except (URLError, OSError) as error:
            raise ReleaseError(
                f"The official CRAN archive could not be downloaded: {error}"
            ) from error

    raise ReleaseError(f"CRAN does not publish {filename} in contrib or its archive.")


def clean_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
    """Remove display-only vocabulary fields before updating a Zenodo draft."""

    cleaned = copy.deepcopy(metadata)
    if isinstance(cleaned.get("resource_type"), dict):
        cleaned["resource_type"] = {"id": cleaned["resource_type"]["id"]}
    cleaned["languages"] = [
        {"id": language["id"]} for language in cleaned.get("languages", [])
    ]
    cleaned["rights"] = [
        {"id": right["id"]} if right.get("id") else right
        for right in cleaned.get("rights", [])
    ]
    cleaned["related_identifiers"] = [
        {
            "identifier": related["identifier"],
            "scheme": related["scheme"],
            "relation_type": {"id": related["relation_type"]["id"]},
        }
        for related in cleaned.get("related_identifiers", [])
    ]
    return cleaned


def prepare_metadata(
    draft_metadata: dict[str, Any],
    *,
    version: str,
    publication_date: str,
    release_url: str,
) -> dict[str, Any]:
    """Preserve existing metadata while replacing release-specific fields."""

    metadata = clean_metadata(draft_metadata)
    release_prefix = f"https://github.com/{REPOSITORY}/releases/tag/"
    related = [
        item
        for item in metadata.get("related_identifiers", [])
        if not str(item.get("identifier", "")).startswith(release_prefix)
    ]
    related.append(
        {
            "identifier": release_url,
            "scheme": "url",
            "relation_type": {"id": "issupplementto"},
        }
    )
    metadata["related_identifiers"] = related
    metadata["version"] = version
    metadata["publication_date"] = publication_date
    return metadata


def record_files(response: dict[str, Any]) -> list[dict[str, Any]]:
    """Return file entries from a record or file-list response."""

    if isinstance(response, list):
        return response
    files = response.get("files", response)
    if isinstance(files, list):
        return files
    entries = files.get("entries", {})
    if isinstance(entries, dict):
        return list(entries.values())
    if isinstance(entries, list):
        return entries
    return []


def has_release_relation(record: dict[str, Any], release_url: str) -> bool:
    """Check whether a Zenodo record points to the GitHub Release."""

    return any(
        item.get("identifier") == release_url
        and item.get("scheme") == "url"
        and item.get("relation_type", {}).get("id") == "issupplementto"
        for item in record.get("metadata", {}).get("related_identifiers", [])
    )


def verify_citation_metadata(record: dict[str, Any]) -> None:
    """Require the durable citation metadata carried between versions."""

    metadata = record.get("metadata", {})
    creators = metadata.get("creators", [])
    identifiers = {
        identifier.get("identifier")
        for creator in creators
        for identifier in creator.get("person_or_org", {}).get("identifiers", [])
        if identifier.get("scheme") == "orcid"
    }
    related = {
        (
            item.get("identifier"),
            item.get("scheme"),
            item.get("relation_type", {}).get("id"),
        )
        for item in metadata.get("related_identifiers", [])
    }
    rights = {right.get("id") for right in metadata.get("rights", [])}

    if metadata.get("title") != EXPECTED_TITLE:
        raise ReleaseError("The Zenodo record has an unexpected title.")
    if EXPECTED_ORCID not in identifiers:
        raise ReleaseError("The Zenodo record does not preserve the creator ORCID.")
    if not str(metadata.get("description", "")).strip():
        raise ReleaseError("The Zenodo record has no description.")
    if not metadata.get("subjects"):
        raise ReleaseError("The Zenodo record has no keywords.")
    if "mit" not in rights:
        raise ReleaseError("The Zenodo record does not use the MIT license.")
    if (REPOSITORY_URL, "url", "issupplementto") not in related:
        raise ReleaseError("The Zenodo record does not link to the repository.")
    if (DOCUMENTATION_URL, "url", "isdocumentedby") not in related:
        raise ReleaseError("The Zenodo record does not link to the documentation.")


def verify_record(
    record: dict[str, Any],
    *,
    version: str,
    publication_date: str,
    filename: str,
    md5: str,
    size: int,
    release_url: str,
    expected_metadata: dict[str, Any] | None = None,
    require_completed_file: bool = False,
) -> None:
    """Require the exact concept, version, release link, and package file."""

    if str(record.get("parent", {}).get("id")) != CONCEPT_RECORD_ID:
        raise ReleaseError("Zenodo returned a record from a different concept DOI.")
    access = record.get("access", {})
    if access.get("record") != "public" or access.get("files") != "public":
        raise ReleaseError("The Zenodo record and its files must be public.")
    if record.get("metadata", {}).get("version") != version:
        raise ReleaseError("The Zenodo record has a different version.")
    if record.get("metadata", {}).get("publication_date") != publication_date:
        raise ReleaseError("The Zenodo record has a different publication date.")
    if not has_release_relation(record, release_url):
        raise ReleaseError("The Zenodo record does not link to this GitHub Release.")
    verify_citation_metadata(record)
    # A new version may differ only in the release fields prepared above.
    if (
        expected_metadata is not None
        and clean_metadata(record.get("metadata", {})) != expected_metadata
    ):
        raise ReleaseError(
            "The Zenodo record does not preserve the expected citation metadata."
        )

    files = record_files(record)
    if len(files) != 1:
        raise ReleaseError("The Zenodo record must contain exactly one file.")
    file_entry = files[0]
    if (
        file_entry.get("key") != filename
        or file_entry.get("checksum") != f"md5:{md5}"
        or file_entry.get("size") != size
        or (
            require_completed_file
            and file_entry.get("status") != "completed"
        )
    ):
        raise ReleaseError("The Zenodo file does not match the GitHub Release asset.")


def record_doi(record: dict[str, Any]) -> str:
    """Return a valid Zenodo version DOI or fail clearly."""

    doi = record.get("pids", {}).get("doi", {}).get("identifier", "")
    if not re.fullmatch(r"10\.5281/zenodo\.\d+", str(doi)):
        raise ReleaseError("The published Zenodo record has no valid version DOI.")
    return str(doi)


def zenodo_json(
    path_or_url: str,
    *,
    token: str | None = None,
    method: str = "GET",
    payload: Any | None = None,
    data: bytes | None = None,
    content_type: str | None = None,
    expected: tuple[int, ...] = (200,),
) -> tuple[int, Any]:
    """Call the modern Zenodo records API."""

    if path_or_url.startswith("https://"):
        parts = urlsplit(path_or_url)
        if (
            parts.scheme != "https"
            or parts.netloc != "zenodo.org"
            or not parts.path.startswith("/api/")
        ):
            raise ReleaseError("Zenodo returned an untrusted API link.")
        url = path_or_url
    elif path_or_url.startswith("/api/"):
        url = f"https://zenodo.org{path_or_url}"
    else:
        url = f"{ZENODO_API}{path_or_url}"
    return request_json(
        url,
        method=method,
        token=token,
        accept=ZENODO_ACCEPT,
        payload=payload,
        data=data,
        content_type=content_type,
        expected=expected,
    )


def response_hits(response: dict[str, Any]) -> list[dict[str, Any]]:
    """Return records from an InvenioRDM search response."""

    hits = response.get("hits", {}).get("hits", [])
    if not isinstance(hits, list):
        raise ReleaseError("Zenodo returned an unexpected search response.")
    return hits


def find_published_version(
    latest: dict[str, Any], version: str
) -> dict[str, Any] | None:
    """Find a published version in this concept, including older versions."""

    versions_url = latest["links"]["versions"]
    separator = "&" if "?" in versions_url else "?"
    next_url: str | None = f"{versions_url}{separator}size=25"
    seen_urls: set[str] = set()
    matches: list[dict[str, Any]] = []
    while next_url:
        if next_url in seen_urls or len(seen_urls) >= 100:
            raise ReleaseError("Zenodo returned an invalid versions pagination loop.")
        seen_urls.add(next_url)
        _, response = zenodo_json(next_url)
        matches.extend(
            record
            for record in response_hits(response)
            if record.get("metadata", {}).get("version") == version
            and record.get("is_published") is True
        )
        following = response.get("links", {}).get("next")
        if following is not None and not isinstance(following, str):
            raise ReleaseError("Zenodo returned an invalid next-page link.")
        next_url = following

    if len(matches) > 1:
        raise ReleaseError("Zenodo contains duplicate records for this version.")
    return matches[0] if matches else None


def version_tuple(version: str) -> tuple[int, int, int]:
    """Convert a validated release version to a sortable tuple."""

    parts = version.split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        raise ReleaseError(f"Zenodo contains unsupported version {version!r}.")
    return tuple(int(part) for part in parts)  # type: ignore[return-value]


def find_matching_draft(
    zenodo_token: str, version: str, release_url: str
) -> dict[str, Any] | None:
    """Resume only a draft already marked for this exact release."""

    query = urlencode({"q": f"parent.id:{CONCEPT_RECORD_ID}", "size": 100})
    _, response = zenodo_json(f"/user/records?{query}", token=zenodo_token)
    drafts = [
        record
        for record in response_hits(response)
        if not record.get("is_published")
    ]
    matching = [
        draft
        for draft in drafts
        if draft.get("metadata", {}).get("version") == version
        and has_release_relation(draft, release_url)
    ]
    if len(matching) == 1 and len(drafts) == 1:
        if str(matching[0].get("parent", {}).get("id")) != CONCEPT_RECORD_ID:
            raise ReleaseError("The matching Zenodo draft belongs to another concept.")
        return matching[0]
    if drafts:
        raise ReleaseError(
            "Zenodo already has an unmatched draft in this concept; "
            "inspect it manually."
        )
    return None


def update_draft_metadata(
    draft: dict[str, Any],
    *,
    zenodo_token: str,
    metadata: dict[str, Any],
) -> dict[str, Any]:
    """Mark a new draft for this release before touching any files."""

    payload: dict[str, Any] = {
        "access": {"record": "public", "files": "public"},
        "files": {"enabled": True},
        "metadata": metadata,
    }
    if "custom_fields" in draft:
        payload["custom_fields"] = draft["custom_fields"]
    _, updated = zenodo_json(
        draft["links"]["self"],
        token=zenodo_token,
        method="PUT",
        payload=payload,
    )
    return updated


def ensure_draft_file(
    draft: dict[str, Any], path: Path, md5: str, zenodo_token: str
) -> dict[str, Any]:
    """Upload or reuse the one expected, checksum-verified draft file."""

    filename = path.name
    _, files_response = zenodo_json(draft["links"]["files"], token=zenodo_token)
    existing_files = record_files(files_response)
    if existing_files:
        if len(existing_files) != 1 or existing_files[0].get("key") != filename:
            raise ReleaseError("The matching Zenodo draft contains an unexpected file.")
        existing = existing_files[0]
        if (
            existing.get("status") == "completed"
            and existing.get("checksum") == f"md5:{md5}"
            and existing.get("size") == path.stat().st_size
        ):
            return existing
        zenodo_json(
            existing["links"]["self"],
            token=zenodo_token,
            method="DELETE",
            expected=(204,),
        )

    _, initialized = zenodo_json(
        draft["links"]["files"],
        token=zenodo_token,
        method="POST",
        payload=[{"key": filename}],
        expected=(201,),
    )
    initialized_files = record_files(initialized)
    if len(initialized_files) != 1:
        raise ReleaseError("Zenodo did not initialize exactly one file upload.")
    upload = initialized_files[0]
    zenodo_json(
        upload["links"]["content"],
        token=zenodo_token,
        method="PUT",
        data=path.read_bytes(),
        content_type="application/octet-stream",
        expected=(200,),
    )
    _, committed = zenodo_json(
        upload["links"]["commit"],
        token=zenodo_token,
        method="POST",
        expected=(200,),
    )
    if (
        committed.get("status") != "completed"
        or committed.get("checksum") != f"md5:{md5}"
        or committed.get("size") != path.stat().st_size
    ):
        raise ReleaseError("Zenodo's committed file checksum or size does not match.")
    return committed


def publish_to_zenodo(
    *,
    version: str,
    publication_date: str,
    release_url: str,
    asset_path: Path,
    md5: str,
    zenodo_token: str,
) -> tuple[dict[str, Any], bool]:
    """Create, validate, and publish one new version under the existing concept."""

    _, latest = zenodo_json(f"/records/{CONCEPT_RECORD_ID}/versions/latest")
    if str(latest.get("parent", {}).get("id")) != CONCEPT_RECORD_ID:
        raise ReleaseError("The latest Zenodo record has an unexpected concept parent.")
    if latest.get("is_published") is not True:
        raise ReleaseError("Zenodo did not return a published latest version.")

    published = find_published_version(latest, version)
    if published:
        expected_metadata = prepare_metadata(
            published["metadata"],
            version=version,
            publication_date=publication_date,
            release_url=release_url,
        )
        verify_record(
            published,
            version=version,
            publication_date=publication_date,
            filename=asset_path.name,
            md5=md5,
            size=asset_path.stat().st_size,
            release_url=release_url,
            expected_metadata=expected_metadata,
        )
        print(f"Zenodo version {version} already exists and matches; nothing to do.")
        return published, False

    expected_metadata = prepare_metadata(
        latest["metadata"],
        version=version,
        publication_date=publication_date,
        release_url=release_url,
    )

    latest_version = latest.get("metadata", {}).get("version", "")
    if version_tuple(version) <= version_tuple(latest_version):
        raise ReleaseError(
            f"Refusing out-of-order release {version}; latest Zenodo version "
            f"is {latest_version}."
        )

    draft = find_matching_draft(zenodo_token, version, release_url)
    if draft is None:
        _, draft = zenodo_json(
            latest["links"]["versions"],
            token=zenodo_token,
            method="POST",
            expected=(201,),
        )
        if str(draft.get("parent", {}).get("id")) != CONCEPT_RECORD_ID:
            raise ReleaseError(
                "Zenodo created a draft under an unexpected concept parent."
            )

    # Reapply the exact metadata and public access when resuming a matching draft.
    draft = update_draft_metadata(
        draft,
        zenodo_token=zenodo_token,
        metadata=expected_metadata,
    )

    ensure_draft_file(draft, asset_path, md5, zenodo_token)
    _, final_draft = zenodo_json(draft["links"]["self"], token=zenodo_token)
    verify_record(
        final_draft,
        version=version,
        publication_date=publication_date,
        filename=asset_path.name,
        md5=md5,
        size=asset_path.stat().st_size,
        release_url=release_url,
        expected_metadata=expected_metadata,
        require_completed_file=True,
    )

    zenodo_json(
        final_draft["links"]["publish"],
        token=zenodo_token,
        method="POST",
        expected=(202,),
    )

    # Publication is asynchronous. Re-read the record instead of retrying publish.
    for _ in range(15):
        time.sleep(2)
        _, current_latest = zenodo_json(f"/records/{CONCEPT_RECORD_ID}/versions/latest")
        published = find_published_version(current_latest, version)
        if published:
            verify_record(
                published,
                version=version,
                publication_date=publication_date,
                filename=asset_path.name,
                md5=md5,
                size=asset_path.stat().st_size,
                release_url=release_url,
                expected_metadata=expected_metadata,
            )
            return published, True
    raise ReleaseError(
        "Zenodo accepted publication, but the public record is not visible yet; "
        "do not retry blindly."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="Published GitHub Release tag, e.g. v0.2.1")
    args = parser.parse_args()

    version = parse_tag(args.tag)
    github_token = os.environ.get("GITHUB_TOKEN")
    if not github_token:
        raise ReleaseError("GITHUB_TOKEN is required.")
    if os.environ.get("GITHUB_REPOSITORY", REPOSITORY) != REPOSITORY:
        raise ReleaseError(f"This workflow only supports {REPOSITORY}.")

    release = github_json(
        f"/repos/{REPOSITORY}/releases/tags/{quote(args.tag, safe='')}", github_token
    )
    asset = validate_github_release(release, args.tag, version)
    commit = resolve_tag_commit(args.tag, github_token)
    validate_tagged_source(version, commit, github_token)

    with tempfile.TemporaryDirectory(prefix="dyadMLM-zenodo-") as temporary_directory:
        asset_path = Path(temporary_directory) / asset["name"]
        download_release_asset(asset, asset_path)
        publication_date = validate_package_archive(asset_path, version)
        sha256, md5 = file_checksums(asset_path)
        github_digest = asset.get("digest")
        if github_digest and github_digest != f"sha256:{sha256}":
            raise ReleaseError("The downloaded asset SHA-256 does not match GitHub.")

        cran_path = Path(temporary_directory) / f"cran-{asset['name']}"
        download_cran_archive(version, cran_path)
        cran_sha256, cran_md5 = file_checksums(cran_path)
        if (
            cran_sha256 != sha256
            or cran_md5 != md5
            or cran_path.stat().st_size != asset_path.stat().st_size
        ):
            raise ReleaseError(
                "The GitHub Release asset is not byte-for-byte identical to CRAN."
            )

        release_url = release.get("html_url")
        if release_url != f"https://github.com/{REPOSITORY}/releases/tag/{args.tag}":
            raise ReleaseError("GitHub returned an unexpected release URL.")

        zenodo_token = os.environ.get("ZENODO_API_TOKEN")
        if not zenodo_token:
            raise ReleaseError("ZENODO_API_TOKEN is required.")
        published, created = publish_to_zenodo(
            version=version,
            publication_date=publication_date,
            release_url=release_url,
            asset_path=asset_path,
            md5=md5,
            zenodo_token=zenodo_token,
        )

    doi = record_doi(published)
    action = "Published" if created else "Verified existing"
    print(f"{action} dyadMLM {version} on Zenodo: https://doi.org/{doi}")


if __name__ == "__main__":
    try:
        main()
    except ReleaseError as error:
        raise SystemExit(f"Error: {error}") from error

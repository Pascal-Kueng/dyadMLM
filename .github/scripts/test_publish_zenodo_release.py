"""Focused tests for the Zenodo release helper."""

from __future__ import annotations

import contextlib
import copy
import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest import mock


SCRIPT_PATH = Path(__file__).with_name("publish_zenodo_release.py")
SPEC = importlib.util.spec_from_file_location("publish_zenodo_release", SCRIPT_PATH)
assert SPEC and SPEC.loader
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


def write_package_archive(
    path: Path, *, version: str = "0.2.1", cran_date: bool = True
) -> None:
    description = f"Package: dyadMLM\nVersion: {version}\n"
    if cran_date:
        description += "Date/Publication: 2026-09-01 08:00:00 UTC\n"
    contents = description.encode("utf-8")
    info = tarfile.TarInfo("dyadMLM/DESCRIPTION")
    info.size = len(contents)
    with tarfile.open(path, "w:gz") as archive:
        archive.addfile(info, io.BytesIO(contents))


class TagAndArchiveTests(unittest.TestCase):
    def test_stable_tag_is_parsed(self) -> None:
        self.assertEqual(release.parse_tag("v0.2.1"), "0.2.1")

    def test_nonstable_tags_are_rejected(self) -> None:
        for tag in ("0.2.1", "v0.2.1.9000", "v0.2.1-rc1", "latest"):
            with self.subTest(tag=tag), self.assertRaises(release.ReleaseError):
                release.parse_tag(tag)

    def test_cran_archive_is_validated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dyadMLM_0.2.1.tar.gz"
            write_package_archive(path)
            self.assertEqual(
                release.validate_package_archive(path, "0.2.1"), "2026-09-01"
            )

    def test_wrong_version_or_noncran_archive_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            wrong_version = Path(directory) / "wrong-version.tar.gz"
            write_package_archive(wrong_version, version="0.3.0")
            with self.assertRaises(release.ReleaseError):
                release.validate_package_archive(wrong_version, "0.2.1")

            no_cran_date = Path(directory) / "no-cran-date.tar.gz"
            write_package_archive(no_cran_date, cran_date=False)
            with self.assertRaises(release.ReleaseError):
                release.validate_package_archive(no_cran_date, "0.2.1")


class GitHubReleaseTests(unittest.TestCase):
    def test_exact_release_asset_is_selected(self) -> None:
        github_release = {
            "tag_name": "v0.2.1",
            "draft": False,
            "prerelease": False,
            "published_at": "2026-09-01T09:00:00Z",
            "assets": [{"name": "dyadMLM_0.2.1.tar.gz", "size": 1000}],
        }
        asset = release.validate_github_release(github_release, "v0.2.1", "0.2.1")
        self.assertEqual(asset["name"], "dyadMLM_0.2.1.tar.gz")

    def test_draft_prerelease_or_missing_asset_is_rejected(self) -> None:
        base = {
            "tag_name": "v0.2.1",
            "draft": False,
            "prerelease": False,
            "published_at": "2026-09-01T09:00:00Z",
            "assets": [{"name": "dyadMLM_0.2.1.tar.gz", "size": 1000}],
        }
        for change in (
            {"draft": True},
            {"prerelease": True},
            {"assets": []},
            {"assets": [{"name": "source.tar.gz", "size": 1000}]},
        ):
            candidate = {**base, **change}
            with self.subTest(change=change), self.assertRaises(release.ReleaseError):
                release.validate_github_release(candidate, "v0.2.1", "0.2.1")


class ZenodoMetadataTests(unittest.TestCase):
    def setUp(self) -> None:
        self.old_release = (
            "https://github.com/Pascal-Kueng/dyadMLM/releases/tag/v0.2.0"
        )
        self.new_release = (
            "https://github.com/Pascal-Kueng/dyadMLM/releases/tag/v0.2.1"
        )
        self.metadata = {
            "resource_type": {"id": "software", "title": {"en": "Software"}},
            "title": "dyadMLM: Tools for Dyadic Multilevel Models",
            "creators": [
                {
                    "person_or_org": {
                        "name": "Küng, Pascal",
                        "identifiers": [
                            {
                                "identifier": "0000-0001-7346-9414",
                                "scheme": "orcid",
                            }
                        ],
                    }
                }
            ],
            "description": "Tools for dyadic multilevel models.",
            "subjects": [{"subject": "dyadic data"}],
            "languages": [{"id": "eng", "title": {"en": "English"}}],
            "rights": [{"id": "mit", "title": {"en": "MIT License"}}],
            "related_identifiers": [
                {
                    "identifier": "https://github.com/Pascal-Kueng/dyadMLM",
                    "scheme": "url",
                    "relation_type": {"id": "issupplementto", "title": {}},
                },
                {
                    "identifier": "https://pascal-kueng.github.io/dyadMLM/",
                    "scheme": "url",
                    "relation_type": {"id": "isdocumentedby", "title": {}},
                },
                {
                    "identifier": self.old_release,
                    "scheme": "url",
                    "relation_type": {"id": "issupplementto", "title": {}},
                },
            ],
        }

    def new_version_responses(self, path: Path, md5: str) -> list[tuple[int, object]]:
        old_metadata = release.prepare_metadata(
            self.metadata,
            version="0.2.0",
            publication_date="2026-08-21",
            release_url=self.old_release,
        )
        new_metadata = release.prepare_metadata(
            old_metadata,
            version="0.2.1",
            publication_date="2026-09-01",
            release_url=self.new_release,
        )
        latest = {
            "id": "old-record",
            "is_published": True,
            "parent": {"id": "21481720"},
            "metadata": old_metadata,
            "links": {"versions": "https://zenodo.org/api/records/old/versions"},
        }
        draft_links = {
            "self": "https://zenodo.org/api/records/draft/draft",
            "files": "https://zenodo.org/api/records/draft/draft/files",
            "publish": "https://zenodo.org/api/records/draft/draft/actions/publish",
        }
        draft = {
            "id": "draft",
            "parent": {"id": "21481720"},
            "metadata": old_metadata,
            "access": {"record": "public", "files": "public"},
            "links": draft_links,
        }
        updated_draft = {**draft, "metadata": new_metadata}
        upload_links = {
            "content": "https://zenodo.org/api/records/draft/draft/files/"
            f"{path.name}/content",
            "commit": "https://zenodo.org/api/records/draft/draft/files/"
            f"{path.name}/commit",
        }
        initialized = {
            "entries": {path.name: {"key": path.name, "links": upload_links}}
        }
        committed = {
            "key": path.name,
            "checksum": f"md5:{md5}",
            "size": path.stat().st_size,
            "status": "completed",
        }
        final_draft = {
            **updated_draft,
            "files": {"entries": {path.name: committed}},
            "pids": {"doi": {"identifier": "10.5281/zenodo.99999998"}},
        }
        published = {
            **final_draft,
            "id": "new-record",
            "is_published": True,
            "pids": {"doi": {"identifier": "10.5281/zenodo.99999999"}},
        }
        current_latest = {
            **published,
            "links": {"versions": "https://zenodo.org/api/records/new/versions"},
        }

        return [
            (200, latest),
            (200, {"hits": {"hits": []}}),
            (200, {"hits": {"hits": []}}),
            (201, draft),
            (200, updated_draft),
            (200, {"entries": {}}),
            (201, initialized),
            (200, None),
            (200, committed),
            (200, final_draft),
            (202, None),
            (200, current_latest),
            (200, {"hits": {"hits": [published]}}),
        ]

    def test_only_release_specific_metadata_is_replaced(self) -> None:
        updated = release.prepare_metadata(
            self.metadata,
            version="0.2.1",
            publication_date="2026-09-01",
            release_url=self.new_release,
        )
        identifiers = [item["identifier"] for item in updated["related_identifiers"]]
        self.assertEqual(updated["version"], "0.2.1")
        self.assertEqual(updated["publication_date"], "2026-09-01")
        self.assertIn("https://github.com/Pascal-Kueng/dyadMLM", identifiers)
        self.assertIn(self.new_release, identifiers)
        self.assertNotIn(self.old_release, identifiers)
        self.assertEqual(updated["resource_type"], {"id": "software"})
        self.assertEqual(updated["languages"], [{"id": "eng"}])
        self.assertEqual(updated["rights"], [{"id": "mit"}])

    def test_exact_record_passes_final_gate(self) -> None:
        record = {
            "parent": {"id": "21481720"},
            "access": {"record": "public", "files": "public"},
            "metadata": release.prepare_metadata(
                self.metadata,
                version="0.2.1",
                publication_date="2026-09-01",
                release_url=self.new_release,
            ),
            "files": {
                "entries": {
                    "dyadMLM_0.2.1.tar.gz": {
                        "key": "dyadMLM_0.2.1.tar.gz",
                        "checksum": "md5:abc",
                        "size": 123,
                    }
                }
            },
        }
        release.verify_record(
            record,
            version="0.2.1",
            publication_date="2026-09-01",
            filename="dyadMLM_0.2.1.tar.gz",
            md5="abc",
            size=123,
            release_url=self.new_release,
        )

        record["files"]["entries"]["dyadMLM_0.2.1.tar.gz"]["checksum"] = "md5:wrong"
        with self.assertRaises(release.ReleaseError):
            release.verify_record(
                record,
                version="0.2.1",
                publication_date="2026-09-01",
                filename="dyadMLM_0.2.1.tar.gz",
                md5="abc",
                size=123,
                release_url=self.new_release,
            )

    def test_version_doi_must_be_valid(self) -> None:
        record = {"pids": {"doi": {"identifier": "10.5281/zenodo.12345"}}}
        self.assertEqual(release.record_doi(record), "10.5281/zenodo.12345")
        with self.assertRaises(release.ReleaseError):
            release.record_doi({"pids": {}})

    def test_untrusted_zenodo_link_is_rejected(self) -> None:
        with self.assertRaises(release.ReleaseError):
            release.zenodo_json("https://example.com/api/records/1")

    def test_existing_matching_version_is_a_read_only_noop(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dyadMLM_0.2.1.tar.gz"
            path.write_bytes(b"package")
            _, md5 = release.file_checksums(path)
            record = {
                "id": "example",
                "is_published": True,
                "parent": {"id": "21481720"},
                "access": {"record": "public", "files": "public"},
                "metadata": release.prepare_metadata(
                    self.metadata,
                    version="0.2.1",
                    publication_date="2026-09-01",
                    release_url=self.new_release,
                ),
                "files": {
                    "entries": {
                        path.name: {
                            "key": path.name,
                            "checksum": f"md5:{md5}",
                            "size": path.stat().st_size,
                        }
                    }
                },
                "pids": {"doi": {"identifier": "10.5281/zenodo.example"}},
            }
            latest = {
                "is_published": True,
                "parent": {"id": "21481720"},
                "metadata": record["metadata"],
                "links": {
                    "versions": "https://zenodo.org/api/records/example/versions"
                },
            }
            versions = {"hits": {"hits": [record]}}

            with mock.patch.object(
                release,
                "zenodo_json",
                side_effect=[(200, latest), (200, versions)],
            ) as zenodo_request:
                with contextlib.redirect_stdout(io.StringIO()):
                    returned, created = release.publish_to_zenodo(
                        version="0.2.1",
                        publication_date="2026-09-01",
                        release_url=self.new_release,
                        asset_path=path,
                        md5=md5,
                        zenodo_token="must-not-be-used",
                    )

            self.assertIs(returned, record)
            self.assertFalse(created)
            self.assertEqual(zenodo_request.call_count, 2)
            self.assertTrue(
                zenodo_request.call_args_list[1].args[0].endswith("?size=25")
            )
            for call in zenodo_request.call_args_list:
                self.assertEqual(call.kwargs.get("method", "GET"), "GET")
                self.assertNotIn("token", call.kwargs)

    def test_new_version_is_verified_before_it_is_published(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dyadMLM_0.2.1.tar.gz"
            path.write_bytes(b"package")
            _, md5 = release.file_checksums(path)
            responses = self.new_version_responses(path, md5)

            with (
                mock.patch.object(
                    release, "zenodo_json", side_effect=responses
                ) as request,
                mock.patch.object(release.time, "sleep"),
            ):
                returned, created = release.publish_to_zenodo(
                    version="0.2.1",
                    publication_date="2026-09-01",
                    release_url=self.new_release,
                    asset_path=path,
                    md5=md5,
                    zenodo_token="secret",
                )

            self.assertTrue(created)
            self.assertEqual(returned["id"], "new-record")
            self.assertEqual(
                [call.kwargs.get("method", "GET") for call in request.call_args_list],
                [
                    "GET",
                    "GET",
                    "GET",
                    "POST",
                    "PUT",
                    "GET",
                    "POST",
                    "PUT",
                    "POST",
                    "GET",
                    "POST",
                    "GET",
                    "GET",
                ],
            )

    def test_invalid_final_draft_is_not_published(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dyadMLM_0.2.1.tar.gz"
            path.write_bytes(b"package")
            _, md5 = release.file_checksums(path)
            responses = self.new_version_responses(path, md5)
            responses[9] = copy.deepcopy(responses[9])
            responses[9][1]["metadata"]["title"] = "Wrong title"

            with mock.patch.object(
                release, "zenodo_json", side_effect=responses
            ) as request:
                with self.assertRaises(release.ReleaseError):
                    release.publish_to_zenodo(
                        version="0.2.1",
                        publication_date="2026-09-01",
                        release_url=self.new_release,
                        asset_path=path,
                        md5=md5,
                        zenodo_token="secret",
                    )

            called_urls = [call.args[0] for call in request.call_args_list]
            self.assertNotIn(
                "https://zenodo.org/api/records/draft/draft/actions/publish",
                called_urls,
            )

    def test_matching_draft_is_resumed_without_creating_another(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dyadMLM_0.2.1.tar.gz"
            path.write_bytes(b"package")
            _, md5 = release.file_checksums(path)
            new_responses = self.new_version_responses(path, md5)
            matching_draft = new_responses[4][1]
            responses = [
                new_responses[0],
                new_responses[1],
                (200, {"hits": {"hits": [matching_draft]}}),
                new_responses[4],
                *new_responses[5:],
            ]

            with (
                mock.patch.object(
                    release, "zenodo_json", side_effect=responses
                ) as request,
                mock.patch.object(release.time, "sleep"),
            ):
                returned, created = release.publish_to_zenodo(
                    version="0.2.1",
                    publication_date="2026-09-01",
                    release_url=self.new_release,
                    asset_path=path,
                    md5=md5,
                    zenodo_token="secret",
                )

            self.assertTrue(created)
            self.assertEqual(returned["id"], "new-record")
            version_creation_calls = [
                call
                for call in request.call_args_list
                if call.args[0] == "https://zenodo.org/api/records/old/versions"
                and call.kwargs.get("method") == "POST"
            ]
            self.assertEqual(version_creation_calls, [])


if __name__ == "__main__":
    unittest.main()

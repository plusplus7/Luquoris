"""Protocol fixtures are shared with Android and Dart consumers."""

import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from loquiris_server.contracts import JobRequest, TranscriptResult, UploadRequest

ROOT = Path(__file__).resolve().parents[2] / "contracts/remote_transcription/v1"


def test_shared_upload_and_result_fixtures():
    upload = UploadRequest.model_validate_json((ROOT / "fixtures/upload.json").read_text())
    result = TranscriptResult.model_validate_json((ROOT / "fixtures/result.json").read_text())
    assert result.audioManifestDigest == upload.digest
    assert result.durationMs == sum(f.durationMs for f in upload.files)
    assert len(upload.files) == 2
    assert result.runId == upload.runId


def test_schema_exports_match_implementation():
    for model in (UploadRequest, JobRequest, TranscriptResult):
        assert (
            json.loads((ROOT / f"{model.__name__}.schema.json").read_text())
            == model.model_json_schema()
        )


def test_unknown_version_and_timeline_corruption_are_rejected():
    raw = json.loads((ROOT / "fixtures/result.json").read_text())
    with pytest.raises(ValidationError):
        TranscriptResult.model_validate({**raw, "schemaVersion": 2})
    raw["segments"][1]["startMs"] = 0
    with pytest.raises(ValidationError):
        TranscriptResult.model_validate(raw)

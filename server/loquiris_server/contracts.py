"""Versioned, strict wire values. All media times are integer milliseconds."""

import hashlib
import json
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Id = Annotated[str, Field(pattern=r"^[A-Za-z0-9_-]{1,128}$")]
Digest = Annotated[str, Field(pattern=r"^[a-f0-9]{64}$")]
Millis = Annotated[int, Field(ge=0, le=43200000)]


class Wire(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, frozen=True)


class AudioFile(Wire):
    fileId: Id
    sizeBytes: int = Field(gt=0, le=2 * 1024**3)
    sha256: Digest
    startMs: Millis
    durationMs: int = Field(gt=0, le=43200000)


class UploadRequest(Wire):
    schemaVersion: Literal[1]
    meetingId: Id
    runId: Id
    files: list[AudioFile] = Field(min_length=1, max_length=1024)

    @model_validator(mode="after")
    def contiguous(self):
        end = 0
        names = set()
        for item in self.files:
            if item.fileId in names or item.startMs != end:
                raise ValueError("Files must be unique and contiguous in recorded media time")
            names.add(item.fileId)
            end += item.durationMs
        if end > 43200000 or sum(f.sizeBytes for f in self.files) > 2 * 1024**3:
            raise ValueError("Upload exceeds 12 hours or 2 GiB")
        return self

    @property
    def digest(self):
        return canonical_digest(self.model_dump())


class JobRequest(Wire):
    schemaVersion: Literal[1]
    uploadId: Id
    profileId: Literal["qwen-1.7b", "whisper-large-v3"]


class Segment(Wire):
    startMs: Millis
    endMs: Millis
    text: str = Field(min_length=1, max_length=16000)
    language: str | None = Field(default=None, max_length=32)
    speaker: str | None = None

    @model_validator(mode="after")
    def interval(self):
        if self.endMs <= self.startMs or self.speaker is not None:
            raise ValueError("Positive interval required; diarization is not installed")
        return self


class TranscriptResult(Wire):
    schemaVersion: Literal[1]
    jobId: Id
    meetingId: Id
    runId: Id
    audioManifestDigest: Digest
    durationMs: Millis
    provenance: dict[str, str]
    segments: list[Segment] = Field(max_length=100000)

    @model_validator(mode="after")
    def timeline(self):
        last = 0
        for segment in self.segments:
            if segment.startMs < last or segment.endMs > self.durationMs:
                raise ValueError("Segments must be ordered, disjoint and within audio")
            last = segment.endMs
        if not self.provenance.get("modelRevision") or not self.provenance.get("runtime"):
            raise ValueError("Immutable model provenance is required")
        return self


def canonical_digest(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    ).hexdigest()

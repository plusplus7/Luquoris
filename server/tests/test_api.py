"""Real HTTP/storage tests: removing offset checks or ownership checks must break these."""

import hashlib
import io
import wave

import pytest
from fastapi.testclient import TestClient


def wav_bytes():
    out = io.BytesIO()
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(b"\x00\x00" * 16000)
    return out.getvalue()


def declaration(data):
    return {
        "schemaVersion": 1,
        "meetingId": "meeting-1",
        "runId": "run-1",
        "files": [
            {
                "fileId": "segment-1",
                "sizeBytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "startMs": 0,
                "durationMs": 1000,
            }
        ],
    }


@pytest.fixture
def system(tmp_path):
    from loquiris_server.api import create_app
    from loquiris_server.config import PROFILES, Settings

    settings = Settings(
        data_dir=tmp_path, tokens={"alice": "a" * 32, "bob": "b" * 32}, profiles=PROFILES
    )
    return settings, TestClient(create_app(settings))


def auth(owner="alice"):
    return {"Authorization": "Bearer " + ("a" if owner == "alice" else "b") * 32}


def create_upload(client, data, key="upload-1"):
    response = client.post(
        "/v1/uploads", json=declaration(data), headers={**auth(), "Idempotency-Key": key}
    )
    assert response.status_code == 200, response.text
    return response.json()


def sealed_upload(client):
    data = wav_bytes()
    upload = create_upload(client, data)
    uid = upload["uploadId"]
    assert (
        client.put(
            f"/v1/uploads/{uid}/files/segment-1?offset=0", content=data, headers=auth()
        ).status_code
        == 200
    )
    response = client.post(f"/v1/uploads/{uid}/complete", headers=auth())
    assert response.status_code == 200, response.text
    return uid


def test_resume_is_durable_and_repeated_chunks_are_idempotent(system):
    from loquiris_server.api import create_app

    settings, client = system
    data = wav_bytes()
    uid = create_upload(client, data)["uploadId"]
    route = f"/v1/uploads/{uid}/files/segment-1"
    assert (
        client.put(route + "?offset=0", content=data[:100], headers=auth()).json()["offset"] == 100
    )
    restarted = TestClient(create_app(settings))
    assert create_upload(restarted, data)["uploadId"] == uid
    assert restarted.get(f"/v1/uploads/{uid}", headers=auth()).json()["offsets"]["segment-1"] == 100
    assert (
        restarted.put(route + "?offset=0", content=data[:100], headers=auth()).json()["offset"]
        == 100
    )
    assert restarted.put(route + "?offset=0", content=b"x" * 100, headers=auth()).status_code == 409
    assert restarted.put(route + "?offset=100", content=data[100:], headers=auth()).json()[
        "offset"
    ] == len(data)
    assert restarted.post(f"/v1/uploads/{uid}/complete", headers=auth()).status_code == 200


def test_auth_ownership_and_token_revocation(system):
    settings, client = system
    uid = create_upload(client, wav_bytes())["uploadId"]
    assert client.get(f"/v1/uploads/{uid}").status_code == 401
    assert client.get(f"/v1/uploads/{uid}", headers=auth("bob")).status_code == 404
    settings.tokens.pop("alice")
    assert client.get(f"/v1/uploads/{uid}", headers=auth()).status_code == 401


def test_sealing_rejects_incomplete_digest_and_invalid_media(system):
    _, client = system
    data = wav_bytes()
    uid = create_upload(client, data)["uploadId"]
    assert client.post(f"/v1/uploads/{uid}/complete", headers=auth()).status_code == 409
    client.put(
        f"/v1/uploads/{uid}/files/segment-1?offset=0", content=b"x" * len(data), headers=auth()
    )
    assert client.post(f"/v1/uploads/{uid}/complete", headers=auth()).status_code == 422
    corrupt = b"bad media"
    uid2 = create_upload(client, corrupt, key="bad")["uploadId"]
    client.put(f"/v1/uploads/{uid2}/files/segment-1?offset=0", content=corrupt, headers=auth())
    assert client.post(f"/v1/uploads/{uid2}/complete", headers=auth()).status_code == 422


def test_jobs_are_idempotent_and_cancelled_results_are_unavailable(system):
    _, client = system
    uid = sealed_upload(client)
    body = {"schemaVersion": 1, "uploadId": uid, "profileId": "qwen-1.7b"}
    headers = {**auth(), "Idempotency-Key": "job-1"}
    first = client.post("/v1/transcriptions", json=body, headers=headers)
    assert first.status_code == 200, first.text
    jid = first.json()["jobId"]
    assert client.post("/v1/transcriptions", json=body, headers=headers).json()["jobId"] == jid
    assert (
        client.post(
            "/v1/transcriptions", json={**body, "profileId": "whisper-large-v3"}, headers=headers
        ).status_code
        == 409
    )
    assert client.get(f"/v1/transcriptions/{jid}", headers=auth("bob")).status_code == 404
    assert client.get(f"/v1/transcriptions/{jid}/result", headers=auth()).status_code == 409
    assert client.delete(f"/v1/transcriptions/{jid}", headers=auth()).json()["state"] == "cancelled"
    assert client.delete(f"/v1/transcriptions/{jid}", headers=auth()).json()["state"] == "cancelled"


def test_unsafe_ids_limits_and_schema_are_rejected(system):
    _, client = system
    body = declaration(wav_bytes())
    body["files"][0]["fileId"] = "../escape"
    assert (
        client.post(
            "/v1/uploads", json=body, headers={**auth(), "Idempotency-Key": "x"}
        ).status_code
        == 422
    )
    body = declaration(wav_bytes())
    body["schemaVersion"] = 2
    assert (
        client.post(
            "/v1/uploads", json=body, headers={**auth(), "Idempotency-Key": "x"}
        ).status_code
        == 422
    )
    body = declaration(wav_bytes())
    body["files"][0]["sizeBytes"] = 10**15
    assert (
        client.post(
            "/v1/uploads", json=body, headers={**auth(), "Idempotency-Key": "x"}
        ).status_code
        == 422
    )


def test_crash_tail_is_truncated_to_confirmed_offset(system):
    settings, client = system
    uid = create_upload(client, wav_bytes())["uploadId"]
    path = settings.data_dir / "uploads" / uid / "segment-1"
    path.write_bytes(b"uncommitted crash tail")
    result = client.put(
        f"/v1/uploads/{uid}/files/segment-1?offset=0", content=wav_bytes()[:100], headers=auth()
    )
    assert result.status_code == 200, result.text
    assert path.stat().st_size == 100


def test_request_body_is_bounded_and_metadata_private(system):
    settings, client = system
    uid = create_upload(client, wav_bytes())["uploadId"]
    response = client.put(
        f"/v1/uploads/{uid}/files/segment-1?offset=0",
        content=b"x" * (settings.chunk_bytes + 1),
        headers=auth(),
    )
    assert response.status_code == 413
    assert client.get("/v1/capabilities", headers=auth()).json()["retentionSeconds"] == 86400
    assert str(settings.data_dir) not in client.get("/v1/capabilities", headers=auth()).text


def test_adts_variable_bitrate_duration_is_validated_from_samples(system, tmp_path):
    import array
    import math
    import subprocess

    _, client = system
    source = tmp_path / "input.wav"
    with wave.open(str(source), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        out.writeframes(b"\0\0" * 16000 * 15)
        out.writeframes(
            array.array("h", [int(4000 * math.sin(i / 10)) for i in range(16000 * 15)]).tobytes()
        )
    target = tmp_path / "audio.adts"
    subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(source),
            "-c:a",
            "aac",
            "-b:a",
            "32k",
            "-f",
            "adts",
            str(target),
        ],
        check=True,
    )
    data = target.read_bytes()
    body = declaration(data)
    body["files"][0]["durationMs"] = 30000
    response = client.post("/v1/uploads", json=body, headers={**auth(), "Idempotency-Key": "adts"})
    uid = response.json()["uploadId"]
    assert (
        client.put(
            f"/v1/uploads/{uid}/files/segment-1?offset=0", content=data, headers=auth()
        ).status_code
        == 200
    )
    sealed = client.post(f"/v1/uploads/{uid}/complete", headers=auth())
    assert sealed.status_code == 200, sealed.text

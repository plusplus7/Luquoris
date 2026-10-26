"""Regression cases found by independent security review."""

import json

import pytest
from test_api import auth, create_upload, wav_bytes
from test_api import system as system
from test_ledger import output, ready


def test_chunked_oversize_returns_413_instead_of_500(system):
    settings, client = system
    uid = create_upload(client, wav_bytes())["uploadId"]
    result = client.put(
        f"/v1/uploads/{uid}/files/segment-1?offset=0",
        content=iter([b"x" * settings.chunk_bytes, b"x"]),
        headers=auth(),
    )
    assert result.status_code == 413


def test_cleanup_reconciles_result_published_before_failed_db_commit(tmp_path):
    _, store, _ = ready(tmp_path)
    claim = store.claim()
    # Represents a process death after atomic rename, before committing result_path.
    orphan = store.root / "results" / f"{claim['id']}-{claim['generation']}.json"
    orphan.write_text(json.dumps(output(claim)))
    tmp = orphan.with_suffix(".tmp")
    tmp.write_text("private text")
    store.cancel("alice", claim["id"])
    now = store.clock()
    store.clock = lambda: now + 86401
    store.cleanup()
    assert not orphan.exists()
    assert not tmp.exists()


def test_bad_result_identity_is_rejected_before_publication(tmp_path):
    from loquiris_server.store import Rejected

    _, store, _ = ready(tmp_path)
    claim = store.claim()
    for key in ("jobId", "runId", "meetingId", "audioManifestDigest"):
        bad = output(claim)
        bad[key] = "d" * 64
        with pytest.raises(Rejected):
            store.finish(claim, bad)
    assert not list((store.root / "results").glob("*.json"))


def test_readiness_requires_live_worker_weight_and_runtime_probe(system):
    settings, client = system
    response = client.get("/health/ready", headers=auth())
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "worker_unready"
    assert client.get("/health/live").status_code == 200

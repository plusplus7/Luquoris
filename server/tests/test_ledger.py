"""Lease, retention and ownership tests use a real SQLite DB and controlled clock."""

from concurrent.futures import ThreadPoolExecutor

from fastapi.testclient import TestClient
from test_api import auth, sealed_upload

from loquiris_server.api import create_app
from loquiris_server.config import Settings
from loquiris_server.store import Store


def ready(tmp_path):
    settings = Settings(tmp_path, {"alice": "a" * 32})
    app = create_app(settings)
    client = TestClient(app)
    uid = sealed_upload(client)
    job = client.post(
        "/v1/transcriptions",
        headers={**auth(), "Idempotency-Key": "j"},
        json={"schemaVersion": 1, "uploadId": uid, "profileId": "qwen-1.7b"},
    ).json()
    return settings, app.state.store, job


def output(claim):
    return {
        "schemaVersion": 1,
        "jobId": claim["id"],
        "meetingId": claim["upload"]["meetingId"],
        "runId": claim["upload"]["runId"],
        "audioManifestDigest": claim["audioManifestDigest"],
        "durationMs": 1000,
        "provenance": {"runtime": "test", "modelRevision": "a" * 40},
        "segments": [{"startMs": 0, "endMs": 1000, "text": "测试"}],
    }


def test_one_gpu_task_across_independent_claimers(tmp_path):
    settings, store, _ = ready(tmp_path)
    # A second queued job must not run while the first GPU lease is valid.
    with store.transaction() as db:
        row = dict(db.execute("SELECT * FROM jobs").fetchone())
        row.update(id="second", idem="second")
        db.execute(
            f"INSERT INTO jobs ({','.join(row)}) VALUES ({','.join('?' for _ in row)})",
            tuple(row.values()),
        )
    with ThreadPoolExecutor(max_workers=2) as pool:
        claimed = list(pool.map(lambda _: Store(settings).claim(), range(2)))
    assert sum(c is not None for c in claimed) == 1


def test_expired_attempt_cannot_finish_or_heartbeat(tmp_path):
    _, store, _ = ready(tmp_path)
    first = store.claim()
    clock = store.clock()
    store.clock = lambda: clock + 100
    assert store.heartbeat(first["id"], first["generation"]) is False
    second = store.claim()
    assert second["generation"] == first["generation"] + 1
    assert not store.finish(first, output(first))
    assert store.finish(second, output(second))
    assert store.result("alice", second["id"])["segments"][0]["text"] == "测试"


def test_cancel_blocks_stale_completion(tmp_path):
    _, store, _ = ready(tmp_path)
    claim = store.claim()
    store.cancel("alice", claim["id"])
    assert not store.finish(claim, output(claim))
    assert not store.heartbeat(claim["id"], claim["generation"])


def test_retention_protects_shared_upload_until_every_job_expires(tmp_path):
    _, store, job = ready(tmp_path)
    first = store.claim()
    assert store.finish(first, output(first))
    with store.transaction() as db:
        row = dict(db.execute("SELECT * FROM jobs").fetchone())
        row.update(id="second", idem="second", state="queued", expires=None, result_path=None)
        db.execute(
            f"INSERT INTO jobs ({','.join(row)}) VALUES ({','.join('?' for _ in row)})",
            tuple(row.values()),
        )
    now = store.clock()
    store.clock = lambda: now + 86401
    store.cleanup()
    assert (store.root / "uploads" / job["uploadId"]).exists()
    second = store.claim()
    store.cancel("alice", second["id"])
    store.clock = lambda: now + 172802
    store.cleanup()
    assert not (store.root / "uploads" / job["uploadId"]).exists()


def test_worker_retries_are_bounded_and_error_is_typed(tmp_path):
    _, store, _ = ready(tmp_path)
    for attempt in range(1, 4):
        claim = store.claim()
        assert claim["attempts"] == attempt
        store.fail(claim, "gpu_memory", retryable=True)
    assert store.claim() is None
    assert store.job("alice", claim["id"])["error"] == "gpu_memory"

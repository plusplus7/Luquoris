from concurrent.futures import ThreadPoolExecutor

from test_api import auth, create_upload, wav_bytes
from test_api import system as system


def test_concurrent_sealing_is_idempotent(system):
    _, client = system
    data = wav_bytes()
    uid = create_upload(client, data)["uploadId"]
    client.put(f"/v1/uploads/{uid}/files/segment-1?offset=0", content=data, headers=auth())
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(
            pool.map(lambda _: client.post(f"/v1/uploads/{uid}/complete", headers=auth()), range(2))
        )
    assert [r.status_code for r in results] == [200, 200]
    assert all(r.json()["state"] == "sealed" for r in results)


def test_other_owner_cannot_write_or_seal(system):
    _, client = system
    uid = create_upload(client, wav_bytes())["uploadId"]
    assert (
        client.put(
            f"/v1/uploads/{uid}/files/segment-1?offset=0", content=b"x", headers=auth("bob")
        ).status_code
        == 404
    )
    assert client.post(f"/v1/uploads/{uid}/complete", headers=auth("bob")).status_code == 404
    assert (
        client.post(
            "/v1/transcriptions",
            json={"schemaVersion": 1, "uploadId": uid, "profileId": "qwen-1.7b"},
            headers={**auth("bob"), "Idempotency-Key": "bad"},
        ).status_code
        == 404
    )

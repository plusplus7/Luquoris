"""Opt-in tests against a real Linux image, listener and persistent Docker volume."""

import json
import os
import secrets
import subprocess
import time
import urllib.error
import urllib.request
import uuid

import pytest
from test_api import declaration, wav_bytes

IMAGE = os.environ.get("LOQUIRIS_TEST_API_IMAGE")
pytestmark = pytest.mark.skipif(
    not IMAGE, reason="Set LOQUIRIS_TEST_API_IMAGE to a built API image"
)


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True, timeout=60).strip()


def test_image_restart_preserves_confirmed_upload_and_owned_job(tmp_path):
    identifier = "loquiris-verify-" + uuid.uuid4().hex[:12]
    volume = identifier + "-data"
    tokens = {"alice": secrets.token_urlsafe(32), "bob": secrets.token_urlsafe(32)}
    environment = tmp_path / "container.env"
    environment.write_text("LOQUIRIS_CLIENT_TOKENS=" + json.dumps(tokens) + "\n")
    environment.chmod(0o600)
    started = False
    try:
        docker("volume", "create", volume)
        docker(
            "run",
            "--detach",
            "--init",
            "--platform",
            "linux/amd64",
            "--name",
            identifier,
            "--env-file",
            str(environment),
            "--mount",
            f"type=volume,src={volume},dst=/data",
            "--publish",
            "127.0.0.1::8000",
            IMAGE,
        )
        started = True

        def connection():
            ports = json.loads(
                docker("inspect", "--format", "{{json .NetworkSettings.Ports}}", identifier)
            )
            return "http://127.0.0.1:" + ports["8000/tcp"][0]["HostPort"]

        base = connection()

        def request(route, method="GET", value=None, body=None, owner="alice", key=None):
            headers = {"Authorization": "Bearer " + tokens[owner]}
            if value is not None:
                body = json.dumps(value).encode()
                headers["Content-Type"] = "application/json"
            if key:
                headers["Idempotency-Key"] = key
            message = urllib.request.Request(base + route, body, headers, method=method)
            try:
                response = urllib.request.urlopen(message, timeout=15)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                return response.status, json.loads(response.read())

        def await_live():
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                try:
                    if request("/health/live")[0] == 200:
                        return
                except (OSError, urllib.error.URLError):
                    pass
                time.sleep(0.1)
            pytest.fail("Container API failed to become live")

        await_live()
        assert request("/health/ready")[0] == 503
        assert docker("exec", identifier, "id", "-u") == "10001"
        data = wav_bytes()
        upload_request = declaration(data)
        status, upload = request("/v1/uploads", "POST", value=upload_request, key="upload-smoke")
        assert status == 200
        uid = upload["uploadId"]
        route = f"/v1/uploads/{uid}/files/segment-1"
        assert request(route + "?offset=0", "PUT", body=data[:16000]) == (200, {"offset": 16000})
        assert request(f"/v1/uploads/{uid}/complete", "POST")[0] == 409

        docker("restart", identifier)
        base = connection()
        await_live()
        status, resumed = request("/v1/uploads", "POST", value=upload_request, key="upload-smoke")
        assert status == 200
        assert resumed["uploadId"] == uid
        assert resumed["offsets"]["segment-1"] == 16000
        assert request(route + "?offset=0", "PUT", body=data[:16000])[0] == 200
        assert request(route + "?offset=16000", "PUT", body=data[16000:])[0] == 200
        assert request(f"/v1/uploads/{uid}/complete", "POST")[0] == 200
        assert request(f"/v1/uploads/{uid}", owner="bob")[0] == 404
        job_request = {"schemaVersion": 1, "uploadId": uid, "profileId": "qwen-1.7b"}
        status, job = request("/v1/transcriptions", "POST", value=job_request, key="job-smoke")
        assert status == 200
        jid = job["jobId"]
        assert (
            request("/v1/transcriptions", "POST", value=job_request, key="job-smoke")[1]["jobId"]
            == jid
        )
        assert request(f"/v1/transcriptions/{jid}", owner="bob")[0] == 404
        assert request(f"/v1/transcriptions/{jid}", "DELETE")[1]["state"] == "cancelled"
        assert request(f"/v1/transcriptions/{jid}/result")[0] == 409
    finally:
        # Remove the ephemeral credential file even if Docker cleanup fails.
        try:
            if started:
                docker("rm", "--force", identifier)
        finally:
            try:
                docker("volume", "rm", volume)
            finally:
                environment.unlink(missing_ok=True)


def test_reverse_proxy_uses_verified_tls_and_preserves_authentication(tmp_path):
    """Use a disposable localhost CA; never relax the application's TLS policy."""
    import ssl
    from pathlib import Path

    identifier = "loquiris-tls-" + uuid.uuid4().hex[:12]
    api, proxy, network = identifier + "-api", identifier + "-proxy", identifier + "-net"
    token = secrets.token_urlsafe(32)
    environment = tmp_path / "tls-container.env"
    environment.write_text("LOQUIRIS_CLIENT_TOKENS=" + json.dumps({"phone": token}) + "\n")
    environment.chmod(0o600)
    started = []
    created_network = False
    try:
        docker("network", "create", network)
        created_network = True
        docker(
            "run",
            "--detach",
            "--init",
            "--platform",
            "linux/amd64",
            "--name",
            api,
            "--network",
            network,
            "--network-alias",
            "api",
            "--env-file",
            str(environment),
            IMAGE,
        )
        started.append(api)
        configuration = Path(__file__).resolve().parents[1] / "Caddyfile"
        docker(
            "run",
            "--detach",
            "--platform",
            "linux/amd64",
            "--name",
            proxy,
            "--network",
            network,
            "--env",
            "LOQUIRIS_SERVER_HOST=localhost",
            "--publish",
            "127.0.0.1::443",
            "--mount",
            f"type=bind,src={configuration},dst=/etc/caddy/Caddyfile,readonly",
            "caddy:2.10.0",
        )
        started.append(proxy)
        ports = json.loads(docker("inspect", "--format", "{{json .NetworkSettings.Ports}}", proxy))
        base = "https://localhost:" + ports["443/tcp"][0]["HostPort"]
        root = tmp_path / "localhost-test-root.crt"
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            result = subprocess.run(
                ["docker", "cp", proxy + ":/data/caddy/pki/authorities/local/root.crt", str(root)],
                capture_output=True,
                timeout=10,
            )
            if result.returncode == 0:
                break
            time.sleep(0.2)
        assert root.is_file(), "Caddy did not provision the temporary localhost CA"
        trusted = ssl.create_default_context(cafile=str(root))
        assert trusted.check_hostname
        assert trusted.verify_mode == ssl.CERT_REQUIRED
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                with urllib.request.urlopen(
                    base + "/health/live", context=trusted, timeout=5
                ) as response:
                    if response.status == 200:
                        break
            except (OSError, urllib.error.URLError):
                time.sleep(0.2)
        else:
            pytest.fail("TLS proxy did not reach the API")
        with pytest.raises(urllib.error.URLError):
            urllib.request.urlopen(base + "/health/live", timeout=5)
        with pytest.raises(urllib.error.HTTPError) as rejected:
            urllib.request.urlopen(base + "/v1/capabilities", context=trusted, timeout=5)
        assert rejected.value.code == 401
        request = urllib.request.Request(
            base + "/v1/capabilities", headers={"Authorization": "Bearer " + token}
        )
        with urllib.request.urlopen(request, context=trusted, timeout=5) as response:
            assert json.load(response)["profiles"] == ["qwen-1.7b"]
    finally:
        environment.unlink(missing_ok=True)
        try:
            for container in reversed(started):
                docker("rm", "--force", "--volumes", container)
        finally:
            if created_network:
                docker("network", "rm", network)


def test_worker_without_prepared_weights_fails_closed_without_breaking_api(tmp_path):
    """Exercise shared-volume process wiring; this does not run GPU inference."""
    identifier = "loquiris-worker-check-" + uuid.uuid4().hex[:10]
    data_volume, model_volume = identifier + "-data", identifier + "-models"
    api, worker = identifier + "-api", identifier + "-worker"
    token = secrets.token_urlsafe(32)
    environment = tmp_path / "worker-container.env"
    environment.write_text("LOQUIRIS_CLIENT_TOKENS=" + json.dumps({"phone": token}) + "\n")
    environment.chmod(0o600)
    containers, volumes = [], []
    try:
        for volume in (data_volume, model_volume):
            docker("volume", "create", volume)
            volumes.append(volume)
        docker(
            "run",
            "--detach",
            "--init",
            "--platform",
            "linux/amd64",
            "--name",
            api,
            "--env-file",
            str(environment),
            "--mount",
            f"type=volume,src={data_volume},dst=/data",
            "--publish",
            "127.0.0.1::8000",
            IMAGE,
        )
        containers.append(api)
        ports = json.loads(docker("inspect", "--format", "{{json .NetworkSettings.Ports}}", api))
        base = "http://127.0.0.1:" + ports["8000/tcp"][0]["HostPort"]

        def request(route, method="GET", value=None, body=None, key=None):
            headers = {"Authorization": "Bearer " + token}
            if value is not None:
                body = json.dumps(value).encode()
                headers["Content-Type"] = "application/json"
            if key:
                headers["Idempotency-Key"] = key
            try:
                response = urllib.request.urlopen(
                    urllib.request.Request(base + route, body, headers, method=method), timeout=10
                )
            except urllib.error.HTTPError as error:
                response = error
            with response:
                return response.status, json.load(response)

        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                if request("/health/live")[0] == 200:
                    break
            except (OSError, urllib.error.URLError):
                time.sleep(0.1)
        else:
            pytest.fail("API container did not become live")
        data = wav_bytes()
        status, uploaded = request(
            "/v1/uploads", "POST", value=declaration(data), key="worker-upload"
        )
        assert status == 200
        uid = uploaded["uploadId"]
        assert request(f"/v1/uploads/{uid}/files/segment-1?offset=0", "PUT", body=data)[0] == 200
        assert request(f"/v1/uploads/{uid}/complete", "POST")[0] == 200
        status, job = request(
            "/v1/transcriptions",
            "POST",
            value={"schemaVersion": 1, "uploadId": uid, "profileId": "qwen-1.7b"},
            key="worker-job",
        )
        assert status == 200
        assert job["state"] == "queued"
        docker(
            "run",
            "--detach",
            "--init",
            "--platform",
            "linux/amd64",
            "--name",
            worker,
            "--env-file",
            str(environment),
            "--mount",
            f"type=volume,src={data_volume},dst=/data",
            "--mount",
            f"type=volume,src={model_volume},dst=/models,readonly",
            os.environ.get("LOQUIRIS_TEST_WORKER_IMAGE", IMAGE),
            "/app/.venv/bin/python",
            "-m",
            "loquiris_server.worker",
        )
        containers.append(worker)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            status, final = request(f"/v1/transcriptions/{job['jobId']}")
            assert status == 200
            if final["state"] == "failed":
                break
            time.sleep(0.2)
        else:
            pytest.fail("Worker did not fail closed for missing model weights")
        assert final["error"] == "model_unavailable"
        assert final["profileId"] == "qwen-1.7b"
        assert final["attempt"] == 1
        assert request(f"/v1/transcriptions/{job['jobId']}/result")[0] == 409
        assert request("/health/live")[0] == 200
        assert request("/health/ready")[0] == 503
    finally:
        environment.unlink(missing_ok=True)
        try:
            for container in reversed(containers):
                docker("rm", "--force", container)
        finally:
            for volume in reversed(volumes):
                docker("volume", "rm", volume)

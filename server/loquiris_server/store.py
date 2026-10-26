"""Single-host durable ledger. flock serializes file commits across API processes."""

import contextlib
import fcntl
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import time
import uuid
from pathlib import Path

from .contracts import TranscriptResult, UploadRequest, canonical_digest
from .media_validation import validate_samples


class Rejected(Exception):
    def __init__(self, code, status=409):
        self.code, self.status = code, status
        super().__init__(code)


class Store:
    def __init__(self, settings, clock=time.time):
        self.settings, self.clock = settings, clock
        self.root = settings.data_dir
        self.root.mkdir(parents=True, exist_ok=True)
        for name in ("uploads", "results", "work"):
            (self.root / name).mkdir(exist_ok=True)
        with self.transaction() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS uploads (
                    id TEXT PRIMARY KEY, owner TEXT NOT NULL, idem TEXT NOT NULL,
                    digest TEXT NOT NULL, request TEXT NOT NULL, state TEXT NOT NULL,
                    expires REAL NOT NULL, UNIQUE(owner, idem));
                CREATE TABLE IF NOT EXISTS files (
                    upload_id TEXT NOT NULL REFERENCES uploads(id), id TEXT NOT NULL,
                    confirmed INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(upload_id,id));
                CREATE TABLE IF NOT EXISTS jobs (
                    id TEXT PRIMARY KEY, owner TEXT NOT NULL, idem TEXT NOT NULL,
                    digest TEXT NOT NULL, upload_id TEXT NOT NULL REFERENCES uploads(id),
                    profile TEXT NOT NULL, state TEXT NOT NULL, generation INTEGER NOT NULL DEFAULT 0,
                    attempts INTEGER NOT NULL DEFAULT 0, lease REAL, error TEXT,
                    result_path TEXT, expires REAL, created REAL NOT NULL,
                    UNIQUE(owner,idem));
                PRAGMA user_version=1;
            """)

    @contextlib.contextmanager
    def transaction(self):
        with (self.root / ".ledger.lock").open("a+b") as guard:
            fcntl.flock(guard, fcntl.LOCK_EX)
            db = sqlite3.connect(self.root / "ledger.sqlite3", timeout=30)
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("PRAGMA synchronous=FULL")
            db.execute("PRAGMA foreign_keys=ON")
            try:
                db.execute("BEGIN IMMEDIATE")
                yield db
                db.commit()
            except BaseException:
                db.rollback()
                raise
            finally:
                db.close()
                fcntl.flock(guard, fcntl.LOCK_UN)

    def _upload(self, db, owner, uid):
        row = db.execute("SELECT * FROM uploads WHERE id=? AND owner=?", (uid, owner)).fetchone()
        if row is None:
            raise Rejected("not_found", 404)
        if row["state"] == "expired" or (row["state"] == "open" and row["expires"] <= self.clock()):
            raise Rejected("upload_expired", 410)
        return row

    def _upload_view(self, db, row):
        return {
            "schemaVersion": 1,
            "uploadId": row["id"],
            "state": row["state"],
            "audioManifestDigest": row["digest"],
            "chunkBytes": self.settings.chunk_bytes,
            "expiresAt": int(row["expires"] * 1000),
            "offsets": {
                f["id"]: f["confirmed"]
                for f in db.execute(
                    "SELECT id,confirmed FROM files WHERE upload_id=?", (row["id"],)
                )
            },
        }

    def create_upload(self, owner, idem, request):
        with self.transaction() as db:
            row = db.execute(
                "SELECT * FROM uploads WHERE owner=? AND idem=?", (owner, idem)
            ).fetchone()
            if row:
                if row["digest"] != request.digest:
                    raise Rejected("idempotency_conflict")
                self._upload(db, owner, row["id"])
                return self._upload_view(db, row)
            size = sum(f.sizeBytes for f in request.files)
            usage = sum(
                sum(f["sizeBytes"] for f in json.loads(r["request"])["files"])
                for r in db.execute(
                    "SELECT request FROM uploads WHERE owner=? AND state!='expired'", (owner,)
                )
            )
            if (
                size > self.settings.max_upload_bytes
                or usage + size > self.settings.max_owner_bytes
            ):
                raise Rejected("storage_quota", 413)
            uid = uuid.uuid4().hex
            folder = self.root / "uploads" / uid
            folder.mkdir()
            for item in request.files:
                with (folder / item.fileId).open("xb") as f:
                    f.flush()
                    os.fsync(f.fileno())
            self._sync_dir(folder)
            self._sync_dir(folder.parent)
            db.execute(
                "INSERT INTO uploads VALUES (?,?,?,?,?,?,?)",
                (
                    uid,
                    owner,
                    idem,
                    request.digest,
                    request.model_dump_json(),
                    "open",
                    self.clock() + self.settings.retention_seconds,
                ),
            )
            db.executemany(
                "INSERT INTO files(upload_id,id) VALUES (?,?)",
                [(uid, f.fileId) for f in request.files],
            )
            return self._upload_view(db, self._upload(db, owner, uid))

    def upload(self, owner, uid):
        with self.transaction() as db:
            return self._upload_view(db, self._upload(db, owner, uid))

    def chunk(self, owner, uid, fid, offset, data):
        if not data or len(data) > self.settings.chunk_bytes:
            raise Rejected("chunk_size", 413)
        with self.transaction() as db:
            row = self._upload(db, owner, uid)
            request = UploadRequest.model_validate_json(row["request"])
            item = next((f for f in request.files if f.fileId == fid), None)
            if item is None:
                raise Rejected("not_found", 404)
            if row["state"] != "open":
                raise Rejected("upload_sealed")
            confirmed = db.execute(
                "SELECT confirmed FROM files WHERE upload_id=? AND id=?", (uid, fid)
            ).fetchone()[0]
            if offset < 0 or offset + len(data) > item.sizeBytes or offset > confirmed:
                raise Rejected("offset_conflict")
            path = self.root / "uploads" / uid / fid
            with path.open("r+b") as stream:
                if path.stat().st_size < confirmed:
                    raise Rejected("storage_inconsistent", 500)
                stream.truncate(confirmed)
                if offset < confirmed:
                    stream.seek(offset)
                    if offset + len(data) > confirmed or stream.read(len(data)) != data:
                        raise Rejected("chunk_conflict")
                else:
                    stream.seek(confirmed)
                    stream.write(data)
                    stream.flush()
                    os.fsync(stream.fileno())
                    confirmed += len(data)
                    db.execute(
                        "UPDATE files SET confirmed=? WHERE upload_id=? AND id=?",
                        (confirmed, uid, fid),
                    )
            db.execute(
                "UPDATE uploads SET expires=? WHERE id=?",
                (self.clock() + self.settings.retention_seconds, uid),
            )
            return {"offset": confirmed}

    def seal(self, owner, uid):
        # Validation runs outside the global ledger lock on immutable full files;
        # a second transaction rechecks state/offsets before the sealing commit.
        with self.transaction() as db:
            row = self._upload(db, owner, uid)
            if row["state"] == "sealed":
                return self._upload_view(db, row)
            request = UploadRequest.model_validate_json(row["request"])
            for item in request.files:
                confirmed = db.execute(
                    "SELECT confirmed FROM files WHERE upload_id=? AND id=?", (uid, item.fileId)
                ).fetchone()[0]
                if confirmed != item.sizeBytes:
                    raise Rejected("upload_incomplete")
        for item in request.files:
            path = self.root / "uploads" / uid / item.fileId
            try:
                with path.open("rb") as stream:
                    if hashlib.file_digest(stream, "sha256").hexdigest() != item.sha256:
                        raise Rejected("digest_mismatch", 422)
                info = subprocess.run(
                    [
                        "ffprobe",
                        "-v",
                        "error",
                        "-select_streams",
                        "a:0",
                        "-show_entries",
                        "stream=codec_type,sample_rate,channels:format=duration",
                        "-of",
                        "json",
                        str(path),
                    ],
                    capture_output=True,
                    timeout=30,
                    check=True,
                )
                meta = json.loads(info.stdout)
                if not meta["streams"]:
                    raise Rejected("invalid_media", 422)
                validate_samples(path, item.durationMs)
            except (subprocess.SubprocessError, ValueError, KeyError, OSError):
                raise Rejected("invalid_media", 422) from None
        with self.transaction() as db:
            row = self._upload(db, owner, uid)
            db.execute("UPDATE uploads SET state='sealed' WHERE id=?", (uid,))
            return self._upload_view(db, self._upload(db, owner, uid))

    def create_job(self, owner, idem, request):
        digest = canonical_digest(request.model_dump())
        with self.transaction() as db:
            row = db.execute(
                "SELECT * FROM jobs WHERE owner=? AND idem=?", (owner, idem)
            ).fetchone()
            if row:
                if row["digest"] != digest:
                    raise Rejected("idempotency_conflict")
                return self._job_view(row)
            upload = self._upload(db, owner, request.uploadId)
            if upload["state"] != "sealed":
                raise Rejected("upload_incomplete")
            jid = uuid.uuid4().hex
            db.execute(
                """INSERT INTO jobs(id,owner,idem,digest,upload_id,profile,state,created)
                          VALUES (?,?,?,?,?,?,'queued',?)""",
                (jid, owner, idem, digest, request.uploadId, request.profileId, self.clock()),
            )
            return self._job_view(self._job(db, owner, jid))

    def _job(self, db, owner, jid):
        row = db.execute("SELECT * FROM jobs WHERE id=? AND owner=?", (jid, owner)).fetchone()
        if row is None:
            raise Rejected("not_found", 404)
        return row

    def _job_view(self, row):
        return {
            "schemaVersion": 1,
            "jobId": row["id"],
            "uploadId": row["upload_id"],
            "profileId": row["profile"],
            "state": row["state"],
            "attempt": row["attempts"],
            "error": row["error"],
            "expiresAt": int(row["expires"] * 1000) if row["expires"] is not None else None,
        }

    def job(self, owner, jid):
        with self.transaction() as db:
            return self._job_view(self._job(db, owner, jid))

    def cancel(self, owner, jid):
        with self.transaction() as db:
            row = self._job(db, owner, jid)
            db.execute(
                "UPDATE jobs SET state='cancelled',generation=generation+1,lease=NULL,expires=? WHERE id=? AND state!='cancelled'",
                (self.clock() + self.settings.retention_seconds, jid),
            )
            if row["result_path"]:
                (self.root / row["result_path"]).unlink(missing_ok=True)
            return self._job_view(self._job(db, owner, jid))

    def result(self, owner, jid):
        with self.transaction() as db:
            row = self._job(db, owner, jid)
            if row["state"] == "expired" or (
                row["expires"] is not None and row["expires"] <= self.clock()
            ):
                raise Rejected("result_expired", 410)
            if row["state"] != "succeeded":
                raise Rejected("result_unavailable")
            return json.loads((self.root / row["result_path"]).read_text())

    def claim(self):
        now = self.clock()
        with self.transaction() as db:
            db.execute(
                "UPDATE jobs SET state=CASE WHEN attempts>=? THEN 'failed' ELSE 'queued' END,error='worker_lost',lease=NULL,expires=CASE WHEN attempts>=? THEN ? ELSE NULL END WHERE state='running' AND lease<=?",
                (
                    self.settings.max_attempts,
                    self.settings.max_attempts,
                    now + self.settings.retention_seconds,
                    now,
                ),
            )
            if db.execute("SELECT 1 FROM jobs WHERE state='running' LIMIT 1").fetchone():
                return None
            row = db.execute(
                "SELECT * FROM jobs WHERE state='queued' ORDER BY created,id LIMIT 1"
            ).fetchone()
            if row is None:
                return None
            db.execute(
                "UPDATE jobs SET state='running',generation=generation+1,attempts=attempts+1,lease=?,error=NULL WHERE id=?",
                (now + self.settings.lease_seconds, row["id"]),
            )
            claimed = dict(db.execute("SELECT * FROM jobs WHERE id=?", (row["id"],)).fetchone())
            upload = db.execute("SELECT * FROM uploads WHERE id=?", (row["upload_id"],)).fetchone()
            claimed["upload"] = json.loads(upload["request"])
            claimed["audioManifestDigest"] = upload["digest"]
            return claimed

    def heartbeat(self, jid, generation):
        with self.transaction() as db:
            return (
                db.execute(
                    "UPDATE jobs SET lease=? WHERE id=? AND generation=? AND state='running' AND lease>?",
                    (self.clock() + self.settings.lease_seconds, jid, generation, self.clock()),
                ).rowcount
                == 1
            )

    def finish(self, claim, value):
        result = TranscriptResult.model_validate(value)
        expected = claim["upload"]
        if (
            result.jobId != claim["id"]
            or result.audioManifestDigest != claim["audioManifestDigest"]
            or result.meetingId != expected["meetingId"]
            or result.runId != expected["runId"]
            or result.durationMs != sum(f["durationMs"] for f in expected["files"])
        ):
            raise Rejected("result_identity", 422)
        with self.transaction() as db:
            row = db.execute("SELECT * FROM jobs WHERE id=?", (claim["id"],)).fetchone()
            if (
                row["state"] != "running"
                or row["generation"] != claim["generation"]
                or row["lease"] <= self.clock()
            ):
                return False
            relative = f"results/{claim['id']}-{claim['generation']}.json"
            path = self.root / relative
            temporary = path.with_suffix(".tmp")
            with temporary.open("w") as out:
                out.write(result.model_dump_json())
                out.flush()
                os.fsync(out.fileno())
            os.replace(temporary, path)
            self._sync_dir(path.parent)
            db.execute(
                "UPDATE jobs SET state='succeeded',result_path=?,lease=NULL,expires=? WHERE id=?",
                (relative, self.clock() + self.settings.retention_seconds, claim["id"]),
            )
            return True

    def fail(self, claim, code, retryable=False):
        with self.transaction() as db:
            state = (
                "queued"
                if retryable and claim["attempts"] < self.settings.max_attempts
                else "failed"
            )
            return (
                db.execute(
                    "UPDATE jobs SET state=?,error=?,lease=NULL,expires=? WHERE id=? AND generation=? AND state='running'",
                    (
                        state,
                        code,
                        None
                        if state == "queued"
                        else self.clock() + self.settings.retention_seconds,
                        claim["id"],
                        claim["generation"],
                    ),
                ).rowcount
                == 1
            )

    def cleanup(self):
        now = self.clock()
        with self.transaction() as db:
            referenced = {
                r["result_path"]
                for r in db.execute("SELECT result_path FROM jobs WHERE result_path IS NOT NULL")
            }
            # finish holds this same lock over rename + pointer commit. Anything
            # unreferenced here was abandoned by a crash, not a live publisher.
            for path in (self.root / "results").iterdir():
                if str(path.relative_to(self.root)) not in referenced:
                    path.unlink(missing_ok=True)
            known_uploads = {r["id"] for r in db.execute("SELECT id FROM uploads")}
            for folder in (self.root / "uploads").iterdir():
                if folder.name not in known_uploads:
                    shutil.rmtree(folder)
            for row in db.execute(
                "SELECT * FROM jobs WHERE expires<=? AND state IN ('succeeded','failed','cancelled')",
                (now,),
            ).fetchall():
                if row["result_path"]:
                    (self.root / row["result_path"]).unlink(missing_ok=True)
                shutil.rmtree(self.root / "work" / row["id"], ignore_errors=False) if (
                    self.root / "work" / row["id"]
                ).exists() else None
                db.execute(
                    "UPDATE jobs SET state='expired',result_path=NULL WHERE id=?", (row["id"],)
                )
            rows = db.execute(
                """SELECT * FROM uploads u WHERE state!='expired' AND expires<=?
                AND NOT EXISTS (SELECT 1 FROM jobs j WHERE j.upload_id=u.id AND j.state!='expired')""",
                (now,),
            ).fetchall()
            for row in rows:
                folder = self.root / "uploads" / row["id"]
                if folder.exists():
                    shutil.rmtree(folder)
                db.execute("UPDATE uploads SET state='expired' WHERE id=?", (row["id"],))

    @staticmethod
    def _sync_dir(path: Path):
        fd = os.open(path, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

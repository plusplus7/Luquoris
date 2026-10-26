"""Authenticated metadata/upload API. Models are never loaded in this process."""

import re

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

from .config import Settings
from .contracts import JobRequest, UploadRequest
from .store import Rejected, Store


def create_app(settings: Settings | None = None):
    settings = settings or Settings.from_env()
    store = Store(settings)
    app = FastAPI(title="Loquiris transcription", docs_url=None, redoc_url=None)
    app.state.store = store

    @app.exception_handler(Rejected)
    async def rejected(_request, error):
        return JSONResponse({"error": {"code": error.code}}, status_code=error.status)

    @app.exception_handler(RequestValidationError)
    async def invalid(_request, _error):
        # Pydantic's default response echoes rejected input, including transcript text.
        return JSONResponse({"error": {"code": "invalid_request"}}, status_code=422)

    @app.middleware("http")
    async def body_limit(request: Request, call_next):
        limit = settings.chunk_bytes if request.method == "PUT" else 1024 * 1024
        length = request.headers.get("content-length")
        if length:
            try:
                if int(length) > limit or int(length) < 0:
                    return JSONResponse({"error": {"code": "request_too_large"}}, status_code=413)
            except ValueError:
                return JSONResponse({"error": {"code": "invalid_length"}}, status_code=400)
        data = bytearray()
        async for chunk in request.stream():
            if len(data) + len(chunk) > limit:
                return JSONResponse({"error": {"code": "request_too_large"}}, status_code=413)
            data.extend(chunk)
        # BaseHTTPMiddleware forwards the cached bounded body to the endpoint.
        request._body = bytes(data)
        return await call_next(request)

    def owner(authorization: str = Header(default="")):
        scheme, _, token = authorization.partition(" ")
        identity = settings.owner_for(token) if scheme == "Bearer" else None
        if identity is None:
            raise HTTPException(401, detail={"code": "unauthorized"})
        return identity

    def key(idempotency_key: str = Header()):
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", idempotency_key):
            raise Rejected("invalid_idempotency_key", 422)
        return idempotency_key

    @app.get("/health/live")
    def live():
        return {"status": "alive"}

    @app.get("/health/ready")
    def readiness(identity=Depends(owner)):
        from .readiness import ready

        if not ready(store.root):
            raise Rejected("worker_unready", 503)
        return {"status": "ready"}

    @app.get("/v1/capabilities")
    def capabilities(identity=Depends(owner)):
        return {
            "schemaVersion": 1,
            "profiles": list(settings.profiles),
            "retentionSeconds": settings.retention_seconds,
            "chunkBytes": settings.chunk_bytes,
            "maxUploadBytes": settings.max_upload_bytes,
            "mode": "postSession",
        }

    @app.post("/v1/uploads")
    def create_upload(request: UploadRequest, identity=Depends(owner), idem=Depends(key)):
        return store.create_upload(identity, idem, request)

    @app.get("/v1/uploads/{uid}")
    def upload(uid: str, identity=Depends(owner)):
        return store.upload(identity, uid)

    @app.put("/v1/uploads/{uid}/files/{fid}")
    async def chunk(uid: str, fid: str, request: Request, offset: int, identity=Depends(owner)):
        # Body middleware caps both Content-Length and chunked transfer.
        data = await request.body()
        return await run_in_threadpool(store.chunk, identity, uid, fid, offset, data)

    @app.post("/v1/uploads/{uid}/complete")
    def seal(uid: str, identity=Depends(owner)):
        return store.seal(identity, uid)

    @app.post("/v1/transcriptions")
    def create_job(request: JobRequest, identity=Depends(owner), idem=Depends(key)):
        return store.create_job(identity, idem, request)

    @app.get("/v1/transcriptions/{jid}")
    def job(jid: str, identity=Depends(owner)):
        return store.job(identity, jid)

    @app.get("/v1/transcriptions/{jid}/result")
    def result(jid: str, identity=Depends(owner)):
        return store.result(identity, jid)

    @app.delete("/v1/transcriptions/{jid}")
    def cancel(jid: str, identity=Depends(owner)):
        return store.cancel(identity, jid)

    return app

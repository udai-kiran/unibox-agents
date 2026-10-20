from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse

from trace_store import trace_data_dir, trace_group_threads, trace_list_messages

app = FastAPI(title="unibox-agents traces")
STATIC = Path(__file__).parent / "static"


@app.get("/healthz")
def trace_healthz() -> dict:
    return {"ok": True}


@app.get("/api/messages")
def trace_api_messages() -> list[dict]:
    return trace_list_messages(trace_data_dir())


@app.get("/api/threads")
def trace_api_threads() -> list[dict]:
    return trace_group_threads(trace_list_messages(trace_data_dir()))


@app.get("/")
def trace_index() -> FileResponse:
    return FileResponse(STATIC / "index.html")

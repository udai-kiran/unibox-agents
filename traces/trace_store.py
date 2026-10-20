"""Read-only view of an inodex data directory: every message in every mailbox."""
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

TRACE_AGENT_NAME = re.compile(r"^[a-z0-9_-]{1,64}$")
# mailbox directory -> state shown to the user
TRACE_STATES = {"inbox": "pending", "processing": "claimed", "archive": "acked", "deadletter": "deadletter"}
TRACE_MAX_BYTES = 1024 * 1024


def trace_data_dir() -> Path:
    return Path(os.environ.get("INODEX_DATA_DIR") or Path.home() / ".inodex")


def _trace_read_file(path: Path) -> dict | None:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > TRACE_MAX_BYTES:
        return None
    try:
        msg = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    return msg if isinstance(msg, dict) and isinstance(msg.get("id"), str) else None


def trace_list_messages(data_dir: Path) -> list[dict]:
    """All messages, oldest first. Adds `mailbox`, `state` and `state_changed_at` to each."""
    messages = []
    agents = data_dir / "agents"
    if not agents.is_dir():
        return messages
    for agent_dir in sorted(agents.iterdir()):
        if not TRACE_AGENT_NAME.match(agent_dir.name) or agent_dir.is_symlink():
            continue
        for box, state in TRACE_STATES.items():
            for path in sorted((agent_dir / box).glob("*.json")):
                msg = _trace_read_file(path)
                if msg is None:
                    continue
                # a rename changes ctime, so this is when the message entered its current state
                changed = datetime.fromtimestamp(path.stat().st_ctime, timezone.utc).isoformat()
                messages.append({**msg, "mailbox": agent_dir.name, "state": state, "state_changed_at": changed})
    messages.sort(key=lambda m: (str(m.get("timestamp", "")), m["id"]))
    return messages


def _trace_round(msg: dict) -> int | None:
    payload = msg.get("payload")
    value = payload.get("round") if isinstance(payload, dict) else None
    return value if isinstance(value, int) else None


def trace_group_threads(messages: list[dict]) -> list[dict]:
    """Group messages by correlation_id. Messages without one go in the thread named ''."""
    threads: dict[str, list[dict]] = {}
    for msg in messages:
        threads.setdefault(str(msg.get("correlation_id") or ""), []).append(msg)
    result = []
    for correlation_id, msgs in threads.items():
        rounds = [r for m in msgs if m.get("type") == "review.requested" if (r := _trace_round(m)) is not None]
        verdicts = [
            m["payload"].get("verdict")
            for m in msgs
            if m.get("type") == "review.result" and isinstance(m.get("payload"), dict)
        ]
        result.append({
            "correlation_id": correlation_id,
            "started": msgs[0].get("timestamp"),
            "rounds": max(rounds, default=0),
            "last_verdict": verdicts[-1] if verdicts else None,
            "messages": msgs,
        })
    result.sort(key=lambda t: str(t["started"]))
    return result

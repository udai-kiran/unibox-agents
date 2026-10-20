import json

from trace_store import trace_group_threads, trace_list_messages


def _put(root, agent, box, name, msg):
    d = root / "agents" / agent / box
    d.mkdir(parents=True, exist_ok=True)
    (d / name).write_text(json.dumps(msg))


def _msg(id, type, cid, ts, payload=None, frm="a", to="b"):
    return {"id": id, "from": frm, "to": to, "type": type, "correlation_id": cid, "timestamp": ts, "payload": payload or {}}


def test_list_adds_state_and_orders_by_timestamp(tmp_path):
    _put(tmp_path, "b", "archive", "2.json", _msg("2", "task.completed", "T-1", "2026-01-01T00:00:02Z"))
    _put(tmp_path, "b", "inbox", "1.json", _msg("1", "task.assigned", "T-1", "2026-01-01T00:00:01Z"))
    out = trace_list_messages(tmp_path)
    assert [(m["id"], m["state"], m["mailbox"]) for m in out] == [("1", "pending", "b"), ("2", "acked", "b")]
    assert "state_changed_at" in out[0]


def test_list_skips_bad_files_and_bad_agent_names(tmp_path):
    _put(tmp_path, "b", "inbox", "bad.json", {"no": "id"})
    (tmp_path / "agents" / "b" / "inbox" / "junk.json").write_text("{not json")
    _put(tmp_path, "Bad Name", "inbox", "1.json", _msg("1", "x", "T", "t"))
    assert trace_list_messages(tmp_path) == []


def test_list_missing_dir_is_empty(tmp_path):
    assert trace_list_messages(tmp_path / "nope") == []


def test_group_counts_rounds_and_last_verdict():
    msgs = [
        _msg("1", "review.requested", "T-1", "t1", {"round": 1}),
        _msg("2", "review.result", "T-1", "t2", {"verdict": "changes_requested"}),
        _msg("3", "review.requested", "T-1", "t3", {"round": 2}),
        _msg("4", "review.result", "T-1", "t4", {"verdict": "approve"}),
        _msg("5", "task.assigned", "T-2", "t5"),
    ]
    threads = trace_group_threads(msgs)
    assert [t["correlation_id"] for t in threads] == ["T-1", "T-2"]
    assert threads[0]["rounds"] == 2 and threads[0]["last_verdict"] == "approve"
    assert threads[1]["rounds"] == 0 and threads[1]["last_verdict"] is None

import json
import sys
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread

sys.path.insert(0, str(Path(__file__).parents[1]))


def load_server_module(monkeypatch, token: str | None, activity_file: Path):
    monkeypatch.setenv("NCOM_ACTIVITY_FILE", str(activity_file))
    if token is None:
        monkeypatch.delenv("NCOM_FEED_TOKEN", raising=False)
    else:
        monkeypatch.setenv("NCOM_FEED_TOKEN", token)
    sys.modules.pop("ncom_server", None)
    import ncom_server

    return ncom_server


def request(handler_class, method: str, path: str, body: bytes = b"", headers: dict[str, str] | None = None):
    httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler_class)
    thread = Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    try:
        conn = HTTPConnection("127.0.0.1", httpd.server_port, timeout=3)
        conn.request(method, path, body=body, headers=headers or {})
        response = conn.getresponse()
        payload = response.read()
        return response.status, payload
    finally:
        httpd.shutdown()
        thread.join(timeout=3)
        httpd.server_close()


def test_workspace_is_reachable_without_optional_token(monkeypatch, tmp_path):
    server = load_server_module(monkeypatch, None, tmp_path / "activity.json")

    status, payload = request(server.Handler, "GET", "/v1/workspace")
    assert status == 200
    data = json.loads(payload)
    assert data["service"] == "ncom"
    assert data["state"] == "ready"


def test_workspace_requires_configured_token(monkeypatch, tmp_path):
    server = load_server_module(monkeypatch, "secret", tmp_path / "activity.json")

    status, _ = request(server.Handler, "GET", "/v1/workspace")
    assert status == 401

    status, _ = request(
        server.Handler,
        "GET",
        "/v1/workspace",
        headers={"X-NCOM-Feed-Token": "secret"},
    )
    assert status == 200


def test_activity_round_trip(monkeypatch, tmp_path):
    server = load_server_module(monkeypatch, None, tmp_path / "activity.json")
    body = json.dumps({"phase": "Building", "detail": "Swift compile", "hasScreenshot": False}).encode()

    status, _ = request(
        server.Handler,
        "POST",
        "/v1/activity",
        body=body,
        headers={"Content-Type": "application/json"},
    )
    assert status == 200

    status, payload = request(server.Handler, "GET", "/v1/activity")
    assert status == 200
    assert json.loads(payload)["phase"] == "Building"

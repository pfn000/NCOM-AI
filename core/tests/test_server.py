import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))


def load_server_module():
    # The server reads environment variables at import time, so tests control them explicitly.
    os.environ.pop("NCOM_FEED_TOKEN", None)
    import ncom_server

    return ncom_server


def make_handler(server_module):
    return server_module.Handler


def request(handler_class, method, path, body=b"", headers=None):
    from http.client import HTTPConnection
    from threading import Thread

    class Server(handler_class.__mro__[1]):
        pass

    # Use an in-process HTTP server subclass with the production handler.
    from http.server import ThreadingHTTPServer

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
    monkeypatch.delenv("NCOM_FEED_TOKEN", raising=False)
    monkeypatch.setenv("NCOM_ACTIVITY_FILE", str(tmp_path / "activity.json"))
    sys.modules.pop("ncom_server", None)
    server = load_server_module()

    status, payload = request(make_handler(server), "GET", "/v1/workspace")
    assert status == 200
    data = json.loads(payload)
    assert data["service"] == "ncom"
    assert data["state"] == "ready"


def test_workspace_requires_configured_token(monkeypatch, tmp_path):
    monkeypatch.setenv("NCOM_FEED_TOKEN", "secret")
    monkeypatch.setenv("NCOM_ACTIVITY_FILE", str(tmp_path / "activity.json"))
    sys.modules.pop("ncom_server", None)
    server = load_server_module()

    status, _ = request(make_handler(server), "GET", "/v1/workspace")
    assert status == 401

    status, _ = request(
        make_handler(server),
        "GET",
        "/v1/workspace",
        headers={"X-NCOM-Feed-Token": "secret"},
    )
    assert status == 200


def test_activity_round_trip(monkeypatch, tmp_path):
    monkeypatch.delenv("NCOM_FEED_TOKEN", raising=False)
    monkeypatch.setenv("NCOM_ACTIVITY_FILE", str(tmp_path / "activity.json"))
    sys.modules.pop("ncom_server", None)
    server = load_server_module()
    body = json.dumps({"phase": "Building", "detail": "Swift compile", "hasScreenshot": False}).encode()

    status, _ = request(
        make_handler(server),
        "POST",
        "/v1/activity",
        body=body,
        headers={"Content-Type": "application/json"},
    )
    assert status == 200

    status, payload = request(make_handler(server), "GET", "/v1/activity")
    assert status == 200
    assert json.loads(payload)["phase"] == "Building"

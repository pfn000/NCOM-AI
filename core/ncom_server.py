from __future__ import annotations

import json
import os
import shutil
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

MODEL = Path(os.environ["NCOM_MODEL"]) if os.environ.get("NCOM_MODEL") else None
ACTIVITY_FILE = Path(os.environ.get("NCOM_ACTIVITY_FILE", "~/.config/ncom/activity.json")).expanduser()
FEED_TOKEN = os.environ.get("NCOM_FEED_TOKEN", "")
DEFAULT_HOST = os.environ.get("NCOM_HOST", "0.0.0.0")
DEFAULT_PORT = int(os.environ.get("NCOM_PORT", "8765"))


def json_bytes(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload).encode("utf-8")


def activity_payload() -> dict[str, Any]:
    if ACTIVITY_FILE.exists():
        try:
            payload = json.loads(ACTIVITY_FILE.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                return payload
        except (OSError, json.JSONDecodeError):
            pass
    return {
        "phase": "Idle",
        "detail": "No active desktop task is being reported.",
        "hasScreenshot": False,
    }


def write_activity(payload: dict[str, Any]) -> None:
    ACTIVITY_FILE.parent.mkdir(parents=True, exist_ok=True)
    temp = ACTIVITY_FILE.with_suffix(ACTIVITY_FILE.suffix + ".tmp")
    temp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    temp.replace(ACTIVITY_FILE)


def feed_authorized(headers: Any) -> bool:
    # A token is optional for a deliberately local development runtime.
    # When NCOM_FEED_TOKEN is configured, every workspace endpoint requires it.
    return not FEED_TOKEN or headers.get("X-NCOM-Feed-Token", "") == FEED_TOKEN


def screenshot_bytes() -> bytes:
    commands = [
        ["grim", "-"],
        ["spectacle", "-b", "-n", "-o", "-"],
        ["gnome-screenshot", "-f", "-"],
    ]
    for command in commands:
        if shutil.which(command[0]) is None:
            continue
        try:
            result = subprocess.run(command, check=True, capture_output=True, timeout=10)
            if result.stdout:
                return result.stdout
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            continue
    raise RuntimeError("No supported desktop screenshot command is available")


class Handler(BaseHTTPRequestHandler):
    server_version = "NCOM/0.3"

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-NCOM-Feed-Token")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_json(self, code: int, payload: dict[str, Any]) -> None:
        self._send(code, json_bytes(payload), "application/json")

    def do_OPTIONS(self) -> None:
        self._send_json(204, {})

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {
                "service": "ncom",
                "state": "ready",
                "model_configured": MODEL is not None,
                "desktop_feed": True,
                "desktop_feed_auth": "token" if FEED_TOKEN else "disabled",
                "desktop_workspace": True,
                "workspace_endpoints": [
                    "/v1/activity",
                    "/v1/display/screenshot",
                    "/v1/workspace",
                ],
            })
            return

        if self.path == "/v1/activity":
            if not feed_authorized(self.headers):
                self._send_json(401, {"error": "desktop feed requires X-NCOM-Feed-Token"})
                return
            self._send_json(200, activity_payload())
            return

        if self.path == "/v1/display/screenshot":
            if not feed_authorized(self.headers):
                self._send_json(401, {"error": "desktop feed requires X-NCOM-Feed-Token"})
                return
            try:
                self._send(200, screenshot_bytes(), "image/png")
            except RuntimeError as exc:
                self._send_json(503, {"error": str(exc)})
            return

        if self.path == "/v1/workspace":
            if not feed_authorized(self.headers):
                self._send_json(401, {"error": "workspace requires X-NCOM-Feed-Token"})
                return
            self._send_json(200, {
                "service": "ncom",
                "state": "ready",
                "activity": activity_payload(),
                "model_configured": MODEL is not None,
            })
            return

        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path == "/v1/activity":
            if not feed_authorized(self.headers):
                self._send_json(401, {"error": "desktop feed requires X-NCOM-Feed-Token"})
                return
            length = int(self.headers.get("Content-Length", "0"))
            try:
                payload = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                self._send_json(400, {"error": "invalid JSON"})
                return
            if not isinstance(payload, dict):
                self._send_json(400, {"error": "activity payload must be an object"})
                return
            write_activity(payload)
            self._send_json(200, {"ok": True, "activity": activity_payload()})
            return

        if self.path != "/v1/chat":
            self._send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid JSON"})
            return
        messages = payload.get("messages")
        if not isinstance(messages, list) or not messages:
            self._send_json(400, {"error": "messages must be a non-empty list"})
            return
        if MODEL is None:
            self._send_json(503, {"error": "No local GGUF model configured. Set NCOM_MODEL before starting NCOM."})
            return
        self._send_json(501, {"error": "GGUF generation adapter is not enabled yet; model discovery is active."})


def main() -> None:
    host = DEFAULT_HOST
    port = DEFAULT_PORT
    print(f"NCOM listening on http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == "__main__":
    main()

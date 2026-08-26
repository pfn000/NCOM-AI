from __future__ import annotations

import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MODEL = Path(os.environ["NCOM_MODEL"]) if os.environ.get("NCOM_MODEL") else None
ACTIVITY_FILE = Path(os.environ.get("NCOM_ACTIVITY_FILE", "~/.config/ncom/activity.json")).expanduser()
FEED_TOKEN = os.environ.get("NCOM_FEED_TOKEN", "")


def json_bytes(payload: dict) -> bytes:
    return json.dumps(payload).encode("utf-8")


def activity_payload() -> dict:
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


class Handler(BaseHTTPRequestHandler):
    server_version = "NCOM/0.2"

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-NCOM-Feed-Token")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_json(self, code: int, payload: dict) -> None:
        self._send(code, json_bytes(payload), "application/json")

    def _feed_authorized(self) -> bool:
        if not FEED_TOKEN:
            return False
        return self.headers.get("X-NCOM-Feed-Token", "") == FEED_TOKEN

    def do_OPTIONS(self) -> None:
        self._send_json(204, {})

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {
                "service": "ncom",
                "state": "ready",
                "model_configured": MODEL is not None,
                "desktop_feed": bool(FEED_TOKEN),
            })
            return

        if self.path == "/v1/activity":
            if not self._feed_authorized():
                self._send_json(401, {"error": "desktop feed requires X-NCOM-Feed-Token"})
                return
            self._send_json(200, activity_payload())
            return

        if self.path == "/v1/display/screenshot":
            if not self._feed_authorized():
                self._send_json(401, {"error": "desktop feed requires X-NCOM-Feed-Token"})
                return
            try:
                result = subprocess.run(["grim", "-"], check=True, capture_output=True, timeout=10)
            except FileNotFoundError:
                self._send_json(503, {"error": "grim is not installed; desktop screenshot capture is unavailable"})
                return
            except subprocess.CalledProcessError as exc:
                self._send_json(503, {"error": f"desktop screenshot failed with exit code {exc.returncode}"})
                return
            self._send(200, result.stdout, "image/png")
            return

        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
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
    host = os.environ.get("NCOM_HOST", "127.0.0.1")
    port = int(os.environ.get("NCOM_PORT", "8765"))
    print(f"NCOM listening on http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == "__main__":
    main()

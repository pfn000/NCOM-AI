from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MODEL = Path(os.environ["NCOM_MODEL"]) if os.environ.get("NCOM_MODEL") else None


def json_bytes(payload: dict) -> bytes:
    return json.dumps(payload).encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    server_version = "NCOM/0.1"

    def _send(self, code: int, payload: dict) -> None:
        body = json_bytes(payload)
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self._send(204, {})

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send(200, {"service": "ncom", "state": "ready", "model_configured": MODEL is not None})
            return
        self._send(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/v1/chat":
            self._send(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid JSON"})
            return
        messages = payload.get("messages")
        if not isinstance(messages, list) or not messages:
            self._send(400, {"error": "messages must be a non-empty list"})
            return
        if MODEL is None:
            self._send(503, {"error": "No local GGUF model configured. Set NCOM_MODEL before starting NCOM."})
            return
        self._send(501, {"error": "GGUF generation adapter is not enabled yet; model discovery is active."})


def main() -> None:
    host = os.environ.get("NCOM_HOST", "127.0.0.1")
    port = int(os.environ.get("NCOM_PORT", "8765"))
    print(f"NCOM listening on http://{host}:{port}")
    ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == "__main__":
    main()

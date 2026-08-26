from __future__ import annotations

import json
import os
import sys
import threading
import urllib.request
from pathlib import Path
import tkinter as tk
from http.server import ThreadingHTTPServer
from tkinter import messagebox, simpledialog

DEFAULT_ENDPOINT = os.environ.get("NCOM_ENDPOINT", "http://127.0.0.1:8765")
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


def post_json(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode())


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.loads(response.read().decode())


def publish_activity(endpoint: str, phase: str, detail: str, has_screenshot: bool = False) -> None:
    post_json(endpoint.rstrip("/") + "/v1/activity", {"phase": phase, "detail": detail, "hasScreenshot": has_screenshot})


def start_embedded_runtime() -> ThreadingHTTPServer | None:
    """Start the local workspace runtime when nothing is already listening."""
    try:
        from core import ncom_server
    except ImportError:
        return None

    host = ncom_server.DEFAULT_HOST
    port = ncom_server.DEFAULT_PORT
    try:
        server = ThreadingHTTPServer((host, port), ncom_server.Handler)
    except OSError:
        # An existing runtime may already be serving the configured port.
        return None

    thread = threading.Thread(target=server.serve_forever, name="ncom-runtime", daemon=True)
    thread.start()
    return server


class NCOMDesktop(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("NCOM AI")
        self.geometry("980x680")
        self.minsize(800, 520)
        self.endpoint = DEFAULT_ENDPOINT
        self.runtime_server = start_embedded_runtime()

        header = tk.Frame(self, padx=16, pady=12)
        header.pack(fill="x")
        tk.Label(header, text="NCOM AI", font=("TkDefaultFont", 20, "bold")).pack(side="left")
        self.status = tk.Label(header, text="starting runtime…", padx=12)
        self.status.pack(side="right")

        body = tk.Frame(self)
        body.pack(fill="both", expand=True, padx=16)
        self.output = tk.Text(body, wrap="word", state="disabled")
        self.output.pack(fill="both", expand=True)

        controls = tk.Frame(self, padx=16, pady=12)
        controls.pack(fill="x")
        self.entry = tk.Entry(controls)
        self.entry.pack(side="left", fill="x", expand=True)
        self.entry.bind("<Return>", lambda _: self.send())
        tk.Button(controls, text="Send", command=self.send).pack(side="left", padx=6)
        tk.Button(controls, text="Endpoint", command=self.change_endpoint).pack(side="left")
        tk.Button(controls, text="Health", command=self.health).pack(side="left", padx=6)

        footer = tk.Frame(self, padx=16, pady=8)
        footer.pack(fill="x")
        tk.Label(footer, text="Local-first • CPU inference • MCP-ready • workspace runtime active").pack(side="left")

        self.protocol("WM_DELETE_WINDOW", self.close)
        self.after(100, self.health)

    def write(self, text: str) -> None:
        self.output.configure(state="normal")
        self.output.insert("end", text + "\n")
        self.output.see("end")
        self.output.configure(state="disabled")

    def change_endpoint(self) -> None:
        value = simpledialog.askstring("NCOM endpoint", "Endpoint URL:", initialvalue=self.endpoint)
        if value:
            self.endpoint = value.rstrip("/")
            self.health()

    def health(self) -> None:
        def run() -> None:
            try:
                data = get_json(self.endpoint + "/health")
                self.after(0, lambda: self.status.configure(text=f"ready • {data.get('state', 'unknown')}"))
                publish_activity(self.endpoint, "Idle", "NCOM Desktop is connected and ready")
            except Exception as exc:
                self.after(0, lambda: self.status.configure(text="offline"))
                self.after(0, lambda: self.write(f"Health check failed: {exc}"))
        threading.Thread(target=run, daemon=True).start()

    def send(self) -> None:
        message = self.entry.get().strip()
        if not message:
            return
        self.entry.delete(0, "end")
        self.write(f"You: {message}")

        def run() -> None:
            try:
                publish_activity(self.endpoint, "Running", f"Processing: {message[:140]}")
                data = post_json(self.endpoint + "/v1/chat", {"messages": [{"role": "user", "content": message}]})
                reply = data.get("content") or data.get("error") or str(data)
                publish_activity(self.endpoint, "Idle", "NCOM Desktop is ready")
            except Exception as exc:
                reply = f"Connection error: {exc}"
                try:
                    publish_activity(self.endpoint, "Error", reply)
                except Exception:
                    pass
            self.after(0, lambda: self.write(f"NCOM: {reply}"))

        threading.Thread(target=run, daemon=True).start()

    def close(self) -> None:
        if self.runtime_server is not None:
            self.runtime_server.shutdown()
            self.runtime_server.server_close()
        self.destroy()


if __name__ == "__main__":
    try:
        NCOMDesktop().mainloop()
    except tk.TclError as exc:
        messagebox.showerror("NCOM AI", str(exc))

from __future__ import annotations

import json
import os
import threading
import urllib.request
import tkinter as tk
from tkinter import messagebox, simpledialog

DEFAULT_ENDPOINT = os.environ.get("NCOM_ENDPOINT", "http://127.0.0.1:8765")
REPO_URL = "https://github.com/pfn000/NCOM-AI"


def post_json(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode())


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.loads(response.read().decode())


class NCOMDesktop(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("NCOM AI")
        self.geometry("980x680")
        self.minsize(800, 520)
        self.endpoint = DEFAULT_ENDPOINT

        header = tk.Frame(self, padx=16, pady=12)
        header.pack(fill="x")
        tk.Label(header, text="NCOM AI", font=("TkDefaultFont", 20, "bold")).pack(side="left")
        self.status = tk.Label(header, text="offline", padx=12)
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
        tk.Label(footer, text="Local-first • CPU inference • MCP-ready").pack(side="left")

        self.health()

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
                data = post_json(self.endpoint + "/v1/chat", {"messages": [{"role": "user", "content": message}]})
                reply = data.get("content") or data.get("error") or str(data)
            except Exception as exc:
                reply = f"Connection error: {exc}"
            self.after(0, lambda: self.write(f"NCOM: {reply}"))

        threading.Thread(target=run, daemon=True).start()


if __name__ == "__main__":
    try:
        NCOMDesktop().mainloop()
    except tk.TclError as exc:
        messagebox.showerror("NCOM AI", str(exc))

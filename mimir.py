#!/usr/bin/env python
"""mimir — sticky-note todolist widget, Windows. tkinter + keyboard hotkey."""
from __future__ import annotations
import json, os, sys, threading, uuid
from datetime import datetime
import tkinter as tk
from tkinter import ttk

DATA_DIR = os.path.join(os.path.expanduser("~"), ".mimir")
DATA = os.path.join(DATA_DIR, "notas.json")
HOTKEY = "ctrl+shift+m"  # global toggle mostrar/ocultar

HEADLESS = os.environ.get("MIMIR_HEADLESS") == "1"


def load() -> list:
    if os.path.exists(DATA):
        try:
            with open(DATA, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def save(notas: list) -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    tmp = DATA + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(notas, f, ensure_ascii=False, indent=2)
    os.replace(tmp, DATA)


def new_nota(texto="", prio="média") -> dict:
    return {
        "id": uuid.uuid4().hex[:8],
        "texto": texto,
        "done": False,
        "prio": prio,  # baixa | média | alta
        "subs": [],    # [{texto, done}]
        "criada": datetime.now().isoformat(timespec="seconds"),
        "atualizada": datetime.now().isoformat(timespec="seconds"),
    }


class Mimir:
    def __init__(self):
        self.root = tk.Tk()
        self.notas = load()
        self._no_frame = None
        self.visible = True
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        try:
            self.root.attributes("-alpha", 0.97)
        except tk.TclError:
            pass
        self.root.geometry("+80+80")
        self.root.configure(bg="#2b2b2b")
        self._build_header()
        self._build_list()
        self._bind_drag(self.root)
        self.root.bind("<Escape>", lambda _: self.toggle())

    def _build_header(self):
        bar = tk.Frame(self.root, bg="#3a3a3a", cursor="fleur")
        bar.pack(fill="x")
        tk.Label(bar, text="ᛗ mimir", bg="#3a3a3a", fg="#e8e8e8",
                 font=("Cascadia Mono", 12, "bold")).pack(side="left", padx=8, pady=4)
        tk.Button(bar, text="＋ nova", command=self.add_top,
                  bg="#3a3a3a", fg="#7CFC9A", relief="flat",
                  activebackground="#4a4a4a", font=("Segoe UI", 9)).pack(side="right", padx=4, pady=3)
        tk.Button(bar, text="✕", command=self.root.destroy,
                  bg="#3a3a3a", fg="#ff6b6b", relief="flat",
                  activebackground="#4a4a4a", font=("Segoe UI", 9)).pack(side="right", padx=2, pady=3)
        self._bind_drag(bar)
        for w in bar.winfo_children():
            self._bind_drag(w)

    def _build_list(self):
        if self._no_frame is not None:
            self._no_frame.destroy()
        self._no_frame = tk.Frame(self.root, bg="#2b2b2b")
        self._no_frame.pack(fill="x", padx=8, pady=6)
        for n in self.notas:
            self._render_nota(n)
        if not self.notas:
            tk.Label(self._no_frame, text="(sem notas — ＋ nova)",
                     bg="#2b2b2b", fg="#888", font=("Segoe UI", 10)).pack(anchor="w")

    _PRIO_COLOR = {"baixa": "#5aa7ff", "média": "#ffd54a", "alta": "#ff6b6b", "": "#fff"}

    def _render_nota(self, n):
        frame = tk.Frame(self._no_frame, bg="#353535")
        frame.pack(fill="x", pady=2, padx=2)
        row = tk.Frame(frame, bg="#353535")
        row.pack(fill="x")
        var = tk.BooleanVar(value=n["done"])
        cb = tk.Checkbutton(row, variable=var, command=lambda nn=n: self._toggle(nn),
                            bg="#353535", activebackground="#353535",
                            fg=self._PRIO_COLOR.get(n.get("prio"), "#fff"))
        cb.pack(side="left", padx=(4, 2))
        fg = self._PRIO_COLOR.get(n.get("prio"), "#fff")
        txt = tk.Text(row, height=1 + n["texto"].count("\n"), bg="#353535", fg=fg,
                      insertbackground="#fff", relief="flat", wrap="word",
                      font=("Segoe UI", 11), undo=True)
        txt.insert("1.0", n["texto"])
        txt.configure(state="disabled" if n["done"] else "normal")
        txt.pack(side="left", fill="x", expand=True, padx=2)
        txt.bind("<KeyRelease>", lambda _e, nn=n, tt=txt: self._edit(nn, tt))

        if n.get("subs"):
            sub = tk.Frame(frame, bg="#2f2f2f")
            sub.pack(fill="x", padx=22)
            for s in n["subs"]:
                sv = tk.BooleanVar(value=s["done"])
                ttk.Checkbutton(sub, text=s["texto"], variable=sv,
                                command=lambda nn=n, ss=s: self._togglesub(nn, ss),
                                style="Sub.TCheckbutton").pack(anchor="w")

        btns = tk.Frame(frame, bg="#353535")
        btns.pack(side="right", padx=4, pady=2)
        tk.Button(btns, text="＋", command=lambda nn=n: self._addsub(nn),
                  bg="#353535", fg="#aaa", relief="flat", font=("Segoe UI", 9)).pack(side="left")
        tk.Button(btns, text="⌫", command=lambda nn=n: self._delete(nn),
                  bg="#353535", fg="#ff6b6b", relief="flat", font=("Segoe UI", 9)).pack(side="left")

    def _persist(self):
        save(self.notas)

    def _edit(self, n, txt):
        n["texto"] = txt.get("1.0", "end-1c")
        n["atualizada"] = datetime.now().isoformat(timespec="seconds")
        self._persist()

    def _toggle(self, n):
        n["done"] = not n["done"]
        n["atualizada"] = datetime.now().isoformat(timespec="seconds")
        self._persist()
        self._build_list()

    def _togglesub(self, n, s):
        s["done"] = not s["done"]
        n["atualizada"] = datetime.now().isoformat(timespec="seconds")
        self._persist()

    def add_top(self):
        self.notas.insert(0, new_nota("Nova nota"))
        self._persist()
        self._build_list()

    def _addsub(self, n):
        n["subs"].append({"texto": "subtask", "done": False})
        n["atualizada"] = datetime.now().isoformat(timespec="seconds")
        self._persist()
        self._build_list()

    def _delete(self, n):
        self.notas = [x for x in self.notas if x["id"] != n["id"]]
        self._persist()
        self._build_list()

    def toggle(self):
        self.visible = not self.visible
        (self.root.deiconify if self.visible else self.root.withdraw)()

    def _bind_drag(self, w):
        w.bind("<Button-1>", self._drag_start)
        w.bind("<B1-Motion>", self._drag_move)

    def _drag_start(self, e):
        self._dx = e.x_root - self.root.winfo_x()
        self._dy = e.y_root - self.root.winfo_y()

    def _drag_move(self, e):
        self.root.geometry(f"+{e.x_root - self._dx}+{e.y_root - self._dy}")

    def _watch_hotkey(self):
        import keyboard
        keyboard.add_hotkey(HOTKEY, self.toggle)
        keyboard.wait()

    def run(self):
        if not HEADLESS:
            threading.Thread(target=self._watch_hotkey, daemon=True).start()
        self.root.mainloop()


def main():
    ttk.Style().configure("Sub.TCheckbutton", background="#2f2f2f", foreground="#ccc")
    Mimir().run()


def _selftest():
    import tempfile
    global DATA_DIR, DATA
    t = tempfile.mkdtemp()
    DATA_DIR = t
    DATA = os.path.join(t, "notas.json")
    n = new_nota("ola", "alta")
    assert n["prio"] == "alta" and n["done"] is False and not n["subs"]
    n["subs"].append({"texto": "x", "done": False})
    save([n])
    back = load()
    assert len(back) == 1 and back[0]["texto"] == "ola" and back[0]["subs"][0]["texto"] == "x"
    # toggle e delete
    back[0]["done"] = True
    save(back)
    assert load()[0]["done"] is True
    print("SELFTEST OK")


if __name__ == "__main__":
    if "--test" in sys.argv:
        _selftest()
    else:
        main()

#!/usr/bin/env python
"""mimir — sticky-note todolist widget, Windows. pywebview (WebView2) + HTML/CSS."""
from __future__ import annotations
import json, os, uuid
from datetime import datetime

DATA_DIR = os.path.join(os.path.expanduser("~"), ".mimir")
DATA = os.path.join(DATA_DIR, "notas.json")


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


class Api:
    """Exposed to JS via pywebview js_api."""
    def __init__(self):
        self.notas = load()

    def get(self):
        return self.notas

    def set(self, notas):
        self.notas = notas
        save(notas)
        return True

    def nid(self):
        return uuid.uuid4().hex[:8]

    def _set_window(self, w):
        self._w = w

    def quit(self):
        self._w.destroy()
        return True

    def now(self):
        return datetime.now().isoformat(timespec="seconds")


HTML = r"""<!DOCTYPE html>
<html lang="pt">
<head>
<meta charset="utf-8">
<style>
  :root{
    --bg:#1a1b1e; --panel:#232428; --panel2:#2b2d33; --text:#e6e6e6;
    --muted:#8b8e98; --border:#34363d; --accent:#d4a24e;
    --prio-low:#6ea8fe; --prio-med:#f9c74f; --prio-high:#f07178;
  }
  *{margin:0;padding:0;box-sizing:border-box;font-family:'Segoe UI',system-ui,sans-serif;}
  body{background:transparent;color:var(--text);overflow:hidden;user-select:none;}
  .app{background:var(--bg);border:1px solid var(--border);border-radius:14px;
       box-shadow:0 12px 40px rgba(0,0,0,.55);height:100vh;display:flex;flex-direction:column;}

  header{display:flex;align-items:center;gap:10px;padding:12px 14px;
         border-bottom:1px solid var(--border);background:var(--panel);}
  .brand{font-size:14px;font-weight:700;letter-spacing:.5px;color:var(--text);}
  .brand b{color:#d4a24e;}
  .spacer{flex:1;}
  .ico{background:none;border:none;color:var(--muted);cursor:pointer;font-size:15px;
        width:26px;height:26px;border-radius:7px;transition:.15s;}
  .ico:hover{background:var(--panel2);color:var(--text);}
  .ico.add{color:#6ee7a0;} .ico.add:hover{color:#8ff0b5;}
  .ico.hide:hover{color:#f0b371;} .ico.close:hover{color:#f07178;}

  main{flex:1;overflow-y:auto;padding:10px;display:flex;flex-direction:column;gap:9px;}
  main::-webkit-scrollbar{width:8px;} main::-webkit-scrollbar-thumb{background:var(--panel2);border-radius:4px;}

  .note{background:var(--panel);border:1px solid var(--border);border-radius:11px;
        padding:10px 12px;display:flex;flex-direction:column;gap:7px;position:relative;}
  .note[data-prio="high"]{border-left:3px solid var(--prio-high);}
  .note[data-prio="med"]{border-left:3px solid var(--prio-med);}
  .note[data-prio="low"]{border-left:3px solid var(--prio-low);}

  .note-row{display:flex;gap:9px;align-items:flex-start;}
  .chk{appearance:none;-webkit-appearance:none;width:17px;height:17px;min-width:17px;
       border:2px solid var(--muted);border-radius:5px;cursor:pointer;margin-top:3px;
       background:transparent;transition:.15s;position:relative;}
  .chk:checked{background:#6ee7a0;border-color:#6ee7a0;}
  .chk:checked::after{content:'✓';position:absolute;inset:0;color:#0b0e0b;
       font-size:11px;font-weight:800;display:flex;align-items:center;justify-content:center;}
  .note-text{flex:1;background:none;border:none;color:var(--text);font-size:13.5px;
       line-height:1.45;resize:none;outline:none;user-select:text;min-height:20px;}
  .note.done .note-text{color:var(--muted);text-decoration:line-through;}

  .subs{display:flex;flex-direction:column;gap:4px;padding-left:26px;}
  .sub{display:flex;gap:8px;align-items:center;}
  .sub .chk{width:14px;height:14px;min-width:14px;margin-top:0;}
  .sub .chk:checked::after{font-size:9px;}
  .sub input{flex:1;background:none;border:none;color:#c3c5cc;font-size:12.5px;outline:none;user-select:text;}
  .sub.done input{color:var(--muted);text-decoration:line-through;}

  .note-actions{display:flex;gap:4px;align-items:center;position:absolute;top:8px;right:10px;opacity:0;transition:.15s;}
  .note:hover .note-actions{opacity:1;}
  .note-actions .ico{font-size:12px;width:20px;height:20px;}
  .prio-pick{display:flex;gap:3px;margin-top:2px;}
  .dot{width:9px;height:9px;border-radius:50%;cursor:pointer;border:1px solid transparent;}
  .dot[data-p="low"]{background:var(--prio-low);} .dot[data-p="med"]{background:var(--prio-med);} .dot[data-p="high"]{background:var(--prio-high);}
  .note[data-prio="low"] .dot[data-p="low"],.note[data-prio="med"] .dot[data-p="med"],.note[data-prio="high"] .dot[data-p="high"]{outline:2px solid rgba(255,255,255,.7);}

  .empty{color:var(--muted);text-align:center;padding:28px 10px;font-size:13px;}
</style>
</head>
<body>
<div class="app">
  <header>
    <span class="brand">ᛗ <b>mimir</b></span>
    <span class="spacer"></span>
    <button class="ico add" id="addbtn" title="Nova nota">＋</button>
    <button class="ico quit" id="quit" title="Fechar">✕</button>
  </header>
  <main id="list"></main>
</div>
<script>
const api = window.pywebview.api;
let notas = [];

function esc(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}

async function load(){ notas = await api.get(); render(); }

function render(){
  const m = document.getElementById('list');
  if(!notas.length){ m.innerHTML = '<div class="empty">Sem notas — ＋ nova</div>'; return; }
  m.innerHTML = notas.map(n=>`
    <div class="note ${n.done?'done':''}" data-id="${n.id}" data-prio="${n.prio}">
      <div class="note-row">
        <input type="checkbox" class="chk" ${n.done?'checked':''} onchange="tog('${n.id}')">
        <textarea class="note-text" spellcheck="false" oninput="edit('${n.id}')">${esc(n.texto)}</textarea>
      </div>
      ${(n.subs||[]).length?`<div class="subs">${n.subs.map((s,i)=>`
        <div class="sub ${s.done?'done':''}">
          <input type="checkbox" class="chk" ${s.done?'checked':''} onchange="togsub('${n.id}',${i})">
          <input value="${esc(s.texto)}" oninput="editsub('${n.id}',${i})">
        </div>`).join('')}</div>`:''}
      <div class="note-actions">
        <button class="ico" title="Sub-tarefa" onclick="addsub('${n.id}')">⊕</button>
        <button class="ico" title="Apagar" onclick="del('${n.id}')">🗑</button>
      </div>
      <div class="prio-pick">
        ${['low','med','high'].map(p=>`<span class="dot" data-p="${p}" title="${p}" onclick="prio('${n.id}','${p}')"></span>`).join('')}
      </div>
    </div>`).join('');
}

async function persist(){ await api.set(notas); }

function find(id){ return notas.find(x=>x.id===id); }

async function addNote(){ notas.unshift({id:await api.nid(),texto:'',done:false,prio:'med',subs:[],criada:await api.now(),atualizada:await api.now()}); render(); focusLast(); persist(); }
function focusLast(){ const t=document.querySelector('.note textarea'); if(t) t.focus(); }

async function tog(id){ const n=find(id); n.done=!n.done; n.atualizada=await api.now(); render(); persist(); }
async function togsub(id,i){ const n=find(id); n.subs[i].done=!n.subs[i].done; n.atualizada=await api.now(); render(); persist(); }
async function edit(id){ const n=find(id); n.texto=document.querySelector(`.note[data-id="${id}"] .note-text`).value; n.atualizada=await api.now(); persist(); }
async function editsub(id,i){ const n=find(id); n.subs[i].texto=document.querySelectorAll(`.note[data-id="${id}"] .sub input[type=text]`)[i].value; n.atualizada=await api.now(); persist(); }
async function addsub(id){ const n=find(id); (n.subs=n.subs||[]).push({texto:'',done:false}); n.atualizada=await api.now(); render(); persist(); }
async function del(id){ notas=notas.filter(x=>x.id!==id); render(); persist(); }
async function prio(id,p){ const n=find(id); n.prio=p; n.atualizada=await api.now(); render(); persist(); }

document.getElementById('addbtn').addEventListener('click', addNote);
document.getElementById('quit').addEventListener('click', () => api.quit());  // pywebview closes window
// drag handled natively via easy_drag

load();
</script>
</body>
</html>
"""

def main():
    import webview
    api = Api()
    window = webview.create_window(
        "mimir", html=HTML, js_api=api,
        width=360, height=520, x=60, y=60,
        frameless=True, easy_drag=True, on_top=True,
        background_color="#1a1b1e", transparent=False,
    )
    api._set_window(window)
    webview.start()


if __name__ == "__main__":
    main()

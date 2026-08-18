# ᛗ Mimir

> O poço do saber — notas rápidas que te seguem. Sticky-note todolist para Windows.

## o quê

Widget de notas/tarefas sempre-em-cima no ecrã:

- sticky note frameless, sempre no topo, arrastável
- notas com check, prioridade (baixa/média/alta), sub-tasks
- persistência automática em `~/.mimir/notas.json`
- hotkey global toggle (versão atual: em revisão)

## como correr

```bash
pythonw.exe mimir.py
```

Dependência: `pip install pywebview keyboard` (v2 usa pywebview/WebView2).

Autostart: atalho em `shell:startup` → `pythonw.exe -u mimir.py`

## estrutura

- `mimir.py` — app (data + UI)
- `notas.json` — dados locais (auto-criado)

## sync (futuro)

JSON local é fácil de sincronizar depois (git-based ou cloud).

---
Mimir — knowledge, memória, o poço de Odin.

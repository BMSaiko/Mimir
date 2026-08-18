# ᛗ Mimir

> O poço do saber — notas rápidas que te seguem. Sticky-note todolist para Windows.

## o quê

- janela frameless, sempre-em-cima, arrastável pelo header
- notas com check e edição inline
- persistência automática em `~/.mimir/notas.json`
- zero dependências — PowerShell + WPF nativo (ships em Windows)

## como correr

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File mimir.ps1
```

Autostart: atalho `Mimir.lnk` em `shell:startup` com o comando acima.

## estrutura

- `mimir.ps1` — app (data + UI WPF)

## sync (futuro)

JSON local é fácil de sincronizar depois (git-based ou cloud).

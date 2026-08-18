# Mimir — Tasks & Planos Detalhados (DP)

> Plano de melhoria incremental da app Mimir (sticky-note todo, PowerShell + WPF nativo, ficheiro único `mimir.ps1`, zero dependências).
> Método: **uma tarefa de cada vez**. Executar → testar → fechar → passar à seguinte.
> Commit: NUNCA auto-commit — gerar mensagem e BMS confirma.

## Estado atual (DR — do código real)
- Notes com checkbox done + prioridade (low/med/high) + subtarefas.
- `Save-Notas` → JSON em `~/.mimir/notas.json`. Swap `TextChanged` só atualiza memória; `Save-Notas` acontece em `LostFocus`/ações.
- Hotkey global F4 (toggle show/hide) via `RegisterHotKey`.
- Janela fixa 372x520, dark, aberta perto do cursor.

## Ordem de execução (prioridade por valor/esforço)
**T1 → T2 → T3 → T4 → T5 → T6 → T7**

| ID | Título | Tipo | Esforço |
|----|--------|------|---------|
| T1 | Debounce de save (evita perda de texto) | BUG | S |
| T2 | Auto-prune notas vazias | Clutter | S |
| T3 | Enter cria nota + Esc faz commit/blur | UX | S |
| T4 | Progress bar no header | UX | S |
| T5 | Done demote para o fundo | UX | S |
| T6 | Lembrar posição da janela | UX | S |
| T7 | Single-instance (Mutex) + assinatura hotkey | Robustez | M |

**Decisões default (pendentes de veto BMS):**
- T5: demote automático (done vai para o fundo). NÃO adicionar toggle "esconder done".
- T6: persistir `Left`/`Top` no `notas.json`; primeira execução (sem valor) abre no cursor como hoje.

---

## T1 — Debounce de autosave ao editar
**Problema:** `TextChanged` do txt (e de cada subtarefa) só atualiza o objeto em memória. `Save-Notas` só dispara em `LostFocus`/ações → fechar com X (ou crash) com campo focado perde as últimas teclas.

**Abordagem:**
1. Criar `DispatcherTimer` global `$saveTimer` (interval 1500ms). `Tick` → `Save-Notas` e `Stop()`.
2. Em `TextChanged` do txt principal e do stxt das subtarefas: `$saveTimer.Stop(); $saveTimer.Start()` (reinicia a cada tecla → grava 1.5s após a última).
3. Manter `LostFocus` imediato. Adicionar `LostFocus` às subtarefas também.
4. `$win.Close()`: `CloseBtn.Add_Click({ Save-Notas; $win.Close() })`.

**Pitfalls:** não chamar `Render` no save (perde foco/cursor). DispatcherTimer usa o dispatcher atual da thread WPF.

**Verificação:** editar, esperar >1.5s, fechar com X, reler `notas.json` → última tecla persistida.

---

## T2 — Auto-prune notas vazias (só whitespace)
**Problema:** notas criadas com `+` e deixadas em branco acumulam-se no JSON e na lista.

**Abordagem:**
1. Em `Save-Notas`, remover notas que sejam vazias e sem vida útil: `[string]::IsNullOrWhiteSpace($_.texto) -and $_.subs.Count -eq 0 -and -not $_.done`.
2. Regra: nunca remover a nota que está em edição ativa (usuário pode estar a limpar o campo para reescrever). Manter se o foco está lá.

**Pitfalls:** guard de foco — só auto-remover quando a nota não estiver focada. Re-check após a prune para garantir lista consistente.

**Verificação:** criar nota vazia, salvar, reler → some. Nota com texto mantém-se.

---

## T3 — Enter cria nota; Esc faz blur
**Objetivo:** `Enter` numa TextBox cria nota nova (topo, foco novo campo); `Esc` faz blur (guarda e sai da edição).

**Abordagem:**
1. `$win.Add_KeyDown` (PreviewKeyDown no Window) — ler `$e.Key`.
2. `Enter` → `Add-Note` (já existe, cria no topo e foca).
3. `Esc` → set focus no `$Header` (força `LostFocus` no campo ativo → `Save-Notas`) e `$e.Handled=$true`.

**Pitfalls:** TextBox default `AcceptsReturn=$false` → Enter não insere linha, safe. Usar `SetFocus` para o Header não dispara Default button. Cuidado com `KeyDown` vs `PreviewKeyDown` (event `Handled`).

**Verificação:** escrever texto, Enter → nota nova focada; Esc num campo → foco sai e texto gravado.

---

## T4 — Barra de progresso no header
**Objetivo:** visual de progresso instantâneo (hoje só texto "3/7").

**Abordagem:**
1. `<ProgressBar>` fina (Height=3) entre o header e o ScrollViewer (nova row no Grid).
2. `Minimum=0`, `Maximum=[Math]::Max(1,$script:notas.Count)`, `Value=$doneCount`, `Foreground=accent`, `Background=surface2`, sem BorderThickness.
3. Atualizar em `Render`.

**Pitfalls:** `Maximum=0` quebra ProgressBar → clamp a 1. Track e valor com as cores do tema já definidas.

**Verificação:** marcar/desmarcar done → barra movimenta; 0 notas → barra vazia/vazia sem erro.

---

## T5 — Done vai para o fundo
**Problema:** notas done ficam misturadas por ordem de inserção → poluem a leitura do "hoje".

**Abordagem:** em `Render`, ordenar apenas o LOOP de exibição: ativas primeiro, depois done (estável dentro de cada grupo). `$script:notas | Sort-Object -Property done` é instável? → usar 2 passos: `@($notas | ? {-not $_.done}) + @($notas | ? {$_.done})`.

**Pitfalls:** NÃO reordenar `$script:notas` em si (destrói ordem de criação). Sort só no render.

**Verificação:** marcar uma no meio → muda para o fundo na lista; desmarcar → volta para a posição do grupo ativo.

---

## T6 — Lembrar posição da janela
**Objetivo:** widget fica em lugar estável entre restarts.

**Abordagem:**
1. Persistir `win.Left`/`win.Top` em `notas.json` (chave nova, ex: `window`).
2. Gravar no `Close` (e/ou `LocationChanged` com debounce).
3. No boot: se `window.Left` existir e estiver dentro do work area → usar; senão → cursor (comportamento atual). Clamp aos limites de ecrã.

**Pitfalls:** multi-monitor (clamp com `Screen.FromPoint`). Debounce em `LocationChanged` para não escrever a cada drag.

**Verificação:** mover, fechar, reabrir → mesma posição. Resolução muda → janela clamped dentro do ecrã.

---

## T7 — Single-instance (Mutex) + alerta hotkey ocupada
**Problema:** 2 processos seguidos escrevem o mesmo `notas.json` (clobber). F4 pode falhar silenciosamente se outra app o possuir.

**Abordagem:**
1. Topo (antes de ler dados): `New-Object System.Threading.Mutex($false,'mimir_single')`; `$createdNew=$mutex.WaitOne(0)`. Se `-not $createdNew` → aviso breve (não bloquear) e `exit`.
2. `RegisterHotKey` retorno: se `$false` → `Add-Content` ao crash log (debug) e não abortar — app continua via botões.
3. Libertar `$mutex.ReleaseMutex()` no `Close`.

**Pitfalls:** Mutex nomeado é por sessão/`Global\` opt-in. `WaitOne(0)` non-blocking.

**Verificação:** lançar 2º com 1º aberto → 2º avisa e sai sem tocar no JSON.

---

## Regras do projeto
- Edições sempre em `mimir.ps1` (ficheiro único). Dados em `~/.mimir/notas.json`; log em `C:/Users/bruno/AppData/Local/Temp/mimir_crash.txt`.
- NUNCA auto-commit. Commit message gerado e BMS confirma.
- Após cada T: smoke check — sintaxe `[System.Management.Automation.Language.Parser]::ParseFile(...)` + teste de partes não-GUI se aplicável (ver skill `powershell-wpf-desktop`).

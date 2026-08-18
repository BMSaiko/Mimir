# Mimir — Tasks & Planos Detalhados (DP)

> Plano de melhoria incremental da app Mimir (sticky-note todo, PowerShell + WPF nativo, ficheiro único `mimir.ps1`, zero dependências).
> Estado: **T1–T7 + T19 + T20 DONE**. T8+ em brainstorm abaixo.
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
| ~~T1~~ | ~~Debounce de save~~ | DONE | S |
| ~~T2~~ | ~~Auto-prune notas vazias~~ | DONE | S |
| ~~T3~~ | ~~Enter cria nota + Esc commit~~ | DONE | S |
| ~~T4~~ | ~~Progress bar no header~~ | DONE | S |
| ~~T5~~ | ~~Done demote para o fundo~~ | DONE | S |
| ~~T6~~ | ~~Lembrar posição da janela~~ | DONE | S |
| ~~T7~~ | ~~Single-instance (Mutex) + assinatura hotkey~~ | DONE | M |

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


---

## Brainstorm — T8+ (novas candidatas, não agendadas)

Ideias do DI no código atual. Ordenadas por valor/esforço. Veto livre.

### Alta prioridade
- **T8 — Marcar done nas subtarefas conta para o progresso?** Hoje subs têm checkbox mas não entram no `Update-Progress`. Decisão de produto: querer que subs done contem? (provavelmente não — manter simples)
- **T9 — Dropdown/ordenação manual**: arrastar notas para reordenar? WPF nativo é doloroso (drag-drop). Skip a menos que peças.
- **T10 — Persistir expansão das subtarefas**: hoje abrir/collapse subs é volátil (Render recolapsa). Guardar `subsExpanded` por nota.

### Média prioridade (UX real)
- **T11 — Escala/paleta**: tema claro? Hoje dark-only. `$PrioColor` hardcoded. Um toggle dark/light no header.
- **T12 — Contador em subs done**: mostrar "2/5" na nota com subs (além da barra global).
- **T13 — Enter num campo existente adiciona linha nova vs Enter cria nota**: hoje Enter cria nota nova sempre. Talvez Enter num sub adicione sub.

### Baixa prioridade / YAGNI até pedires
- T14 — Export/import JSON manual (já é JSON, é trivial mas raramente necessário).
- T15 — Undo/redo (overkill para widget).
- T16 — Sincronização cloud/multi-device (fora de scope, App pessoal local).
- T17 — Notificações/lembretes (fora do propósito sticky-note).
- T18 — Regravação compacta: compactar `$script:notas` após N prunes (micro).

### Bug-fixes candidatos (do DI)
- T19 — `Add-Content $crashLog` no handler de hotkey: `$crashLog` é definido depois de `$win.Add_SourceInitialized` — em runtime o hotkey dispara depois, mas por robustez mover def de `$crashLog` para cima (evita erro se F4 falhar antes da def).
- T20 — Prune T2 também no boot: hoje só no Add-Note; notas vazias no JSON de sessões antigas persistem até próximo `+`. Limpar no load.

### Recomendação imediata (alto valor, baixo esforço)
- **T19** (crashLog antes) — 1 linha, evita edge case real.
- **T20** (prune no boot) — 1 linha, limpa o histórico de 17 instâncias que podes ter criado.
- **T10** (persistir subs expanded) — se usas subs com frequência.
- **T11** (tema claro) — se queres alternar.

---

## DP T8–T20 (detalhe)

### T8 — Subs done contam para o progresso?
**DR:** `Update-Progress` conta só `$_.done` das notas; `subs` ignoradas.
**DP:** manter como está. Progresso global = notas, subs são detalhe. Um sub done a mexer na barra global é ruído.
**Pitfalls:** nenhum.
**Verificação:** N/A (skip). Se quiseres, o caminho é: `$d += subs done / total subs` por nota expandida — não vale o custo.

### T9 — Drag-drop reordenação manual
**DP:** SKIP. WPF nativo sem framework de drag-drop = `MouseMove`+hit-test+reparenting, ~100 linhas frágeis. O `$script:notas` mantém ordem de criação; reordenar visual ≠ reordenar dados. Valor baixo p/ widget de notas.
**Pitfalls:** (aplicável se insistires) reordenar a array + manter IDs únicos.
**Verificação:** N/A.

### T10 — Persistir expansão das subtarefas
**DR:** `subsHost.Visibility='Collapsed'` default; `subBtn` toggle só em memória. `Render` reconstrói → collapse sempre.
**DP:**
1. No load, `Add-Member -Force` `expanded` (default `$false`) a cada nota (padrão já usado p/ `prio`/`subs`).
2. No `$subBtn.Add_Click`, além do toggle visual: `$nn.expanded = $host_.Visibility -eq 'Visible'` + `Save-Notas`.
3. Em `New-NoteRow`, inicializar `$host_.Visibility` a partir de `$n.expanded` (e `$s.Content` `+`/`-` correspondente) em vez de `'Collapsed'` fixo.
**Pitfalls:** PSCustomObject do JSON não aceita property nova → `Add-Member -Force` (padrão já no ficheiro).
**Verificação:** abrir subs, fechar mimir, reabrir → subs continuam abertas.

### T11 — Tema claro (toggle dark/light)
**DP:** uma variável `$script:dark=$true` no topo; guardar em notas.json. No `Render`, escolher o `SolidColorBrush` por tema. Mas: **as cores estão hardcoded em XAML (`<SolidColorBrush x:Key="bg">`)** — tema em runtime exigiria trocar todos os `StaticResource` por DynamicResource + re-aplicar brush. Não é 1 linha.
**Pitfalls:** XAML StaticResource não muda em runtime.
**Verificação:** N/A até decidires. Valor: baixo p/ tool pessoal dark-first.

### T12 — Contador "2/5" em subs done
**DR:** nota com subs não mostra progresso parcial da própria nota.
**DP:** no `New-NoteRow`, quando `$n.subs.Count -gt 0`, adicionar `TextBlock "d/count"` no header do card; atualizar no `$subsHost` toggle. Reusar `Update-Progress` (mesmo `$d/$count`).
**Pitfalls:** sem `Render` no toggle de sub (rebuild recolapsa). TextBlock dedicado + atualização inline.
**Verificação:** abrir subs, marcar 1 → "1/3" na nota.

### T13 — Enter em sub adiciona sub
**DP:** hoje `$win.Add_KeyDown` (T3) faz `Add-Note` em qualquer Enter. Opcional: se foco está num stxt, adicionar sub nova à nota. SKIP por agora — confunde o Enter global; subs criam-se pelo botão `+` da nota. Se quiseres, o handler distingue `$e.OriginalSource.Tag` (stxt vs txt).
**Pitfalls:** Enter no último stxt + Enter para nova nota = conflito de atalho.
**Verificação:** N/A (skip).

### T14 — Export/import JSON manual
**DP:** o formato já é JSON em `~/.mimir/notas.json`. Export = copiar o ficheiro. SKIP — funcionalidade nativa do SO.

### T15 — Undo/redo
**DP:** SKIP. Widget de notas rápidas; o debounce já evita perda. Undo exigiria snapshot por ação.

### T16 — Cloud sync
**DP:** SKIP. App local, dados privados. Fora de scope.

### T17 — Lembretes/notificações
**DP:** SKIP. Sticky-note ≠ lembrete com alarme.

### T18 — Compactação pós-prune
**DP:** SKIP. O JSON é pequeno; `Save-Notas` regrava tudo com `ConvertTo-Json` — já compacto.

### T19 — Mover `$crashLog` para cima (bug-fix)
**DR:** `$crashLog` definido perto do fim (`$crashLog='C:/.../mimir_crash.txt'`), mas o handler `$win.Add_SourceInitialized` (que pode `Add-Content $crashLog` se hotkey falhar) é registado ANTES. Se F4 falhar entre SourceInitialized e a def, `$crashLog` é `$null` → erro no próprio handler de erro.
**DP:**
1. Mover `$crashLog = 'C:/Users/bruno/AppData/Local/Temp/mimir_crash.txt'` para junto do `$dataDir` (topo), antes do `Add_SourceInitialized`.
2. Apagar a def duplicada no fim.
**Pitfalls:** garantir CRLF/BOM na escrita. `$crashLog` já é path absoluto.
**Verificação:** Parser SYNTAX OK + F4 registado OK → log não é escrito (sem erro).

### T20 — Prune no boot (bug-fix)
**DR:** prune T2 só em `Add-Note`; notas vazias de sessões antigas persistem no JSON até o próximo `+`.
**DP:**
1. Extrair a linha de prune para função `Prune-Empty` (ou inline reusado).
2. Chamar no load, depois da normalização (antes do primeiro `Render`).
**Pitfalls:** manter o guard "nunca remover nota em edição" — no boot ninguém está a editar, safe.
**Verificação:** criar notas vazias, reler, boot → some.

---

## Ordem recomendada para T8+
**T19 → T20** (1 linha cada, bug-fixes) → **T10** (se usas subs) → **T12** (opcional)
Skip: T8, T9, T11 (até decidires), T13–T18.

---
name: codex-claude-orchestrator
description: Explicitly invoked bidirectional Codex-Claude dual-agent coding workflow. When used from Codex, Codex plans/reviews and Claude executes through `claude -p`. When used from Claude, Claude plans/reviews and Codex executes through `codex exec`. Use only when the user explicitly asks to use this skill, use the collaboration skill, use the dual-agent workflow, let Codex be the brain and Claude be the hands, let Claude be the brain and Codex be the hands, or run a PASS/REVISE Codex-Claude loop. Do not use for ordinary coding requests, ordinary reviews, or tasks where the user wants a single agent.
---

# Codex-Claude Bidirectional Orchestrator

This skill supports two bounded two-agent engineering loops that are directionally opposite:

- **Codex-led mode** (Codex is the host): Codex plans, calls Claude via `claude -p`, reviews, and controls revisions. Claude implements exactly the plan.
- **Claude-led mode** (Claude is the host): Claude plans, calls Codex via `codex exec`, reviews, and controls revisions. Codex implements exactly the plan.

The mode is selected automatically by the host surface: if you are in Codex, you are the brain; if you are in Claude, you are the brain. Both modes use the same task root structure and review gates.

## Host Auto-Selection

- **Codex host** -- Codex-led mode. Read `AGENT.md` for the brain protocol. Codex writes plans, invokes Claude via `scripts/invoke-claude.ps1`, and reviews results.
- **Claude host** -- Claude-led mode. Read `CLAUDE-ORCHESTRATOR.md` for the brain protocol. Claude writes plans, invokes Codex via `scripts/invoke-codex.ps1`, and reviews results.

Do not activate yourself in a loop. The brain agent invokes the executor agent; neither agent invokes itself.

## Activation

Default activation mode is explicit. Use this skill only when the user clearly asks for the Codex-Claude collaboration workflow, for example:

- "Use the collaboration skill for this request."
- "Use $codex-claude-orchestrator to implement this."
- "Let Codex plan and review while Claude executes."
- "Let Claude plan and review while Codex executes."
- "Run this through Claude from Codex."
- "Run this through Codex from Claude."
- "Run a PASS/REVISE loop."

Do not activate this skill for normal implementation, normal review, Q&A, or cases where the user says they want only one agent. In those cases, answer or implement as a single agent.

## First Steps

1. Determine which host you are running in (Codex or Claude).
2. Read the brain protocol for your host: `AGENT.md` (Codex host) or `CLAUDE-ORCHESTRATOR.md` (Claude host).
3. Read the executor protocol for the other agent: `CLAUDE.md` (when Codex is host) or `CODEX.md` (when Claude is host).
4. Read `config.json`.
5. Inspect the target repository enough to write a file/symbol-level plan.

## Codex-Led Workflow (Codex Host)

1. Create or select a request task root:
   - New user request: summarize the user's request into a concise title, then run the bundled script from this skill directory: `scripts/new-request.ps1 -ProjectRoot "<target-project>" -Title "<AI summary title>" -RequestText "<full request>"`.
   - Existing active request: read `task/CURRENT.md`.
   - Explicit request: pass `-RequestId <id>` to the scripts.
2. Write `<task-root>/plan.md`.
3. Assemble `<task-root>/context.md` using:
   - `CLAUDE.md`
   - the current `<task-root>/plan.md`
   - `config.interactionLanguage`
   - `config.reportLanguage`
   - relevant constraints, repository notes, and previous review notes
4. Invoke Claude:

```powershell
<skill-root>/scripts/invoke-claude.ps1 -ProjectRoot <target-project> -Round 1 -RequestId <id>
```

5. Read `<task-root>/execution.md`.
6. Inspect changed files and diffs. If no git repository exists, use file timestamps and targeted file reads.
7. Review the result. The first line of the review must be exactly `PASS` or `REVISE`.
8. On `REVISE`, overwrite `<task-root>/plan.md` with a precise correction plan and invoke Claude again, up to `config.maxIterations`.
9. Archive every round under `<task-root>/history/round-N/`.

## Claude-Led Workflow (Claude Host)

When Claude is the host and the user explicitly activates the bidirectional collaboration workflow:

1. Create or select a request task root using the same `scripts/new-request.ps1` script.
2. Write `<task-root>/plan.md`.
3. Assemble `<task-root>/context.md` using:
   - `CODEX.md`
   - the current `<task-root>/plan.md`
   - `config.interactionLanguage`
   - `config.reportLanguage`
   - relevant constraints, repository notes, and previous review notes
4. Invoke Codex:

```powershell
<skill-root>/scripts/invoke-codex.ps1 -ProjectRoot <target-project> -Round 1 -RequestId <id>
```

5. Read `<task-root>/execution.md`.
6. Inspect changed files and diffs. If no git repository exists, use file timestamps and targeted file reads.
7. Review the result. The first line of the review must be exactly `PASS` or `REVISE`.
8. On `REVISE`, overwrite `<task-root>/plan.md` with a precise correction plan and invoke Codex again, up to `config.maxIterations`.
9. Archive every round under `<task-root>/history/round-N/`.

## Planning Contract

`<task-root>/plan.md` must include:

- Goal.
- Assumptions.
- Allowed files.
- Forbidden files/actions.
- Required changes by file and symbol.
- Acceptance criteria.
- Implementation order.
- Validation commands.
- UI evidence requirements when relevant.
- Required execution report format.

Keep the plan narrow. Claude should not need to infer architecture or product decisions.

## Claude Invocation

Prefer the wrapper script because it avoids command-line quoting problems, especially on PowerShell:

```powershell
<skill-root>/scripts/invoke-claude.ps1 -ProjectRoot <target-project> -Round <N>
```

Use `-SkipAssemble` only when `<task-root>/context.md` has already been manually prepared:

```powershell
<skill-root>/scripts/invoke-claude.ps1 -ProjectRoot <target-project> -Round 2 -RequestId <id> -SkipAssemble
```

If the user's `claude` command is backed by DeepSeek, still use the same CLI entry point unless the user provides a different executable or flags.

## UI Evidence

When UI screenshots are needed, prefer the bundled capture wrapper:

```powershell
<skill-root>/scripts/capture-ui.ps1 -ProjectRoot <target-project> -Round <N> -HtmlPath demo/index.html
```

It uses installed Chrome or Edge through the Chrome DevTools Protocol. Requirements: PowerShell, Node 20+ for built-in WebSocket support, and Chrome or Edge. If the browser is not auto-detected, pass `-BrowserPath <path-to-chrome-or-edge>`. If no compatible browser exists, record that UI screenshots were not captured and continue with manual or code-level review.

## Report Language

`config.json` controls task artifact language and user-facing language separately:

```json
{
  "maxIterations": 10,
  "interactionLanguage": "en-US",
  "reportLanguage": "en-US",
  "userFacingLanguage": "zh-CN",
  "languagePolicy": "interaction-and-report-config-authoritative",
  "taskWorkspaceMode": "request-scoped-current-plus-history",
  "requestIdPattern": "yyyyMMdd-HHmmss-slug",
  "activationMode": "explicit",
  "requestTitleMode": "ai-summary",
  "runtimeMode": "skill-contained",
  "taskStorage": "project",
  "taskDirectory": "task"
}
```

Use `interactionLanguage` for plan, context, review, and Codex-to-Claude round instructions. Use `reportLanguage` for execution reports, changed-file summaries, validation notes, UI notes, and deviation explanations. Use `userFacingLanguage` for final replies to the user.

Treat `interactionLanguage` and `reportLanguage` as authoritative. Do not switch languages because a terminal displayed mojibake. Fix the encoding path or use safe escaping while preserving the configured language.

## Task File Semantics

- Runtime protocol files (`SKILL.md`, `AGENT.md`, `CLAUDE.md`, `config.json`, and `scripts/`) live inside the skill. Do not copy them into target projects.
- Target projects only receive task records under `task/` plus the actual implementation edits requested by the user.
- `task/CURRENT.md` points to the active request.
- `task/requests/<request-id>/request.md` stores the user's request for that work item.
- `task/requests/<request-id>/plan.md`, `context.md`, `execution.md`, and `review.md` are current working copies for the active/latest round of that request.
- `task/requests/<request-id>/history/round-N/` stores snapshots for each completed round in that request.
- `task/requests/<request-id>/artifacts/round-N/` stores UI screenshots and generated evidence for that request round.
- Root-level `task/plan.md`, `task/context.md`, `task/execution.md`, and `task/review.md` are legacy-compatible only. Prefer request-scoped paths for new work.

## Review Contract

Review dimensions:

- Completeness.
- Correctness.
- Consistency.
- Side effects.
- Validation quality.
- Scope control.
- Maintainability.
- Visual/UI quality when relevant.

`PASS` means the requested task is done and verified enough to hand back.

`REVISE` means Codex must provide a concrete next plan for Claude, not a vague critique.

## Safety

- Do not let Claude modify files outside the plan.
- Do not let Claude commit, push, reset, or discard changes.
- Do not allow global installs or secret access unless explicitly required and safe.
- Preserve unrelated user changes.

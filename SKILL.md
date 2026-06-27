---
name: codex-claude-orchestrator
description: Codex-driven dual-agent coding workflow where Codex plans and reviews while invoking Claude through `claude -p` as the executor. Use when the user asks to use Codex as the brain, Claude as the hands, run a Codex-Claude collaboration loop, generate task/plan.md and task/context.md, invoke Claude Code or a DeepSeek-backed Claude CLI, review task/execution.md, or enforce PASS/REVISE multi-round implementation.
---

# Codex-Claude Orchestrator

Use this skill to run a bounded two-agent engineering loop:

- Codex plans, calls Claude, reviews, and controls revisions.
- Claude implements exactly the plan and writes `task/execution.md`.

## First Steps

1. Read `AGENT.md`.
2. Read `CLAUDE.md`.
3. Read `config.json`.
4. Inspect the target repository enough to write a file/symbol-level plan.

## Codex Workflow

1. Create `task/` if missing.
2. Write `task/plan.md`.
3. Assemble `task/context.md` using:
   - `CLAUDE.md`
   - the current `task/plan.md`
   - relevant constraints, repository notes, and previous review notes
4. Invoke Claude:

```powershell
./scripts/invoke-claude.ps1 -Round 1
```

5. Read `task/execution.md`.
6. Inspect changed files and diffs. If no git repository exists, use file timestamps and targeted file reads.
7. Review the result. The first line of the review must be exactly `PASS` or `REVISE`.
8. On `REVISE`, overwrite `task/plan.md` with a precise correction plan and invoke Claude again, up to `config.maxIterations`.
9. Archive every round under `task/history/round-N/`.

## Planning Contract

`task/plan.md` must include:

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
./scripts/invoke-claude.ps1 -Round <N>
```

Use `-SkipAssemble` only when `task/context.md` has already been manually prepared:

```powershell
./scripts/invoke-claude.ps1 -Round 2 -SkipAssemble
```

If the user's `claude` command is backed by DeepSeek, still use the same CLI entry point unless the user provides a different executable or flags.

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

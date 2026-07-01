# CLAUDE-ORCHESTRATOR.md - Claude Orchestrator Protocol

Claude is the entry point, planner, reviewer, and loop controller in the Claude-led mode of this dual-agent workflow. Codex is the executor.

This file activates when Claude is the host surface (e.g., a Claude conversation or Claude Code session) and the user explicitly requests the bidirectional Codex-Claude collaboration workflow. When Codex is the host, use `AGENT.md` instead.

## Activation Rules

- Default to Claude-only behavior unless the user explicitly asks to use the Codex-Claude collaboration skill with Claude as the brain.
- Activate this workflow when the user says things like "use the collaboration skill", "use Codex-Claude skill", "Claude plans and Codex executes", "run this through Codex from Claude", or "run a PASS/REVISE loop with Codex".
- Do not activate this workflow for ordinary coding, ordinary review, Q&A, or any request where the user wants one agent only.
- When activating for a new user request, Claude summarizes the request into a concise title before creating the request task root.

## Non-Negotiable Rules

- Do not directly edit the target project's implementation files when this workflow is active. Codex performs implementation through `codex exec`.
- Claude may create and update coordination files under the target project's `task/`, and may update skill files when the user is editing this skill itself.
- Do not copy `AGENT.md`, `CLAUDE.md`, `CLAUDE-ORCHESTRATOR.md`, `CODEX.md`, `config.json`, or `scripts/` into target projects. These runtime files live in the skill directory.
- Every plan must be executable: include exact file paths, symbols/functions/components, intended edits, constraints, and validation commands.
- Every review conclusion must start with exactly `PASS` or `REVISE`.
- If the result is `REVISE`, write a concrete revised plan and run another Codex round, up to `config.maxIterations`.
- Preserve unrelated user changes. Never reset, checkout, or discard work unless the user explicitly asks.

## Claude Responsibilities

1. Understand the user request and inspect the repository.
2. Create or select a request task root and write `<task-root>/plan.md` with a precise implementation plan.
3. Assemble `<task-root>/context.md` from:
   - skill-local `CODEX.md`
   - `<task-root>/plan.md`
   - skill-local `config.interactionLanguage`
   - skill-local `config.reportLanguage`
   - optional task-local context, constraints, and prior review notes
4. Invoke Codex in non-interactive mode with `codex exec`.
5. Read `<task-root>/execution.md`, inspect changed files and diffs, run or verify validation when useful.
6. Review for completeness, correctness, consistency, side effects, validation quality, scope control, maintainability, and UI quality when relevant.
7. Either report `PASS` to the user or revise `<task-root>/plan.md` and repeat.

## Required Workflow

```text
User request
  -> Claude inspects repo
  -> Claude creates or selects <target-project>/task/requests/<request-id>/
  -> Claude writes <task-root>/plan.md
  -> Claude assembles <task-root>/context.md
  -> Claude runs <skill-root>/scripts/invoke-codex.ps1 with -ProjectRoot <target-project>
  -> Codex edits code and writes <task-root>/execution.md
  -> Claude reviews execution.md + diff + artifacts
  -> PASS or REVISE
```

## Planning Requirements

`<task-root>/plan.md` must include:

- Goal: one or two sentences.
- Assumptions: only those affecting implementation.
- Scope:
  - Allowed files.
  - Forbidden files or actions.
- Required changes:
  - File path.
  - Function/component/type/module name.
  - Exact behavioral change.
  - Acceptance criteria for that item.
- Implementation order.
- Validation commands and expected outcomes.
- UI evidence requirements when UI is involved.
- Reporting requirements for `<task-root>/execution.md`.

## Language Configuration

- Read `config.interactionLanguage`, `config.reportLanguage`, and `config.userFacingLanguage` before each round.
- Default `interactionLanguage` to `reportLanguage` when missing. Default `reportLanguage` to `en-US` when missing. Default `userFacingLanguage` to `zh-CN` when missing.
- Use `interactionLanguage` for `<task-root>/plan.md`, `<task-root>/context.md`, `<task-root>/review.md`, and Claude-to-Codex round instructions.
- Use `reportLanguage` for Codex execution reports, change summaries, validation notes, UI notes, and deviation explanations.
- Use `userFacingLanguage` for final replies and ordinary conversation with the user.
- Do not switch execution artifacts to another language just because a previous terminal display showed mojibake. Fix the encoding/read path or use safe escaping while preserving the configured language.
- Only override the configured language when the user explicitly asks for a one-off language override.
- Keep fixed protocol tokens such as `PASS`, `REVISE`, `DONE`, `PARTIAL`, and `BLOCKED` unchanged.

## Codex Invocation

Prefer the wrapper script because it avoids command-line quoting problems and automatically resolves `codex` from PATH or common VS Code / VS Code Insiders extension locations:

```powershell
<skill-root>/scripts/invoke-codex.ps1 -ProjectRoot <target-project> -Round <N>
```

Use `-SkipAssemble` only when `<task-root>/context.md` has already been manually prepared:

```powershell
<skill-root>/scripts/invoke-codex.ps1 -ProjectRoot <target-project> -Round 2 -RequestId <id> -SkipAssemble
```

If the user's `codex` command is backed by a different model provider, still use the same CLI entry point unless the user provides a different executable or flags.

Before the first round, prefer a wrapper dry run instead of asking the user to locate `codex.exe` manually:

```powershell
<skill-root>/scripts/invoke-codex.ps1 -ProjectRoot <target-project> -Round 1 -RequestId <id> -DryRun
```

If this fails, classify the problem as `ENVIRONMENT_ERROR`. Do not claim the protocol is impossible; explain that automatic CLI discovery failed after checking PATH and common VS Code extension folders. Manual `config.codexCommand` or `$env:CODEX_COMMAND` is a fallback, not the normal user path.

## Task Directory Semantics

- Use one request task root for each distinct user request.
- For a new request, summarize the user's request into a concise title, then run the skill-local script: `<skill-root>/scripts/new-request.ps1 -ProjectRoot "<target-project>" -Title "<AI summary title>" -RequestText "<full request>"`.
- Runtime protocol files remain in the skill directory. Target projects store only `task/` records and requested implementation changes.
- `task/CURRENT.md` points to the active request task root.
- `task/requests/<request-id>/request.md` stores the user's request text.
- `task/requests/<request-id>/plan.md`, `context.md`, `execution.md`, and `review.md` are current working copies for the active/latest round of that request.
- `task/requests/<request-id>/history/round-N/` contains per-round snapshots for auditing.
- `task/requests/<request-id>/artifacts/round-N/` contains screenshots and generated evidence.
- Duplicates between request-root files and `history/round-N/` are intentional: current state plus immutable history.
- Root-level `task/plan.md`, `task/context.md`, `task/execution.md`, and `task/review.md` are legacy-compatible only. Prefer request-scoped paths for new work.

## Review Requirements

Review dimensions:

1. Completeness: every plan item completed.
2. Correctness: behavior and logic match the request.
3. Consistency: names, interfaces, structure, and style match the plan and codebase.
4. Side effects: no unrelated regressions or broad churn.
5. Validation quality: required checks were run or failures were explained.
6. Scope control: only planned files changed unless explicitly justified.
7. Maintainability: implementation is simple and local.
8. Visual quality: for UI work, inspect screenshots or live page states.

Review output shape:

```text
PASS
Short reason.
Validation reviewed:
- ...
```

or:

```text
REVISE
Issues:
- ...

Revised plan:
- Exact file/symbol-level corrections for Codex.

Validation:
- Commands/artifacts required next round.
```

## Revision Rules

- Prefer narrow revisions that fix blocking problems.
- Do not add speculative improvements.
- If the plan itself was wrong, rewrite `<task-root>/plan.md` rather than asking Codex to improvise.
- If Codex changed files outside scope, instruct Codex to correct or report the mismatch without destructive cleanup unless explicitly safe.

## Safety

- Do not let Codex modify files outside the plan.
- Do not let Codex commit, push, reset, or discard changes.
- Do not allow global installs or secret access unless explicitly required and safe.
- Preserve unrelated user changes.

## Failure Classes

- `PLAN_ERROR`: Claude's plan was incomplete, wrong, or impossible.
- `EXECUTION_ERROR`: Codex did not follow the plan or produced incorrect changes.
- `VALIDATION_ERROR`: build, tests, lint, or UI checks failed.
- `ENVIRONMENT_ERROR`: local tools, dependencies, or credentials prevented execution.
- `SCOPE_ERROR`: files outside the allowed scope were changed.

Claude should use these classes in review notes when helpful.

## UI Evidence

When UI changes are involved, require Codex to provide:

- Dev server command and URL.
- Routes visited.
- Screenshot paths for desktop and mobile.
- Viewport sizes.
- Browser console errors.
- Failed network requests.
- Steps used to reach important states such as modal open, empty state, loading, error, hover, or form validation.

Claude should inspect screenshots with visual tools when available and mention layout, typography, spacing, color, responsiveness, and interaction states in the review.

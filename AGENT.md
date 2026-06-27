# AGENT.md - Codex Orchestrator Protocol

Codex is the entry point, planner, reviewer, and loop controller in this dual-agent workflow. Claude is the executor.

## Non-Negotiable Rules

- Do not directly edit the target project's implementation files when this workflow is active. Claude performs implementation through `claude -p`.
- Codex may create and update coordination files under `task/`, skill files, scripts, and protocol documents.
- Every plan must be executable: include exact file paths, symbols/functions/components, intended edits, constraints, and validation commands.
- Every review conclusion must start with exactly `PASS` or `REVISE`.
- If the result is `REVISE`, write a concrete revised plan and run another Claude round, up to `config.maxIterations`.
- Preserve unrelated user changes. Never reset, checkout, or discard work unless the user explicitly asks.

## Codex Responsibilities

1. Understand the user request and inspect the repository.
2. Write `task/plan.md` with a precise implementation plan.
3. Assemble `task/context.md` from:
   - `CLAUDE.md`
   - `task/plan.md`
   - optional task-local context, constraints, and prior review notes
4. Invoke Claude in non-interactive mode with the local CLI.
5. Read `task/execution.md`, inspect changed files and diffs, run or verify validation when useful.
6. Review for completeness, correctness, consistency, side effects, validation quality, scope control, maintainability, and UI quality when relevant.
7. Either report `PASS` to the user or revise `task/plan.md` and repeat.

## Required Workflow

```text
User request
  -> Codex inspects repo
  -> Codex writes task/plan.md
  -> Codex assembles task/context.md
  -> Codex runs scripts/invoke-claude.ps1
  -> Claude edits code and writes task/execution.md
  -> Codex reviews execution.md + diff + artifacts
  -> PASS or REVISE
```

## Planning Requirements

`task/plan.md` must include:

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
- Reporting requirements for `task/execution.md`.

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
- Exact file/symbol-level corrections for Claude.

Validation:
- Commands/artifacts required next round.
```

## Revision Rules

- Prefer narrow revisions that fix blocking problems.
- Do not add speculative improvements.
- If the plan itself was wrong, rewrite `task/plan.md` rather than asking Claude to improvise.
- If Claude changed files outside scope, instruct Claude to correct or report the mismatch without destructive cleanup unless explicitly safe.

## UI Review Rules

When UI changes are involved, require Claude to provide:

- Dev server command and URL.
- Routes visited.
- Screenshot paths for desktop and mobile.
- Viewport sizes.
- Browser console errors.
- Failed network requests.
- Steps used to reach important states such as modal open, empty state, loading, error, hover, or form validation.

Codex should inspect screenshots with visual tools when available and mention layout, typography, spacing, color, responsiveness, and interaction states in the review.

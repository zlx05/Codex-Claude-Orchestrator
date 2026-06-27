# Codex-Claude Collaboration Design

This repository defines a Codex-driven dual-agent workflow:

- Codex is the brain: planner, caller, reviewer, loop controller.
- Claude is the hands: executor, validator, reporter.

The design goal is not to let two agents chat freely. The goal is to create an auditable engineering loop with explicit plans, bounded execution, structured reports, and review gates.

Default activation is explicit. Use this workflow only when the user asks for the collaboration skill or Codex-Claude loop. Ordinary coding and review requests stay Codex-only.

Runtime mode is skill-contained: protocol files and scripts live in the skill directory. Target projects only receive `task/` records and the implementation edits requested by the user.

## Architecture

```text
User
      -> Codex
      -> create/select <target-project>/task/requests/<request-id>/
      -> write <task-root>/plan.md
      -> assemble <task-root>/context.md
      -> run claude -p with allowed tools
      -> Claude edits code and writes <task-root>/execution.md
      -> Codex reviews diff, report, tests, and UI evidence
      -> PASS or REVISE
```

## Files

```text
AGENT.md                 Codex operating protocol
CLAUDE.md                Claude executor protocol
SKILL.md                 Skill entry point for Codex
config.json              Runtime configuration
scripts/invoke-claude.ps1  PowerShell Claude CLI wrapper
<target-project>/task/   Runtime collaboration files stored inside each project
  CURRENT.md
  requests/<request-id>/
    request.md
    plan.md
    context.md
    execution.md
    review.md
    artifacts/round-N/
    history/round-N/
```

## Loop

1. Codex inspects the target repository.
2. Codex writes a precise plan.
3. Codex assembles Claude context.
4. Codex invokes Claude non-interactively.
5. Claude implements only the plan and writes an execution report.
6. Codex reviews:
   - plan completeness
   - implementation correctness
   - scope control
   - validation results
   - side effects
   - maintainability
   - UI evidence if relevant
7. Codex either passes or revises the plan and repeats.

## Failure Classes

- `PLAN_ERROR`: Codex's plan was incomplete, wrong, or impossible.
- `EXECUTION_ERROR`: Claude did not follow the plan or produced incorrect changes.
- `VALIDATION_ERROR`: build, tests, lint, or UI checks failed.
- `ENVIRONMENT_ERROR`: local tools, dependencies, or credentials prevented execution.
- `SCOPE_ERROR`: files outside the allowed scope were changed.

Codex should use these classes in review notes when helpful.

## Command

Create a request folder, then use the PowerShell wrapper instead of manually embedding file contents in shell quotes:

```powershell
<skill-root>/scripts/new-request.ps1 -ProjectRoot <target-project> -Title "AI summarized title" -RequestText "full user request"
```

Codex should summarize the user's request into the title. The script can create a fallback title from `-RequestText` when `-Title` is omitted.

```powershell
<skill-root>/scripts/invoke-claude.ps1 -ProjectRoot <target-project> -Round 1
```

The wrapper reads `<task-root>/context.md` as raw UTF-8 text and runs:

```text
claude -p <context> --print --allowedTools Read,Write,Edit,Bash
```

If your Claude CLI is actually DeepSeek-backed, keep the same command surface as long as `claude -p` accepts the prompt and tool flags.

## Report Language

`config.json` controls the language of human-readable execution and review records:

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

Set `reportLanguage` to `zh-CN` for Chinese records or `en-US` for English records. Protocol status tokens such as `PASS`, `REVISE`, `DONE`, `PARTIAL`, and `BLOCKED` stay unchanged.

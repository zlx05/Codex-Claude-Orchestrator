# Codex-Claude Collaboration Design

This repository defines a Codex-driven dual-agent workflow:

- Codex is the brain: planner, caller, reviewer, loop controller.
- Claude is the hands: executor, validator, reporter.

The design goal is not to let two agents chat freely. The goal is to create an auditable engineering loop with explicit plans, bounded execution, structured reports, and review gates.

## Architecture

```text
User
  -> Codex
      -> write task/plan.md
      -> assemble task/context.md
      -> run claude -p with allowed tools
      -> Claude edits code and writes task/execution.md
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
task/                    Runtime collaboration files
  plan.md
  context.md
  execution.md
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

Use the PowerShell wrapper instead of manually embedding file contents in shell quotes:

```powershell
./scripts/invoke-claude.ps1 -Round 1
```

The wrapper reads `task/context.md` as raw UTF-8 text and runs:

```text
claude -p <context> --print --allowedTools Read,Write,Edit,Bash --project .
```

If your Claude CLI is actually DeepSeek-backed, keep the same command surface as long as `claude -p` accepts the prompt and tool flags.

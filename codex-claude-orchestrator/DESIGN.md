# Codex-Claude Bidirectional Collaboration Design

This skill defines two dual-agent workflows that are directionally opposite but share the same task structure, review gates, and configuration:

- **Codex-led mode**: Codex is the brain (planner, caller, reviewer, loop controller). Claude is the hands (executor, validator, reporter). Codex invokes Claude via `claude -p`.
- **Claude-led mode**: Claude is the brain (planner, caller, reviewer, loop controller). Codex is the hands (executor, validator, reporter). Claude invokes Codex via `codex exec`.

The design goal is not to let two agents chat freely. The goal is to create an auditable engineering loop with explicit plans, bounded execution, structured reports, and review gates.

Default activation is explicit. Use this workflow only when the user asks for the collaboration skill or Codex-Claude loop. Ordinary coding and review requests stay single-agent.

Runtime mode is skill-contained: protocol files and scripts live in the skill directory. Target projects only receive `task/` records and the implementation edits requested by the user.

## Architecture

### Codex-Led Mode (Codex Host)

```text
User
      -> Codex (brain)
      -> create/select <target-project>/task/requests/<request-id>/
      -> write <task-root>/plan.md
      -> assemble <task-root>/context.md (from CLAUDE.md + plan.md + config)
      -> run claude -p with allowed tools
      -> Claude (hands) edits code and writes <task-root>/execution.md
      -> Codex reviews diff, report, tests, and UI evidence
      -> PASS or REVISE
```

### Claude-Led Mode (Claude Host)

```text
User
      -> Claude (brain)
      -> create/select <target-project>/task/requests/<request-id>/
      -> write <task-root>/plan.md
      -> assemble <task-root>/context.md (from CODEX.md + plan.md + config)
      -> run codex exec
      -> Codex (hands) edits code and writes <task-root>/execution.md
      -> Claude reviews diff, report, tests, and UI evidence
      -> PASS or REVISE
```

Both modes use the same `task/requests/<request-id>/` structure, the same review dimensions, and the same `PASS`/`REVISE` gate. The brain and hands roles swap depending on which surface the user is in.

## Files

```text
AGENT.md                  Codex brain protocol (Codex-led mode)
CLAUDE.md                 Claude executor protocol (Codex-led mode)
CLAUDE-ORCHESTRATOR.md    Claude brain protocol (Claude-led mode)
CODEX.md                  Codex executor protocol (Claude-led mode)
SKILL.md                  Skill entry point (host-auto-select)
DESIGN.md                 Architecture and design docs
config.json               Runtime configuration (both modes)
agents/openai.yaml        Codex UI metadata
scripts/
  new-request.ps1         Create a new request task root
  invoke-claude.ps1       PowerShell Claude CLI wrapper (Codex-led)
  invoke-codex.ps1        PowerShell Codex CLI wrapper (Claude-led)
  capture-ui.ps1          Chrome/Edge CDP UI screenshot capture
<target-project>/task/    Runtime collaboration files stored inside each project
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

Both modes follow the same loop structure with the roles swapped:

1. Brain agent (Codex or Claude) inspects the target repository.
2. Brain writes a precise plan to `<task-root>/plan.md`.
3. Brain assembles executor context from the executor protocol, plan, and config.
4. Brain invokes the executor non-interactively.
5. Executor implements only the plan and writes an execution report to `<task-root>/execution.md`.
6. Brain reviews:
   - plan completeness
   - implementation correctness
   - scope control
   - validation results
   - side effects
   - maintainability
   - UI evidence if relevant
7. Brain either passes or revises the plan and repeats.

## Failure Classes

- `PLAN_ERROR`: the brain agent's plan was incomplete, wrong, or impossible.
- `EXECUTION_ERROR`: the executor did not follow the plan or produced incorrect changes.
- `VALIDATION_ERROR`: build, tests, lint, or UI checks failed.
- `ENVIRONMENT_ERROR`: local tools, dependencies, or credentials prevented execution.
- `SCOPE_ERROR`: files outside the allowed scope were changed.

The brain agent should use these classes in review notes when helpful.

## Commands

### Create a Request

Use the PowerShell wrapper instead of manually embedding file contents in shell quotes:

```powershell
<skill-root>/scripts/new-request.ps1 -ProjectRoot <target-project> -Title "AI summarized title" -RequestText "full user request"
```

The brain agent should summarize the user's request into the title. The script can create a fallback title from `-RequestText` when `-Title` is omitted.

### Codex-Led: Invoke Claude

```powershell
<skill-root>/scripts/invoke-claude.ps1 -ProjectRoot <target-project> -Round 1
```

The wrapper reads `<task-root>/context.md` (assembled from `CLAUDE.md` + plan + config) as raw UTF-8 text and runs:

```text
claude -p <context> --print --allowedTools Read,Write,Edit,Bash
```

If your Claude CLI is actually DeepSeek-backed, keep the same command surface as long as `claude -p` accepts the prompt and tool flags.

### Claude-Led: Invoke Codex

```powershell
<skill-root>/scripts/invoke-codex.ps1 -ProjectRoot <target-project> -Round 1
```

The wrapper reads `<task-root>/context.md` (assembled from `CODEX.md` + plan + config) as raw UTF-8 text and runs:

```text
codex exec <context>
```

Use `-DryRun` to validate the round setup without actually invoking Codex:

```powershell
<skill-root>/scripts/invoke-codex.ps1 -ProjectRoot <target-project> -Round 1 -DryRun
```

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

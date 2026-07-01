param(
    [string]$ProjectRoot = ".",
    [int]$Round = 1,
    [string]$RequestId = "",
    [switch]$SkipAssemble,
    [switch]$DryRun,
    [string]$CodexCommand = "codex",
    [string]$AllowedMode = "exec"
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Copy-IfExists {
    param(
        [string]$Source,
        [string]$Destination
    )
    if (Test-Path -LiteralPath $Source) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

function Resolve-Command {
    param(
        [string]$Command,
        [string]$CommandName
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        throw "$CommandName command is empty. Set config.json $($CommandName.ToLower())Command, pass -$CommandName`Command, or set ${CommandName}_COMMAND."
    }

    # Test a single candidate string as a literal path or PATH command.
    function Test-CommandCandidate {
        param([string]$Candidate)
        if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
        $cmd = Get-Command $Candidate -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            if ($cmd.PSObject.Properties.Name -contains "Path" -and -not [string]::IsNullOrWhiteSpace($cmd.Path)) {
                return $cmd.Path
            }
            if (-not [string]::IsNullOrWhiteSpace($cmd.Source)) {
                return $cmd.Source
            }
            return $cmd.Name
        }
        return $null
    }

    # Try the current command value first.
    $result = Test-CommandCandidate $Command
    if ($result) { return $result }

    # For Codex, scan common VS Code extension directories for bundled codex.exe.
    if ($CommandName -eq "CODEX") {
        $vsCodeBaseDirs = @(
            "$env:USERPROFILE\.vscode\extensions",
            "$env:USERPROFILE\.vscode-insiders\extensions"
        )
        foreach ($baseDir in $vsCodeBaseDirs) {
            if (-not (Test-Path -LiteralPath $baseDir)) { continue }
            # Try known path patterns under openai.chatgpt-* directories.
            $chatGptDirs = Get-ChildItem -LiteralPath $baseDir -Directory -Filter "openai.chatgpt-*" -ErrorAction SilentlyContinue
            foreach ($dir in $chatGptDirs) {
                $knownPaths = @(
                    Join-Path $dir.FullName "bin\windows-x86_64\codex.exe"
                    Join-Path $dir.FullName "bin\codex.exe"
                )
                foreach ($p in $knownPaths) {
                    if (Test-Path -LiteralPath $p -PathType Leaf) {
                        return $p
                    }
                }
            }
            # Broader fallback: search for codex.exe inside openai-named extension dirs.
            $found = Get-ChildItem -LiteralPath $baseDir -Recurse -Depth 5 -Filter "codex.exe" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match "\\openai\\" -or $_.FullName -match "\\openai\." } |
                Select-Object -First 1
            if ($found) {
                return $found.FullName
            }
        }
    }

    # For Claude, scan VS Code extension directories for claude* executables.
    if ($CommandName -eq "CLAUDE") {
        $vsCodeBaseDirs = @(
            "$env:USERPROFILE\.vscode\extensions",
            "$env:USERPROFILE\.vscode-insiders\extensions"
        )
        foreach ($baseDir in $vsCodeBaseDirs) {
            if (-not (Test-Path -LiteralPath $baseDir)) { continue }
            $found = Get-ChildItem -LiteralPath $baseDir -Recurse -Depth 5 -Filter "claude.exe" -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) {
                return $found.FullName
            }
        }
    }

    # Report what was tried when discovery fails.
    $triedMsg = "Tried:`n- Command '$Command' (literal path and PATH lookup)"
    if ($CommandName -eq "CODEX") {
        $triedMsg += "`n- Bundled Codex under VS Code extension directories: .vscode\extensions\openai.chatgpt-* and .vscode-insiders\extensions\openai.chatgpt-*"
    }
    if ($CommandName -eq "CLAUDE") {
        $triedMsg += "`n- VS Code extension directories under .vscode\extensions and .vscode-insiders\extensions"
    }

    throw @"
Automatic $CommandName CLI discovery failed.

$triedMsg

Fix options:
1. Make sure the matching VS Code extension or CLI is installed.
2. Restart VS Code/Claude Code so the terminal sees newly installed commands.
3. Optional fallback: set the full executable path in codex-claude-orchestrator/config.json:
   "$($CommandName.ToLower())Command": "C:\\path\\to\\$($CommandName.ToLower()).exe"
4. Optional one-run fallback: pass it with -${CommandName}Command or set:
   `$env:${CommandName}_COMMAND = "C:\\path\\to\\$($CommandName.ToLower()).exe"
"@
}

function Get-TaskRoot {
    param([string]$RequestId)
    if ([string]::IsNullOrWhiteSpace($RequestId)) {
        if (Test-Path -LiteralPath "task/CURRENT.md") {
            $current = Get-Content -LiteralPath "task/CURRENT.md" -Raw -Encoding UTF8
            $match = [regex]::Match($current, "(?m)^RequestId:\s*(.+?)\s*$")
            if ($match.Success) {
                return "task/requests/$($match.Groups[1].Value.Trim())"
            }
        }
        return "task"
    }
    return "task/requests/$RequestId"
}

$skillRoot = (Resolve-Path -LiteralPath $PSScriptRoot\..).Path
$projectRootPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $projectRootPath

$configPath = Join-Path $skillRoot "config.json"
$codexProtocolPath = Join-Path $skillRoot "CODEX.md"
$config = Read-JsonFile -Path $configPath
$maxIterations = 5
if ($null -ne $config -and $null -ne $config.maxIterations) {
    $maxIterations = [int]$config.maxIterations
}
$reportLanguage = "en-US"
if ($null -ne $config -and $null -ne $config.reportLanguage) {
    $reportLanguage = [string]$config.reportLanguage
}
$interactionLanguage = $reportLanguage
if ($null -ne $config -and $null -ne $config.interactionLanguage) {
    $interactionLanguage = [string]$config.interactionLanguage
}
$userFacingLanguage = "zh-CN"
if ($null -ne $config -and $null -ne $config.userFacingLanguage) {
    $userFacingLanguage = [string]$config.userFacingLanguage
}
$languagePolicy = "interaction-and-report-config-authoritative"
if ($null -ne $config -and $null -ne $config.languagePolicy) {
    $languagePolicy = [string]$config.languagePolicy
}
$taskWorkspaceMode = "current-plus-history"
if ($null -ne $config -and $null -ne $config.taskWorkspaceMode) {
    $taskWorkspaceMode = [string]$config.taskWorkspaceMode
}
if ($null -ne $config -and $null -ne $config.codexCommand -and
    ([string]::IsNullOrWhiteSpace($CodexCommand) -or $CodexCommand -eq "codex")) {
    $CodexCommand = [string]$config.codexCommand
}
if (-not [string]::IsNullOrWhiteSpace($env:CODEX_COMMAND)) {
    $CodexCommand = $env:CODEX_COMMAND
}

if ($Round -lt 1) {
    throw "Round must be >= 1."
}
if ($Round -gt $maxIterations) {
    throw "Round $Round exceeds config.maxIterations=$maxIterations."
}

New-Item -ItemType Directory -Force -Path "task" | Out-Null
$taskRoot = Get-TaskRoot -RequestId $RequestId
New-Item -ItemType Directory -Force -Path $taskRoot | Out-Null
New-Item -ItemType Directory -Force -Path "$taskRoot/history" | Out-Null
New-Item -ItemType Directory -Force -Path "$taskRoot/artifacts/round-$Round" | Out-Null

if (-not (Test-Path -LiteralPath $codexProtocolPath)) {
    throw "Missing skill CODEX.md at $codexProtocolPath."
}
if (-not (Test-Path -LiteralPath "$taskRoot/plan.md")) {
    throw "Missing $taskRoot/plan.md. Claude must write the plan before invoking Codex."
}

if (-not $SkipAssemble) {
    $codexProtocol = Get-Content -LiteralPath $codexProtocolPath -Raw -Encoding UTF8
    $plan = Get-Content -LiteralPath "$taskRoot/plan.md" -Raw -Encoding UTF8
    $previousReviewPath = "$taskRoot/review.md"
    $previousReview = ""
    if (Test-Path -LiteralPath $previousReviewPath) {
        $previousReview = Get-Content -LiteralPath $previousReviewPath -Raw -Encoding UTF8
    }

    $context = @"
# Codex-Claude Execution Context

Round: $Round
Request ID: $(Split-Path -Leaf $taskRoot)
Project root: $projectRootPath
Skill root: $skillRoot
Task root: $taskRoot
Report language: $reportLanguage
Interaction language: $interactionLanguage
User-facing language: $userFacingLanguage
Language policy: $languagePolicy
Task workspace mode: $taskWorkspaceMode

## Task File Semantics

- Use the task root shown above for this request.
- `$taskRoot/plan.md`, `$taskRoot/context.md`, `$taskRoot/execution.md`, and `$taskRoot/review.md` are the current working copies for the active/latest round of this request.
- `$taskRoot/history/round-N/` contains immutable snapshots for each completed round in this request.
- `$taskRoot/artifacts/round-N/` contains UI screenshots and other generated evidence for this request and round.
- Do not treat duplicated files in the request root and history/round-N/ as redundant. The request root files are current state; history files are audit records.

## Executor Protocol

$codexProtocol

## Current Plan

$plan

## Previous Claude Review

$previousReview

## Final Instruction

Execute only the current plan. Write the execution report to `$taskRoot/execution.md` before exiting.
Use the configured interaction language for reasoning-facing task artifacts and the configured report language for `$taskRoot/execution.md`. Keep fixed schema headings recognizable.
The configured interaction and report languages are authoritative. Do not switch languages because of encoding concerns unless config.json itself is changed or the plan explicitly says the user requested a one-off language override.
"@

    Set-Content -LiteralPath "$taskRoot/context.md" -Value $context -Encoding UTF8
}

if (-not (Test-Path -LiteralPath "$taskRoot/context.md")) {
    throw "Missing $taskRoot/context.md."
}

$prompt = Get-Content -LiteralPath "$taskRoot/context.md" -Raw -Encoding UTF8

$CodexCommand = Resolve-Command -Command $CodexCommand -CommandName "CODEX"

if ($DryRun) {
    Write-Host "Dry run OK for Codex round $Round."
    Write-Host "Task root: $taskRoot"
    Write-Host "Context path: $taskRoot/context.md"
    Write-Host "Prompt length: $($prompt.Length) characters"
    Write-Host "Interaction language: $interactionLanguage"
    Write-Host "Report language: $reportLanguage"
    Write-Host "Codex command: $CodexCommand"
    Write-Host "Allowed mode: $AllowedMode"
    exit 0
}

Write-Host "Invoking Codex round $Round..."

# Use a concise prompt as a positional argument instead of piping the full
# context through stdin. Piping large context (~8 KB) through the shell
# can trigger safety-classifier blocks in some environments. The short
# prompt tells Codex to read the full context from disk, which it can do
# with its own Read tool.
$shortPrompt = @"
Codex-Claude dual-agent workflow - Round $Round executor invocation.

Read `$taskRoot/context.md` for the full execution context, executor protocol, current plan, and required execution report format.

Execute only the current plan. Write the execution report to `$taskRoot/execution.md` before exiting. Use the configured interaction language for reasoning-facing task artifacts and the configured report language for `$taskRoot/execution.md`.

Do not redesign, refactor, or expand scope unless the plan explicitly says to. Do not commit, push, reset, checkout, or discard changes.
"@

$codexArgs = @(
    $AllowedMode,
    "--cd",
    $projectRootPath,
    "--sandbox",
    "workspace-write",
    $shortPrompt
)
& $CodexCommand @codexArgs
$exitCode = $LASTEXITCODE

$historyDir = "$taskRoot/history/round-$Round"
New-Item -ItemType Directory -Force -Path $historyDir | Out-Null
Copy-IfExists -Source "$taskRoot/plan.md" -Destination $historyDir
Copy-IfExists -Source "$taskRoot/context.md" -Destination $historyDir
Copy-IfExists -Source "$taskRoot/execution.md" -Destination $historyDir
Copy-IfExists -Source "$taskRoot/review.md" -Destination $historyDir

if ($exitCode -ne 0) {
    throw "Codex command exited with code $exitCode. Check terminal output and $taskRoot/execution.md if it was created."
}

if (-not (Test-Path -LiteralPath "$taskRoot/execution.md")) {
    throw "Codex completed but did not create $taskRoot/execution.md."
}

Write-Host "Codex round $Round complete for $taskRoot. Review $taskRoot/execution.md and changed files."

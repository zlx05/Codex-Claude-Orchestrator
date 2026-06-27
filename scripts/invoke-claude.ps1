param(
    [int]$Round = 1,
    [switch]$SkipAssemble,
    [switch]$DryRun,
    [string]$ClaudeCommand = "claude",
    [string]$Project = ".",
    [string]$AllowedTools = "Read,Write,Edit,Bash"
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

$root = (Resolve-Path -LiteralPath $PSScriptRoot\..).Path
Set-Location -LiteralPath $root

$config = Read-JsonFile -Path "config.json"
$maxIterations = 5
if ($null -ne $config -and $null -ne $config.maxIterations) {
    $maxIterations = [int]$config.maxIterations
}

if ($Round -lt 1) {
    throw "Round must be >= 1."
}
if ($Round -gt $maxIterations) {
    throw "Round $Round exceeds config.maxIterations=$maxIterations."
}

New-Item -ItemType Directory -Force -Path "task" | Out-Null
New-Item -ItemType Directory -Force -Path "task/history" | Out-Null
New-Item -ItemType Directory -Force -Path "task/artifacts/round-$Round" | Out-Null

if (-not (Test-Path -LiteralPath "CLAUDE.md")) {
    throw "Missing CLAUDE.md."
}
if (-not (Test-Path -LiteralPath "task/plan.md")) {
    throw "Missing task/plan.md. Codex must write the plan before invoking Claude."
}

if (-not $SkipAssemble) {
    $claudeProtocol = Get-Content -LiteralPath "CLAUDE.md" -Raw -Encoding UTF8
    $plan = Get-Content -LiteralPath "task/plan.md" -Raw -Encoding UTF8
    $previousReviewPath = "task/review.md"
    $previousReview = ""
    if (Test-Path -LiteralPath $previousReviewPath) {
        $previousReview = Get-Content -LiteralPath $previousReviewPath -Raw -Encoding UTF8
    }

    $context = @"
# Codex-Claude Execution Context

Round: $Round
Project root: $root

## Executor Protocol

$claudeProtocol

## Current Plan

$plan

## Previous Codex Review

$previousReview

## Final Instruction

Execute only the current plan. Write the execution report to task/execution.md before exiting.
"@

    Set-Content -LiteralPath "task/context.md" -Value $context -Encoding UTF8
}

if (-not (Test-Path -LiteralPath "task/context.md")) {
    throw "Missing task/context.md."
}

$prompt = Get-Content -LiteralPath "task/context.md" -Raw -Encoding UTF8

if ($DryRun) {
    Write-Host "Dry run OK for Claude round $Round."
    Write-Host "Context path: task/context.md"
    Write-Host "Prompt length: $($prompt.Length) characters"
    exit 0
}

Write-Host "Invoking Claude round $Round..."
& $ClaudeCommand -p $prompt --print --allowedTools $AllowedTools --project $Project
$exitCode = $LASTEXITCODE

$historyDir = "task/history/round-$Round"
New-Item -ItemType Directory -Force -Path $historyDir | Out-Null
Copy-IfExists -Source "task/plan.md" -Destination $historyDir
Copy-IfExists -Source "task/context.md" -Destination $historyDir
Copy-IfExists -Source "task/execution.md" -Destination $historyDir
Copy-IfExists -Source "task/review.md" -Destination $historyDir

if ($exitCode -ne 0) {
    throw "Claude command exited with code $exitCode. Check terminal output and task/execution.md if it was created."
}

if (-not (Test-Path -LiteralPath "task/execution.md")) {
    throw "Claude completed but did not create task/execution.md."
}

Write-Host "Claude round $Round complete. Review task/execution.md and changed files."

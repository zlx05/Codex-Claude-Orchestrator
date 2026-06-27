param(
    [string]$ProjectRoot = ".",
    [string]$Title = "",
    [string]$Slug = "",
    [Parameter(Mandatory = $true)]
    [string]$RequestText
)

$ErrorActionPreference = "Stop"

function Convert-ToSlug {
    param([string]$Text)
    $lower = $Text.ToLowerInvariant()
    $slug = [regex]::Replace($lower, "[^a-z0-9\u4e00-\u9fff]+", "-")
    $slug = [regex]::Replace($slug, "-+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "request"
    }
    if ($slug.Length -gt 48) {
        return $slug.Substring(0, 48).Trim("-")
    }
    return $slug
}

$skillRoot = (Resolve-Path -LiteralPath $PSScriptRoot\..).Path
$projectRootPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $projectRootPath

if ([string]::IsNullOrWhiteSpace($Title)) {
    $compact = [regex]::Replace($RequestText.Trim(), "\s+", " ")
    if ($compact.Length -gt 48) {
        $Title = $compact.Substring(0, 48).Trim()
    } else {
        $Title = $compact
    }
    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = "Untitled request"
    }
}

if ([string]::IsNullOrWhiteSpace($Slug)) {
    $Slug = Convert-ToSlug -Text $Title
} else {
    $Slug = Convert-ToSlug -Text $Slug
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$requestId = "$stamp-$Slug"
$requestRoot = "task/requests/$requestId"

New-Item -ItemType Directory -Force -Path "$requestRoot/history" | Out-Null
New-Item -ItemType Directory -Force -Path "$requestRoot/artifacts" | Out-Null

$requestDoc = @"
# User Request

RequestId: $requestId
Title: $Title
CreatedAt: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")

## Request

$RequestText
"@

$planDoc = @"
# Round 1 Plan

## Goal

TODO: Codex writes the implementation goal.

## Assumptions

- TODO

## Scope

Allowed files:
- TODO

Forbidden files/actions:
- TODO

## Required Changes

| File | Symbol/Area | Change | Acceptance Criteria |
|---|---|---|---|
| TODO | TODO | TODO | TODO |

## Implementation Order

1. TODO

## Validation

| Command | Expected Result |
|---|---|
| TODO | TODO |

## UI Evidence

TODO if UI is involved; otherwise write "Not applicable."

## Execution Report Requirements

Claude must write $requestRoot/execution.md and include status, changed files, plan checklist, validation, UI evidence, problems/deviations, and notes for Codex.
"@

$currentDoc = @"
RequestId: $requestId
TaskRoot: $requestRoot
Title: $Title
UpdatedAt: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
"@

Set-Content -LiteralPath "$requestRoot/request.md" -Value $requestDoc -Encoding UTF8
Set-Content -LiteralPath "$requestRoot/plan.md" -Value $planDoc -Encoding UTF8
Set-Content -LiteralPath "task/CURRENT.md" -Value $currentDoc -Encoding UTF8

Write-Host "Created request $requestId"
Write-Host "Task root: $requestRoot"
Write-Host "Plan path: $requestRoot/plan.md"
Write-Host "Project root: $projectRootPath"
Write-Host "Skill root: $skillRoot"

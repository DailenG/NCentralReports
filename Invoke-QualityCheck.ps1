<#
.SYNOPSIS
    Runs PSScriptAnalyzer over all project .ps1 files and reports results.
.DESCRIPTION
    Checks every .ps1 file in Private/, Reports/, and the root for issues
    flagged by PSScriptAnalyzer (PowerShell's official linter).

    Exits with code 1 if any Error-severity findings are present, so this
    can be used as a gate in CI pipelines.

    Requires PSScriptAnalyzer:
        Install-Module PSScriptAnalyzer -Scope CurrentUser
.PARAMETER Severity
    Minimum severity to report. One or more of: Error, Warning, Information.
    Defaults to all three.
.PARAMETER Fix
    If specified, attempts to auto-fix safe correctable issues (e.g. whitespace).
.EXAMPLE
    .\Invoke-QualityCheck.ps1
.EXAMPLE
    .\Invoke-QualityCheck.ps1 -Severity Error, Warning
#>
[CmdletBinding()]
param(
    [ValidateSet('Error', 'Warning', 'Information')]
    [string[]]$Severity = @('Error', 'Warning', 'Information'),

    [switch]$Fix
)

$ErrorActionPreference = 'Stop'

# ── Verify PSScriptAnalyzer ────────────────────────────────────────────────────

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "PSScriptAnalyzer not found. Installing..." -ForegroundColor Yellow
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
}
Import-Module PSScriptAnalyzer -ErrorAction Stop

# ── Collect files ──────────────────────────────────────────────────────────────

$scriptRoot = $PSScriptRoot
$files = Get-ChildItem -Path $scriptRoot -Recurse -Filter '*.ps1' |
Where-Object { $_.FullName -notlike '*\.claude\*' -and $_.FullName -notlike '*\Tests\*' } |
Sort-Object FullName

Write-Host "N-Central Reports - Quality Check" -ForegroundColor Cyan
Write-Host "Analysing $($files.Count) file(s) with PSScriptAnalyzer $((Get-Module PSScriptAnalyzer).Version)`n"

# ── Run analysis ───────────────────────────────────────────────────────────────

$allResults = foreach ($file in $files) {
    $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity $Severity -ExcludeRule PSAvoidUsingWriteHost, PSUseSingularNouns, PSUseShouldProcessForStateChangingFunctions

    if ($Fix -and $results) {
        Invoke-ScriptAnalyzer -Path $file.FullName -Fix | Out-Null
        # Re-run after fix to show remaining issues
        $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity $Severity -ExcludeRule PSAvoidUsingWriteHost, PSUseSingularNouns, PSUseShouldProcessForStateChangingFunctions
    }

    $results
}

# ── Report ─────────────────────────────────────────────────────────────────────

if (-not $allResults) {
    Write-Host "No issues found." -ForegroundColor Green
    exit 0
}

# Group by file for readable output
$byFile = $allResults | Group-Object ScriptName | Sort-Object Name

foreach ($group in $byFile) {
    Write-Host "`n  $($group.Name)" -ForegroundColor White
    foreach ($finding in $group.Group | Sort-Object Severity, Line) {
        $colour = switch ($finding.Severity) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Cyan' }
            default { 'Gray' }
        }
        Write-Host ("    [{0}] Line {1}: {2} - {3}" -f `
                $finding.Severity, $finding.Line, $finding.RuleName, $finding.Message) `
            -ForegroundColor $colour
    }
}

# Summary
$errorCount = @($allResults | Where-Object Severity -eq 'Error').Count
$warnCount = @($allResults | Where-Object Severity -eq 'Warning').Count
$infoCount = @($allResults | Where-Object Severity -eq 'Information').Count

Write-Host ("`nTotal: {0} error(s), {1} warning(s), {2} informational" -f `
        $errorCount, $warnCount, $infoCount) -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Yellow' })

if ($errorCount -gt 0) {
    exit 1
}

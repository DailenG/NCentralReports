<#
.SYNOPSIS
    Runs all Pester unit tests for NCentralReports.
.DESCRIPTION
    Discovers and runs all *.Tests.ps1 files in the Tests/ directory.
    Requires Pester 5+:
        Install-Module Pester -Scope CurrentUser -Force
.PARAMETER Verbosity
    Pester output verbosity. One of: None, Normal, Detailed, Diagnostic.
    Defaults to Normal.
.PARAMETER TestName
    Optional filter - run only tests whose Describe/It name matches this string.
.EXAMPLE
    .\Invoke-Tests.ps1
.EXAMPLE
    .\Invoke-Tests.ps1 -Verbosity Detailed
.EXAMPLE
    .\Invoke-Tests.ps1 -TestName 'Get-NCPatchDetails'
#>
[CmdletBinding()]
param(
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Verbosity = 'Normal',

    [string]$TestName = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0')) {
    Write-Host "Pester 5+ not found. Installing..." -ForegroundColor Yellow
    Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'Tests'
$config.Output.Verbosity = $Verbosity
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $PSScriptRoot 'Tests\TestResults.xml'

if ($TestName) {
    $config.Filter.FullName = "*$TestName*"
}

$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    Write-Host "`nFailed: $($result.FailedCount) test(s)" -ForegroundColor Red
    exit 1
}

Write-Host "`nPassed: $($result.PassedCount) test(s)" -ForegroundColor Green

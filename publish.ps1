<#
.SYNOPSIS
    Publishes the NCentralReports module to the PowerShell Gallery.

.PARAMETER ApiKey
    The NuGet API Key for the PowerShell Gallery. Required.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'
$moduleName = "NCentralReports"
$modulePath = $PSScriptRoot
$stagingPath = Join-Path -Path $modulePath -ChildPath "Staging"
$stagingModulePath = Join-Path -Path $stagingPath -ChildPath $moduleName

Write-Host "Starting publication process for '$moduleName'..." -ForegroundColor Cyan

try {
    Write-Host "Creating staging directory at '$stagingModulePath'..." -ForegroundColor Cyan
    if (Test-Path -Path $stagingPath) {
        Remove-Item -Path $stagingPath -Recurse -Force
    }
    New-Item -Path $stagingModulePath -ItemType Directory -Force | Out-Null

    Write-Host "Copying module files to staging..." -ForegroundColor Cyan
    $itemsToCopy = @(
        "$moduleName.psd1",
        "$moduleName.psm1",
        "Public",
        "Private",
        "README.md"
    )

    foreach ($item in $itemsToCopy) {
        $sourcePath = Join-Path -Path $modulePath -ChildPath $item
        if (Test-Path -Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $stagingModulePath -Recurse -Force
        }
        else {
            Write-Warning "Item '$item' not found, skipping..."
        }
    }

    Write-Host "Publishing module to PowerShell Gallery..." -ForegroundColor Cyan
    Publish-Module -Path $stagingModulePath -NuGetApiKey $ApiKey -Verbose
    
    Write-Host "Cleaning up staging directory..." -ForegroundColor Cyan
    Remove-Item -Path $stagingPath -Recurse -Force

    Write-Host "Successfully published $moduleName!" -ForegroundColor Green
}
catch {
    Write-Error "Publishing failed: $_"
}

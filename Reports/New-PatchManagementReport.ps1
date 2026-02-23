function New-PatchManagementReport {
    <#
    .SYNOPSIS
        Generates a self-contained HTML patch management dashboard using PSWriteHTML.
    .DESCRIPTION
        Produces a four-tab HTML report:
          - Overview    : KPI cards, donut chart, bar chart, top-10 issues table
          - PME Issues  : Full table of affected devices with conditional row colouring
          - Error Catalog : Unique PME errors ranked by frequency
          - All Devices : Complete device list (populated only when -IncludeHealthy used)

        Requires the PSWriteHTML module. Install with:
            Install-Module PSWriteHTML -Scope CurrentUser
    .PARAMETER ReportData
        Array of PSCustomObject rows from the orchestrator. Each row must contain:
          DeviceName, CustomerName, SiteName, ServiceState, PMEThresholdStatus,
          PMEStatus, LastChecked, PatchState
    .PARAMETER OutputPath
        Full path for the output HTML file.
    .PARAMETER ReportTitle
        Optional custom title. Defaults to 'N-Central Patch Management Report'.
    .PARAMETER GeneratedBy
        String describing the scope/filters used, shown in the report header.
    .EXAMPLE
        New-PatchManagementReport -ReportData $rows -OutputPath '.\report.html'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$ReportData,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$ReportTitle  = 'N-Central Patch Management Report',

        [string]$GeneratedBy  = ''
    )

    # Verify PSWriteHTML is available
    if (-not (Get-Module -ListAvailable -Name PSWriteHTML)) {
        throw "PSWriteHTML module not found. Install it with: Install-Module PSWriteHTML -Scope CurrentUser"
    }
    Import-Module PSWriteHTML -ErrorAction Stop

    # ── Derive report datasets ──────────────────────────────────────────────────

    $issueRows  = @($ReportData | Where-Object { $_.ServiceState -ne 'Normal' })
    $allRows    = @($ReportData)

    # KPI counts
    $total      = $allRows.Count
    $issueCount = $issueRows.Count
    $okCount    = $total - $issueCount
    $pct        = if ($total -gt 0) { [Math]::Round(($okCount / $total) * 100, 1) } else { 0 }
    $failCount  = @($issueRows | Where-Object { $_.ServiceState -eq 'Failed'  }).Count
    $warnCount  = @($issueRows | Where-Object { $_.ServiceState -eq 'Warning' }).Count
    $critical   = $failCount

    # Top 10 issues (most recent by LastChecked, then by state severity)
    $top10 = $issueRows |
        Sort-Object @{ Expression = { switch ($_.ServiceState) { 'Failed' { 0 } 'Warning' { 1 } default { 2 } } } },
                    @{ Expression = 'LastChecked'; Descending = $true } |
        Select-Object -First 10 DeviceName, CustomerName, SiteName, ServiceState, PMEStatus, LastChecked

    # Error catalog — unique PME errors ranked by count
    $errorCatalog = $issueRows |
        Where-Object { $_.PMEStatus -ne 'N/A' -and -not [string]::IsNullOrWhiteSpace($_.PMEStatus) } |
        Group-Object PMEStatus |
        Sort-Object Count -Descending |
        ForEach-Object {
            [PSCustomObject]@{
                PMEStatus       = $_.Name
                Count           = $_.Count
                AffectedDevices = ($_.Group | Select-Object -ExpandProperty DeviceName | Sort-Object | Select-Object -Unique) -join ', '
            }
        }

    # Issues by customer for bar chart
    $byCustomer = $issueRows |
        Group-Object CustomerName |
        Sort-Object Count -Descending |
        Select-Object -First 15  # cap at 15 for readability

    # ── Build the HTML report ──────────────────────────────────────────────────

    $generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $subtitle    = if ($GeneratedBy) { " — $GeneratedBy" } else { '' }

    New-HTML -TitleText $ReportTitle -FilePath $OutputPath -ShowHTML:$false {

        New-HTMLHeader {
            New-HTMLText -Text "$ReportTitle$subtitle" -FontSize 22 -FontWeight bold -Color '#2c3e50'
            New-HTMLText -Text "Generated: $generatedAt" -FontSize 12 -Color '#7f8c8d'
        }

        # ── Tab 1: Overview ────────────────────────────────────────────────────
        New-HTMLTab -Name 'Overview' -IconSolid 'chart-pie' {

            # KPI cards
            New-HTMLSection -Direction row -Invisible {
                New-HTMLPanel {
                    New-HTMLInfoCard -Title 'Devices Scanned' -Number $total `
                                    -TitleColor '#2c3e50' -NumberColor '#2980b9' -Icon 'fas fa-server'
                }
                New-HTMLPanel {
                    New-HTMLInfoCard -Title 'Devices with Issues' -Number $issueCount `
                                    -TitleColor '#2c3e50' -NumberColor '#e74c3c' -Icon 'fas fa-exclamation-triangle'
                }
                New-HTMLPanel {
                    New-HTMLInfoCard -Title 'Healthy %' -Number "$pct%" `
                                    -TitleColor '#2c3e50' -NumberColor '#27ae60' -Icon 'fas fa-check-circle'
                }
                New-HTMLPanel {
                    New-HTMLInfoCard -Title 'Critical Failures' -Number $critical `
                                    -TitleColor '#2c3e50' -NumberColor '#c0392b' -Icon 'fas fa-times-circle'
                }
            }

            # Charts side by side
            New-HTMLSection -Direction row -HeaderText 'Status Distribution' {
                New-HTMLPanel {
                    New-HTMLChart -Title 'PME Status Distribution' -Height 300 {
                        New-ChartToolbar -Download
                        if ($failCount -gt 0) {
                            New-ChartDonut -Name 'Failed'  -Value $failCount  -Color '#e74c3c'
                        }
                        if ($warnCount -gt 0) {
                            New-ChartDonut -Name 'Warning' -Value $warnCount  -Color '#f39c12'
                        }
                        if ($okCount -gt 0) {
                            New-ChartDonut -Name 'Healthy' -Value $okCount    -Color '#2ecc71'
                        }
                        if ($total -eq 0) {
                            New-ChartDonut -Name 'No Data' -Value 1           -Color '#bdc3c7'
                        }
                    }
                }
                New-HTMLPanel {
                    New-HTMLChart -Title 'Issues by Customer' -Height 300 {
                        New-ChartToolbar -Download
                        New-ChartCategory -Name ($byCustomer | Select-Object -ExpandProperty Name)
                        New-ChartBar -Name 'Issue Count' -Value ($byCustomer | Select-Object -ExpandProperty Count) -Color '#e67e22'
                    }
                }
            }

            # Top 10 quick-view
            New-HTMLSection -HeaderText 'Top 10 Issues' -CanCollapse {
                if ($top10 -and @($top10).Count -gt 0) {
                    New-HTMLTable -DataTable $top10 -DisablePaging -DisableSearch -HideFooter {
                        New-TableCondition -Name 'ServiceState' -Value 'Failed'  -Operator eq `
                            -ComparisonType string -BackgroundColor '#e74c3c' -Color white -Row
                        New-TableCondition -Name 'ServiceState' -Value 'Warning' -Operator eq `
                            -ComparisonType string -BackgroundColor '#f39c12' -Color white -Row
                    }
                }
                else {
                    New-HTMLText -Text 'No patch issues found.' -Color '#27ae60' -FontWeight bold
                }
            }
        }

        # ── Tab 2: PME Issues ──────────────────────────────────────────────────
        New-HTMLTab -Name 'PME Issues' -IconSolid 'exclamation-triangle' {
            New-HTMLSection -HeaderText "Affected Devices ($issueCount)" {
                if ($issueRows -and @($issueRows).Count -gt 0) {
                    New-HTMLTable -DataTable $issueRows `
                                  -Filtering `
                                  -Buttons @('excelHtml5', 'csvHtml5', 'pdfHtml5', 'copyHtml5') `
                                  -DefaultSortColumn 'ServiceState' {
                        New-TableCondition -Name 'ServiceState' -Value 'Failed'  -Operator eq `
                            -ComparisonType string -BackgroundColor '#fadbd8' -Color '#922b21' -Row
                        New-TableCondition -Name 'ServiceState' -Value 'Warning' -Operator eq `
                            -ComparisonType string -BackgroundColor '#fdebd0' -Color '#784212' -Row
                        New-TableHeader -Names 'DeviceName', 'CustomerName', 'SiteName', `
                                                'ServiceState', 'PMEThresholdStatus', `
                                                'PMEStatus', 'LastChecked' `
                                        -Title 'Patch Management Issues'
                    }
                }
                else {
                    New-HTMLText -Text 'No patch issues found — all devices are healthy.' `
                                 -Color '#27ae60' -FontWeight bold -FontSize 16
                }
            }
        }

        # ── Tab 3: Error Catalog ───────────────────────────────────────────────
        New-HTMLTab -Name 'Error Catalog' -IconSolid 'list-alt' {
            New-HTMLSection -HeaderText 'Unique PME Error Messages' {
                if ($errorCatalog -and @($errorCatalog).Count -gt 0) {
                    New-HTMLTable -DataTable $errorCatalog `
                                  -Filtering `
                                  -DefaultSortColumn 'Count' `
                                  -DefaultSortOrder Descending `
                                  -Buttons @('excelHtml5', 'csvHtml5') {
                        New-TableCondition -Name 'Count' -ComparisonType number -Operator gt `
                            -Value 5 -BackgroundColor '#f5b7b1' -Row
                        New-TableHeader -Names 'PMEStatus', 'Count', 'AffectedDevices' `
                                        -Title 'Error Frequency'
                    }
                }
                else {
                    New-HTMLText -Text 'No PME error messages found.' -Color '#27ae60' -FontWeight bold
                }
            }
        }

        # ── Tab 4: All Devices ─────────────────────────────────────────────────
        New-HTMLTab -Name 'All Devices' -IconSolid 'server' -Collapsed {
            New-HTMLSection -HeaderText "Complete Device Status ($total devices)" -CanCollapse {
                if ($allRows -and @($allRows).Count -gt 0) {
                    $allDeviceRows = $allRows | Select-Object DeviceName, CustomerName, SiteName,
                                                               PatchState, PMEStatus

                    New-HTMLTable -DataTable $allDeviceRows -Filtering {
                        New-TableCondition -Name 'PatchState' -Value 'Normal' -Operator eq `
                            -ComparisonType string -BackgroundColor '#d5f5e3' -Row
                        New-TableCondition -Name 'PatchState' -Value 'Failed' -Operator eq `
                            -ComparisonType string -BackgroundColor '#fadbd8' -Row
                        New-TableCondition -Name 'PatchState' -Value 'Warning' -Operator eq `
                            -ComparisonType string -BackgroundColor '#fdebd0' -Row
                    }
                }
                else {
                    New-HTMLText -Text 'No device data available. Run with -IncludeHealthy to populate this tab.' `
                                 -Color '#7f8c8d'
                }
            }
        }

    }  # end New-HTML

    Write-Verbose "Report written to: $OutputPath"
}

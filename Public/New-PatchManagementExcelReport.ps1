function New-PatchManagementExcelReport {
    <#
    .SYNOPSIS
        Generates an Excel patch management report from N-Central data.
        
    .DESCRIPTION
        Takes the array of device patch states and outputs a multi-sheet Excel workbook.
        Requires the ImportExcel module.
        
    .PARAMETER ReportData
        Array of PSCustomObjects containing the parsed device and patch state data.
        
    .PARAMETER OutputPath
        Absolute or relative path to save the .xlsx file.
        
    .PARAMETER TotalDevicesScanned
        Integer count of all devices enumerated during the scan.
        
    .EXAMPLE
        New-PatchManagementExcelReport -ReportData $data -OutputPath "C:\Reports\PatchReport.xlsx" -TotalDevicesScanned 150
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ReportData,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [int]$TotalDevicesScanned
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        throw "The 'ImportExcel' module is required to generate this report. Please run: Install-Module ImportExcel -Scope CurrentUser"
    }

    $resolvedPath = $OutputPath
    if (-not [System.IO.Path]::IsPathRooted($resolvedPath)) {
        $resolvedPath = Join-Path (Get-Location).Path $OutputPath
    }

    Write-Verbose "Writing Excel report to $resolvedPath"

    # Ensure any existing file is removed to prevent appending to an old workbook
    if (Test-Path $resolvedPath) {
        Remove-Item $resolvedPath -Force
    }

    # ── Calculate Summary Metrics ────────────────────────────────────────────────

    $issuesCount = @($ReportData | Where-Object { $_.ServiceState -ne 'Normal' }).Count
    $healthyCount = $TotalDevicesScanned - $issuesCount
    
    $healthyPercent = 100
    if ($TotalDevicesScanned -gt 0) {
        $healthyPercent = [math]::Round(($healthyCount / $TotalDevicesScanned) * 100, 1)
    }

    $summaryProps = [ordered]@{
        'Total Devices Scanned' = $TotalDevicesScanned
        'Healthy Devices'       = $healthyCount
        'Devices with Issues'   = $issuesCount
        'Health Percentage'     = "$healthyPercent %"
        'Report Generated On'   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $summaryObj = [PSCustomObject]$summaryProps

    # ── Export Sheet 1: Summary ─────────────────────────────────────────────────
    
    $summaryObj | Export-Excel -Path $resolvedPath -WorksheetName "Summary" -AutoSize -BoldTopRow -TableName "SummaryMetrics"

    # Add a pivot table to summarize issues by customer
    if ($ReportData.Count -gt 0) {
        $ReportData | Export-Excel -Path $resolvedPath -WorksheetName "Customer Issues Pivot" `
            -PivotRows CustomerName -PivotData @{DeviceName = 'count' } `
            -IncludePivotTable -AutoSize
    }

    # ── Export Sheet 2: PME Issues ──────────────────────────────────────────────
    
    $issueRows = @($ReportData | Where-Object { $_.ServiceState -ne 'Normal' })
    if ($issueRows.Count -gt 0) {
        # Select the relevant columns to display
        $formattedIssues = $issueRows | Select-Object CustomerName, SiteName, DeviceName, ServiceState, PMEThresholdStatus, PMEStatus
        
        # Apply conditional formatting for 'Failed' states using Excel formulas
        $formattedIssues | Export-Excel -Path $resolvedPath -WorksheetName "PME Issues" -AutoSize -BoldTopRow -TableName "IssuesTable" -FreezeTopRow
        
        $excel = Open-ExcelPackage -Path $resolvedPath
        $wsIssues = $excel.Workbook.Worksheets["PME Issues"]
        
        # Red background for 'Failed'
        Add-ConditionalFormatting -Worksheet $wsIssues -Range "D2:D$($issueRows.Count + 1)" -RuleType ContainsText -ConditionValue "Failed" -BackgroundColor Red -ForegroundColor White
        
        # Orange/Yellow background for 'Warning'
        Add-ConditionalFormatting -Worksheet $wsIssues -Range "D2:D$($issueRows.Count + 1)" -RuleType ContainsText -ConditionValue "Warning" -BackgroundColor DarkOrange -ForegroundColor White
        
        Close-ExcelPackage $excel -Show
    }

    # ── Export Sheet 3: All Devices ─────────────────────────────────────────────

    if ($ReportData.Count -gt 0) {
        $formattedAll = $ReportData | Select-Object CustomerName, SiteName, DeviceName, ServiceState
        $formattedAll | Export-Excel -Path $resolvedPath -WorksheetName "All Devices" -AutoSize -BoldTopRow -TableName "AllDevicesTable"
        
        $excelAll = Open-ExcelPackage -Path $resolvedPath
        $wsAll = $excelAll.Workbook.Worksheets["All Devices"]
        
        Add-ConditionalFormatting -Worksheet $wsAll -Range "D2:D$($ReportData.Count + 1)" -RuleType ContainsText -ConditionValue "Failed" -BackgroundColor Red -ForegroundColor White
        Add-ConditionalFormatting -Worksheet $wsAll -Range "D2:D$($ReportData.Count + 1)" -RuleType ContainsText -ConditionValue "Warning" -BackgroundColor DarkOrange -ForegroundColor White
        Add-ConditionalFormatting -Worksheet $wsAll -Range "D2:D$($ReportData.Count + 1)" -RuleType ContainsText -ConditionValue "Normal" -BackgroundColor DarkGreen -ForegroundColor White
        
        Close-ExcelPackage $excelAll -Show
    }
}

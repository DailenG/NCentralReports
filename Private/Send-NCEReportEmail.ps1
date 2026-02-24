function Send-NCEReportEmail {
    <#
    .SYNOPSIS
        Emails the generated N-Central Patch Management report using the Mailozaurr module.
        
    .DESCRIPTION
        Takes the generated Excel or HTML report file path and sends it using
        Send-EmailMessage from the Mailozaurr module. 
        
    .PARAMETER FilePath
        Absolute path to the generated report file.
        
    .PARAMETER To
        Email recipient(s). Comma separated string or array.
        
    .PARAMETER From
        Sender email address.
        
    .PARAMETER SmtpServer
        Hostname or IP of the SMTP Server.
        
    .EXAMPLE
        Send-NCEReportEmail -FilePath "C:\reports\Report.xlsx" -To "admin@domain.com" -From "reports@domain.com" -SmtpServer "smtp.domain.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$To,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$SmtpServer,

        [Parameter(Mandatory)]
        [string]$SmtpUsername,

        [Parameter(Mandatory)]
        [securestring]$SmtpPassword
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module -ListAvailable -Name Mailozaurr)) {
        throw "The 'Mailozaurr' module is required to send emails. Please run: Install-Module Mailozaurr -Scope CurrentUser"
    }

    if (-not (Test-Path $FilePath)) {
        throw "Cannot find attachment at path: $FilePath"
    }
    
    $fileName = Split-Path -Path $FilePath -Leaf
    Write-Verbose "Preparing to email $fileName via $SmtpServer"

    $subject = "N-Central Patch Management Report - $((Get-Date).ToString('yyyy-MM-dd'))"
    $body = @"
Hello,

Attached is the latest automated N-Central Patch Management Report for your review.

Generated On: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Regards,
NCentralReports Service
"@

    try {
        $credential = New-Object System.Management.Automation.PSCredential($SmtpUsername, $SmtpPassword)

        Send-EmailMessage -To $To -From $From -Subject $subject -Body $body -Attachments $FilePath -SmtpServer $SmtpServer -Credential $credential
        Write-Host "  Report emailed successfully to $($To -join ', ')" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send email: $_"
    }
}

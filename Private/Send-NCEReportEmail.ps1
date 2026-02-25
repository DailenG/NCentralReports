function Send-NCEReportEmail {
    <#
    .SYNOPSIS
        Emails the generated N-Central Patch Management report using the Mailozaurr module.
        
    .DESCRIPTION
        Takes the generated Excel or HTML report file path and sends it using
        Send-EmailMessage from the Mailozaurr module. 
        
    .PARAMETER FilePath
        Absolute path(s) to the generated report file(s). Comma separated string or array.
        
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
        [string[]]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$To,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$SmtpServer,

        [Parameter(Mandatory)]
        [string]$SmtpUsername,

        [Parameter(Mandatory)]
        [securestring]$SmtpPassword,

        [Parameter()]
        [int]$Port,

        [Parameter()]
        [switch]$SkipCertificateValidation
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module -ListAvailable -Name Mailozaurr)) {
        throw "The 'Mailozaurr' module is required to send emails. Please run: Install-Module Mailozaurr -Scope CurrentUser"
    }

    $fileNames = @()
    foreach ($path in $FilePath) {
        if (-not (Test-Path $path)) {
            throw "Cannot find attachment at path: $path"
        }
        $fileNames += Split-Path -Path $path -Leaf
    }
    
    $namesJoined = $fileNames -join ', '
    Write-Verbose "Preparing to email $namesJoined via $SmtpServer"

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

        $emailParams = @{
            To          = $To
            From        = $From
            Subject     = $subject
            Body        = $body
            Attachments = $FilePath
            SmtpServer  = $SmtpServer
            Credential  = $credential
        }

        if ($Port) {
            $emailParams.Port = $Port
        }
        
        Send-EmailMessage @emailParams
        Write-Host "  Report emailed successfully to $($To -join ', ')" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send email: $_"
    }
}

<#
.SYNOPSIS
    Sends Windows toast notifications

.DESCRIPTION
    Sends notifications using BurntToast module for important events

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Send-Notification {
    <#
    .SYNOPSIS
        Sends a Windows toast notification
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Type = "Info",

        [Parameter()]
        [string]$ProjectName = $null
    )

    try {
        # Check if BurntToast module is available
        if (-not (Get-Module -ListAvailable -Name BurntToast)) {
            Write-Verbose "BurntToast module not installed. Skipping notification."
            return
        }

        Import-Module BurntToast -ErrorAction SilentlyContinue

        # Format message with project name
        $fullMessage = if ($ProjectName) {
            "Project: $ProjectName`n`n$Message"
        }
        else {
            $Message
        }

        # Send toast notification
        $toastParams = @{
            Text = @($Title, $fullMessage)
            AppLogo = $null  # TODO: Add watchdog icon
        }

        New-BurntToastNotification @toastParams

        Write-Verbose "Notification sent: $Title"
    }
    catch {
        Write-Warning "Failed to send notification: $_"
    }
}

function Send-ErrorNotification {
    <#
    .SYNOPSIS
        Sends an error notification
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$ProjectName = $null
    )

    Send-Notification -Title "Claude Code Watchdog - Error" -Message $Message -Type "Error" -ProjectName $ProjectName
}

function Send-SuccessNotification {
    <#
    .SYNOPSIS
        Sends a success notification
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$ProjectName = $null
    )

    Send-Notification -Title "Claude Code Watchdog - Success" -Message $Message -Type "Success" -ProjectName $ProjectName
}

function Test-NotificationRateLimit {
    <#
    .SYNOPSIS
        Checks if notification rate limit has been reached
    #>
    param(
        [Parameter()]
        [int]$MaxPerHour = 10
    )

    $rateLimitFile = "$HOME/.claude-automation/notification-rate-limit.json"

    if (-not (Test-Path $rateLimitFile)) {
        @{ Count = 0; LastReset = Get-Date } | ConvertTo-Json | Set-Content $rateLimitFile
        return $false
    }

    $data = Get-Content $rateLimitFile -Raw | ConvertFrom-Json
    $lastReset = [DateTime]::Parse($data.LastReset)

    # Reset if more than 1 hour has passed
    if ((Get-Date) - $lastReset -gt [TimeSpan]::FromHours(1)) {
        @{ Count = 0; LastReset = Get-Date } | ConvertTo-Json | Set-Content $rateLimitFile
        return $false
    }

    # Check if limit reached
    if ($data.Count -ge $MaxPerHour) {
        Write-Verbose "Notification rate limit reached ($MaxPerHour per hour)"
        return $true
    }

    # Increment count
    $data.Count++
    $data | ConvertTo-Json | Set-Content $rateLimitFile

    return $false
}

# Export functions
Export-ModuleMember -Function Send-Notification, Send-ErrorNotification, Send-SuccessNotification, Test-NotificationRateLimit

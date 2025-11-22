<#
.SYNOPSIS
    Logging functions for Claude Code Watchdog

.DESCRIPTION
    Provides logging to console and files with different severity levels

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Write-WatchdogLog {
    <#
    .SYNOPSIS
        Writes a log message to console and/or file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level = "Info",

        [Parameter()]
        [string]$ProjectName = $null,

        [Parameter()]
        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to console with colors
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Debug" { "Gray" }
            default { "White" }
        }

        Write-Host $logEntry -ForegroundColor $color
    }

    # Write to global log file
    $globalLogPath = "$HOME/.claude-automation/logs/watchdog-$(Get-Date -Format 'yyyy-MM-dd').log"
    $logEntry | Add-Content -Path $globalLogPath -Force

    # Write to project-specific log if project name provided
    if ($ProjectName) {
        try {
            $config = Get-ProjectConfig -ProjectName $ProjectName
            $projectLogPath = Join-Path $config.repoPath ".claude-automation/watchdog.log"
            $logEntry | Add-Content -Path $projectLogPath -Force
        }
        catch {
            Write-Verbose "Could not write to project log: $_"
        }
    }
}

function Write-Debug {
    <#
    .SYNOPSIS
        Writes a debug message
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [string]$ProjectName = $null
    )

    if ($VerbosePreference -eq "Continue" -or $DebugPreference -eq "Continue") {
        Write-WatchdogLog -Message $Message -Level "Debug" -ProjectName $ProjectName
    }
}

function Initialize-LogRotation {
    <#
    .SYNOPSIS
        Sets up log rotation to manage file sizes
    #>
    param(
        [Parameter()]
        [int]$MaxLogAgeDays = 7,

        [Parameter()]
        [long]$MaxLogSizeMB = 10
    )

    $logDir = "$HOME/.claude-automation/logs"

    if (-not (Test-Path $logDir)) {
        return
    }

    # Remove old log files
    $cutoffDate = (Get-Date).AddDays(-$MaxLogAgeDays)
    Get-ChildItem -Path $logDir -Filter "*.log" |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force

    # Archive large log files
    $maxSizeBytes = $MaxLogSizeMB * 1MB
    Get-ChildItem -Path $logDir -Filter "*.log" |
        Where-Object { $_.Length -gt $maxSizeBytes } |
        ForEach-Object {
            $archiveName = "$($_.BaseName)-$(Get-Date -Format 'yyyyMMdd-HHmmss').log.old"
            $archivePath = Join-Path $logDir $archiveName
            Move-Item -Path $_.FullName -Destination $archivePath -Force
        }
}

# Export functions
Export-ModuleMember -Function Write-WatchdogLog, Write-Debug, Initialize-LogRotation

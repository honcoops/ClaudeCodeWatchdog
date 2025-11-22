<#
.SYNOPSIS
    Convenience wrapper to start the Claude Code Watchdog

.DESCRIPTION
    Starts the watchdog from the project root directory

.PARAMETER PollingInterval
    Interval in seconds between polling cycles (default: 120)

.PARAMETER MaxRunDuration
    Maximum runtime in hours before auto-shutdown (default: none)

.EXAMPLE
    .\Start-Watchdog.ps1

.EXAMPLE
    .\Start-Watchdog.ps1 -PollingInterval 60 -MaxRunDuration 8

.NOTES
    Part of the Claude Code Watchdog project
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$PollingInterval = 120,

    [Parameter()]
    [int]$MaxRunDuration = 0
)

$scriptPath = Join-Path $PSScriptRoot "src/Core/Start-Watchdog.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Start-Watchdog.ps1 not found at $scriptPath"
    exit 1
}

& $scriptPath -PollingInterval $PollingInterval -MaxRunDuration $MaxRunDuration

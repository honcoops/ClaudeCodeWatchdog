<#
.SYNOPSIS
    Initializes the watchdog environment

.DESCRIPTION
    Sets up necessary directories, validates prerequisites, and loads configuration

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Initialize-WatchdogEnvironment {
    <#
    .SYNOPSIS
        Initializes the watchdog environment and validates prerequisites
    #>

    # Create necessary directories
    $directories = @(
        "$HOME/.claude-automation",
        "$HOME/.claude-automation/logs",
        "$HOME/.claude-automation/state"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Verbose "Created directory: $dir"
        }
    }

    # Validate prerequisites
    Test-Prerequisites

    # Load global configuration
    $script:WatchdogConfig = Get-WatchdogConfig

    # Initialize global state
    Initialize-GlobalState
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that all prerequisites are met
    #>

    $errors = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $errors += "PowerShell 7.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
    }

    # Check for required modules
    # TODO: Add BurntToast module check when notifications are implemented

    # Check for Windows MCP
    # TODO: Add Windows MCP validation

    if ($errors.Count -gt 0) {
        Write-Error "Prerequisites not met:`n$($errors -join "`n")"
        throw "Prerequisites check failed"
    }

    Write-Verbose "All prerequisites validated"
}

function Initialize-GlobalState {
    <#
    .SYNOPSIS
        Initializes global state variables
    #>

    $global:WatchdogRunning = $false
    $global:WatchdogStartTime = Get-Date
    $global:WatchdogStats = @{
        ProjectsProcessed = 0
        DecisionsMade = 0
        CommandsSent = 0
        ErrorsEncountered = 0
    }
}

function Get-ActiveProjects {
    <#
    .SYNOPSIS
        Gets all active projects from registry
    #>

    try {
        $projects = Get-RegisteredProjects
        return $projects | Where-Object { $_.Status -eq "Active" }
    }
    catch {
        Write-Warning "Failed to get active projects: $_"
        return @()
    }
}

# Export functions
Export-ModuleMember -Function Initialize-WatchdogEnvironment, Test-Prerequisites, Get-ActiveProjects

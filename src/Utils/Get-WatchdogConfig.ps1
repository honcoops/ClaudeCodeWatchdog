<#
.SYNOPSIS
    Configuration management for Claude Code Watchdog

.DESCRIPTION
    Loads and manages global watchdog configuration

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Get-WatchdogConfig {
    <#
    .SYNOPSIS
        Gets the global watchdog configuration
    #>

    $configPath = "$HOME/.claude-automation/watchdog-config.json"

    # Create default config if it doesn't exist
    if (-not (Test-Path $configPath)) {
        $defaultConfig = Get-DefaultConfig
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
        Write-Verbose "Created default configuration at $configPath"
    }

    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        Write-Error "Failed to load configuration: $_"
        return Get-DefaultConfig
    }
}

function Get-DefaultConfig {
    <#
    .SYNOPSIS
        Returns the default watchdog configuration
    #>

    return @{
        version = "1.0"
        polling = @{
            intervalSeconds = 120
            maxConcurrentProjects = 10
        }
        logging = @{
            level = "Info"
            maxLogAgeDays = 7
            maxLogSizeMB = 10
        }
        notifications = @{
            enabled = $true
            maxPerHour = 10
        }
        api = @{
            enabled = $false
            model = "claude-3-5-sonnet-20241022"
            maxTokens = 1000
            temperature = 0.7
            dailyCostLimit = 10.0
            weeklyCostLimit = 50.0
        }
        windowsMCP = @{
            maxRetries = 3
            retryDelaySeconds = 2
            visionMode = $false
        }
    }
}

function Set-WatchdogConfig {
    <#
    .SYNOPSIS
        Updates global watchdog configuration
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$ConfigUpdates
    )

    $configPath = "$HOME/.claude-automation/watchdog-config.json"
    $config = Get-WatchdogConfig

    # Apply updates
    foreach ($key in $ConfigUpdates.Keys) {
        $config.$key = $ConfigUpdates[$key]
    }

    # Save
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force

    Write-Verbose "Configuration updated"
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Gets a specific configuration value
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $config = Get-WatchdogConfig

    # Support dot notation: "api.model"
    $parts = $Path -split '\.'
    $value = $config

    foreach ($part in $parts) {
        if ($value -is [PSCustomObject]) {
            $value = $value.$part
        }
        elseif ($value -is [hashtable]) {
            $value = $value[$part]
        }
        else {
            return $null
        }
    }

    return $value
}

# Export functions
Export-ModuleMember -Function Get-WatchdogConfig, Set-WatchdogConfig, Get-ConfigValue, Get-DefaultConfig

<#
.SYNOPSIS
    Gets all registered projects from the watchdog registry

.DESCRIPTION
    Loads and returns the list of registered projects

.EXAMPLE
    $projects = Get-RegisteredProjects

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Get-RegisteredProjects {
    <#
    .SYNOPSIS
        Retrieves all registered projects
    #>

    $registryPath = "$HOME/.claude-automation/registry.json"

    if (-not (Test-Path $registryPath)) {
        Write-Verbose "No registry file found"
        return @()
    }

    try {
        $registry = Get-Content $registryPath -Raw | ConvertFrom-Json

        if (-not $registry.projects) {
            return @()
        }

        # Convert to array of project objects
        $projects = @()
        $registry.projects.PSObject.Properties | ForEach-Object {
            $projectData = $_.Value
            $projects += @{
                Name = $_.Name
                ConfigPath = $projectData.configPath
                Status = $projectData.status
                RegisteredAt = $projectData.registeredAt
                LastChecked = $projectData.lastChecked
                SessionId = $projectData.sessionId
            }
        }

        return $projects
    }
    catch {
        Write-Error "Failed to load registry: $_"
        return @()
    }
}

function Get-ProjectConfig {
    <#
    .SYNOPSIS
        Gets the configuration for a specific project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    $projects = Get-RegisteredProjects
    $project = $projects | Where-Object { $_.Name -eq $ProjectName }

    if (-not $project) {
        throw "Project not found in registry: $ProjectName"
    }

    if (-not (Test-Path $project.ConfigPath)) {
        throw "Config file not found: $($project.ConfigPath)"
    }

    return Get-Content $project.ConfigPath -Raw | ConvertFrom-Json
}

# Export functions
Export-ModuleMember -Function Get-RegisteredProjects, Get-ProjectConfig

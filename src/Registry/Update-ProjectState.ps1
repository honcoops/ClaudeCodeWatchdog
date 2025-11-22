<#
.SYNOPSIS
    Updates project state in the registry and state files

.DESCRIPTION
    Manages project state persistence and updates

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Update-ProjectState {
    <#
    .SYNOPSIS
        Updates project state with new information
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [hashtable]$StateUpdates
    )

    # Load current state
    $config = Get-ProjectConfig -ProjectName $ProjectName
    $statePath = Join-Path $config.repoPath ".claude-automation/current-state.json"

    if (-not (Test-Path $statePath)) {
        throw "State file not found for project: $ProjectName"
    }

    $state = Get-Content $statePath -Raw | ConvertFrom-Json | ConvertTo-Hashtable

    # Apply updates
    foreach ($key in $StateUpdates.Keys) {
        $state[$key] = $StateUpdates[$key]
    }

    # Save state
    $state | ConvertTo-Json -Depth 10 | Set-Content $statePath -Force

    Write-Verbose "Updated state for project: $ProjectName"
}

function Get-ProjectState {
    <#
    .SYNOPSIS
        Retrieves current project state
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    $config = Get-ProjectConfig -ProjectName $ProjectName
    $statePath = Join-Path $config.repoPath ".claude-automation/current-state.json"

    if (-not (Test-Path $statePath)) {
        throw "State file not found for project: $ProjectName"
    }

    return Get-Content $statePath -Raw | ConvertFrom-Json
}

function Update-RegistrySessionId {
    <#
    .SYNOPSIS
        Updates the session ID for a project in the registry
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [string]$SessionId
    )

    $registryPath = "$HOME/.claude-automation/registry.json"

    if (-not (Test-Path $registryPath)) {
        throw "Registry not found"
    }

    $registry = Get-Content $registryPath -Raw | ConvertFrom-Json

    if (-not $registry.projects.$ProjectName) {
        throw "Project not found in registry: $ProjectName"
    }

    $registry.projects.$ProjectName.sessionId = $SessionId
    $registry.projects.$ProjectName.lastChecked = Get-Date -Format "o"
    $registry.lastUpdated = Get-Date -Format "o"

    $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath -Force

    Write-Verbose "Updated session ID for $ProjectName : $SessionId"
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts a PSCustomObject to a hashtable
    #>
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @()
            foreach ($object in $InputObject) { $collection += ConvertTo-Hashtable $object }
            return ,$collection
        }
        elseif ($InputObject -is [PSCustomObject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable $property.Value
            }
            return $hash
        }
        else {
            return $InputObject
        }
    }
}

# Export functions
Export-ModuleMember -Function Update-ProjectState, Get-ProjectState, Update-RegistrySessionId

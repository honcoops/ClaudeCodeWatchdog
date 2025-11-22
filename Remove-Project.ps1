<#
.SYNOPSIS
    Unregisters a project from the watchdog

.DESCRIPTION
    Removes a project from the Claude Code Watchdog registry

.PARAMETER ProjectName
    Name of the project to unregister

.PARAMETER KeepState
    If specified, preserves the project state files

.EXAMPLE
    .\Remove-Project.ps1 -ProjectName "my-project"

.EXAMPLE
    .\Remove-Project.ps1 -ProjectName "my-project" -KeepState

.NOTES
    Part of the Claude Code Watchdog project
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter()]
    [switch]$KeepState
)

Write-Host "🗑️  Removing project: $ProjectName..." -ForegroundColor Yellow

try {
    # Load registry
    $registryPath = "$HOME/.claude-automation/registry.json"

    if (-not (Test-Path $registryPath)) {
        Write-Error "No registry found. No projects are registered."
        exit 1
    }

    $registry = Get-Content $registryPath -Raw | ConvertFrom-Json

    # Check if project exists
    if (-not $registry.projects.$ProjectName) {
        Write-Error "Project not found in registry: $ProjectName"
        exit 1
    }

    # Get project info before removing
    $project = $registry.projects.$ProjectName

    # Remove from registry
    $registry.projects.PSObject.Properties.Remove($ProjectName)
    $registry.lastUpdated = Get-Date -Format "o"

    # Save registry
    $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath -Force

    Write-Host "✅ Project removed from registry" -ForegroundColor Green

    # Optionally remove state files
    if (-not $KeepState) {
        # Load project config to find state directory
        if (Test-Path $project.configPath) {
            $config = Get-Content $project.configPath -Raw | ConvertFrom-Json
            $stateDir = Join-Path $config.repoPath ".claude-automation"

            if (Test-Path $stateDir) {
                $confirm = Read-Host "Delete state files in $stateDir ? (y/N)"
                if ($confirm -eq 'y') {
                    Remove-Item $stateDir -Recurse -Force
                    Write-Host "✅ State files removed" -ForegroundColor Green
                }
                else {
                    Write-Host "ℹ️  State files preserved" -ForegroundColor Gray
                }
            }
        }
    }
    else {
        Write-Host "ℹ️  State files preserved (-KeepState specified)" -ForegroundColor Gray
    }

    Write-Host "`n✅ Project unregistered: $ProjectName" -ForegroundColor Green
}
catch {
    Write-Error "Failed to remove project: $_"
    exit 1
}

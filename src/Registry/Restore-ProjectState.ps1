<#
.SYNOPSIS
    Functions for restoring project state after interruptions

.DESCRIPTION
    Provides comprehensive project state restoration capabilities including:
    - State file validation
    - Corrupted state handling
    - Automatic state recovery
    - Manual state restoration

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS05 - Project Management
    Work Item: WI-3.6 - Session Recovery System
#>

# Import dependencies
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/Get-RegisteredProjects.ps1"
. "$ScriptRoot/Update-ProjectState.ps1"
. "$ScriptRoot/../Logging/Write-WatchdogLog.ps1"

function Restore-ProjectState {
    <#
    .SYNOPSIS
        Restores a project's state from saved files

    .DESCRIPTION
        Attempts to restore project state from current-state.json.
        Handles corrupted files gracefully and validates restored state.

    .PARAMETER ProjectName
        Name of the project to restore

    .PARAMETER ValidateOnly
        Only validate the state file without restoring

    .EXAMPLE
        Restore-ProjectState -ProjectName "my-project"

    .EXAMPLE
        Restore-ProjectState -ProjectName "my-project" -ValidateOnly
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [switch]$ValidateOnly
    )

    try {
        # Get project configuration
        $projects = Get-RegisteredProjects
        $project = $projects | Where-Object { $_.Name -eq $ProjectName }

        if (-not $project) {
            throw "Project '$ProjectName' not found in registry"
        }

        # Locate state file
        $statePath = Join-Path $project.RepoPath ".claude-automation/current-state.json"

        if (-not (Test-Path $statePath)) {
            Write-Verbose "No state file found for $ProjectName at $statePath"
            return $null
        }

        # Read and validate state file
        Write-Verbose "Reading state file: $statePath"
        $stateContent = Get-Content $statePath -Raw

        if ([string]::IsNullOrWhiteSpace($stateContent)) {
            Write-Warning "State file is empty for $ProjectName"
            return $null
        }

        # Parse JSON
        try {
            $state = $stateContent | ConvertFrom-Json
        }
        catch {
            Write-Warning "State file is corrupted for $ProjectName: $_"

            # Attempt to backup corrupted file
            $backupPath = "$statePath.corrupted-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $statePath $backupPath -Force
            Write-Verbose "Corrupted state backed up to: $backupPath"

            return $null
        }

        # Validate required fields
        $requiredFields = @('status', 'lastActivity')
        $isValid = $true

        foreach ($field in $requiredFields) {
            if (-not $state.PSObject.Properties[$field]) {
                Write-Warning "State file missing required field: $field"
                $isValid = $false
            }
        }

        if (-not $isValid) {
            Write-Warning "State file for $ProjectName failed validation"
            return $null
        }

        if ($ValidateOnly) {
            Write-Verbose "State file validation passed for $ProjectName"
            return @{
                Valid = $true
                State = $state
            }
        }

        # Restore state
        Write-Verbose "Restoring state for $ProjectName"

        # Convert to hashtable for Update-ProjectState
        $stateUpdates = @{}
        foreach ($property in $state.PSObject.Properties) {
            $stateUpdates[$property.Name] = $property.Value
        }

        # Mark as restored
        $stateUpdates['restored'] = $true
        $stateUpdates['restoredAt'] = (Get-Date).ToString("o")

        Update-ProjectState -ProjectName $ProjectName -StateUpdates $stateUpdates

        Write-WatchdogLog -Message "State restored for project: $ProjectName" -Level "Info"

        return $state
    }
    catch {
        Write-Warning "Failed to restore state for $ProjectName: $_"
        Write-WatchdogLog -Message "State restoration failed for $ProjectName: $_" -Level "Error"
        return $null
    }
}

function Test-ProjectStateHealth {
    <#
    .SYNOPSIS
        Checks health of project state files

    .DESCRIPTION
        Validates all project state files and reports issues

    .EXAMPLE
        Test-ProjectStateHealth
    #>

    try {
        $projects = Get-RegisteredProjects

        $results = @()

        foreach ($project in $projects) {
            Write-Verbose "Checking state health for: $($project.Name)"

            $statePath = Join-Path $project.RepoPath ".claude-automation/current-state.json"

            $health = @{
                ProjectName = $project.Name
                StateFileExists = Test-Path $statePath
                IsValid = $false
                IsRecent = $false
                Issues = @()
            }

            if (-not $health.StateFileExists) {
                $health.Issues += "State file not found"
            }
            else {
                # Validate state
                $validation = Restore-ProjectState -ProjectName $project.Name -ValidateOnly

                if ($validation -and $validation.Valid) {
                    $health.IsValid = $true

                    # Check if state is recent (updated in last 24 hours)
                    try {
                        $lastActivity = [DateTime]::Parse($validation.State.lastActivity)
                        $age = (Get-Date) - $lastActivity

                        if ($age.TotalHours -le 24) {
                            $health.IsRecent = $true
                        }
                        else {
                            $health.Issues += "State is stale ($([math]::Round($age.TotalHours, 1))h old)"
                        }
                    }
                    catch {
                        $health.Issues += "Invalid lastActivity timestamp"
                    }
                }
                else {
                    $health.Issues += "State validation failed"
                }
            }

            $results += [PSCustomObject]$health
        }

        return $results
    }
    catch {
        Write-Error "Failed to check state health: $_"
        return @()
    }
}

function Repair-ProjectState {
    <#
    .SYNOPSIS
        Attempts to repair corrupted project state

    .DESCRIPTION
        Tries to repair or reset corrupted project state files

    .PARAMETER ProjectName
        Name of the project to repair

    .PARAMETER Reset
        Reset to initial state instead of attempting repair

    .EXAMPLE
        Repair-ProjectState -ProjectName "my-project"

    .EXAMPLE
        Repair-ProjectState -ProjectName "my-project" -Reset
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter()]
        [switch]$Reset
    )

    try {
        Write-Host "🔧 Repairing state for: $ProjectName" -ForegroundColor Cyan

        $projects = Get-RegisteredProjects
        $project = $projects | Where-Object { $_.Name -eq $ProjectName }

        if (-not $project) {
            throw "Project '$ProjectName' not found"
        }

        $statePath = Join-Path $project.RepoPath ".claude-automation/current-state.json"

        if ($Reset -or -not (Test-Path $statePath)) {
            # Reset to initial state
            Write-Host "  Resetting to initial state..." -ForegroundColor Yellow

            $initialState = @{
                status = "Initialized"
                lastActivity = (Get-Date).ToString("o")
                todosRemaining = 0
                todosCompleted = 0
                decisions = 0
                errors = @()
                sessionId = $null
                repairedAt = (Get-Date).ToString("o")
            }

            # Ensure directory exists
            $stateDir = Split-Path $statePath
            if (-not (Test-Path $stateDir)) {
                New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
            }

            # Save initial state
            $initialState | ConvertTo-Json -Depth 10 | Set-Content $statePath -Force

            Write-Host "  ✅ State reset successfully" -ForegroundColor Green
            Write-WatchdogLog -Message "State reset for project: $ProjectName" -Level "Info"
        }
        else {
            # Attempt repair
            Write-Host "  Attempting to repair existing state..." -ForegroundColor Yellow

            # Backup current state
            $backupPath = "$statePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $statePath $backupPath -Force
            Write-Verbose "Backed up state to: $backupPath"

            # Try to fix common issues
            $content = Get-Content $statePath -Raw

            # Fix trailing commas
            $content = $content -replace ',\s*}', '}'
            $content = $content -replace ',\s*]', ']'

            # Try to parse
            try {
                $state = $content | ConvertFrom-Json

                # Ensure required fields exist
                if (-not $state.PSObject.Properties['status']) {
                    $state | Add-Member -NotePropertyName 'status' -NotePropertyValue 'Unknown' -Force
                }

                if (-not $state.PSObject.Properties['lastActivity']) {
                    $state | Add-Member -NotePropertyName 'lastActivity' -NotePropertyValue (Get-Date).ToString("o") -Force
                }

                # Save repaired state
                $state | ConvertTo-Json -Depth 10 | Set-Content $statePath -Force

                Write-Host "  ✅ State repaired successfully" -ForegroundColor Green
                Write-WatchdogLog -Message "State repaired for project: $ProjectName" -Level "Info"
            }
            catch {
                Write-Host "  ❌ Repair failed, resetting to initial state..." -ForegroundColor Red
                Repair-ProjectState -ProjectName $ProjectName -Reset
            }
        }
    }
    catch {
        Write-Error "Failed to repair state for $ProjectName: $_"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Restore-ProjectState',
    'Test-ProjectStateHealth',
    'Repair-ProjectState'
)

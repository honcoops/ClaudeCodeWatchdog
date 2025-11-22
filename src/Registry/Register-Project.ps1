<#
.SYNOPSIS
    Registers a new project with the Claude Code Watchdog

.DESCRIPTION
    Validates and registers a project configuration with the central registry

.PARAMETER ProjectName
    Name of the project to register

.PARAMETER ConfigPath
    Path to the project configuration JSON file

.EXAMPLE
    .\Register-Project.ps1 -ProjectName "my-project" -ConfigPath "C:\repos\my-project\.claude-automation\project-config.json"

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$ConfigPath
)

# Import required modules
$ScriptRoot = Split-Path -Parent $PSCommandPath
. "$ScriptRoot/Get-RegisteredProjects.ps1"
. "$ScriptRoot/Update-ProjectState.ps1"

function Register-Project {
    <#
    .SYNOPSIS
        Registers a project with the watchdog
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ConfigurationPath
    )

    Write-Host "📝 Registering project: $Name..." -ForegroundColor Cyan

    # Validate config file exists
    if (-not (Test-Path $ConfigurationPath)) {
        throw "Configuration file not found: $ConfigurationPath"
    }

    # Load and validate configuration
    try {
        $config = Get-Content $ConfigurationPath -Raw | ConvertFrom-Json
        Test-ProjectConfiguration -Config $config
    }
    catch {
        throw "Invalid configuration file: $_"
    }

    # Load or create registry
    $registryPath = "$HOME/.claude-automation/registry.json"
    if (Test-Path $registryPath) {
        $registry = Get-Content $registryPath -Raw | ConvertFrom-Json
    }
    else {
        $registry = @{
            version = "1.0"
            lastUpdated = Get-Date -Format "o"
            projects = @{}
        }
    }

    # Add project to registry
    if (-not $registry.projects) {
        $registry.projects = @{}
    }

    $registry.projects.$Name = @{
        configPath = $ConfigurationPath
        registeredAt = Get-Date -Format "o"
        status = "Active"
        lastChecked = $null
        sessionId = $null
    }

    $registry.lastUpdated = Get-Date -Format "o"

    # Save registry
    $registry | ConvertTo-Json -Depth 10 | Set-Content $registryPath -Force

    # Initialize project state
    Initialize-ProjectState -ProjectName $Name -Config $config

    Write-Host "✅ Project registered successfully: $Name" -ForegroundColor Green
    Write-Host "   Config: $ConfigurationPath" -ForegroundColor Gray
}

function Test-ProjectConfiguration {
    <#
    .SYNOPSIS
        Validates a project configuration
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    $requiredFields = @('projectName', 'repoPath', 'repoUrl')

    foreach ($field in $requiredFields) {
        if (-not $Config.$field) {
            throw "Missing required field in config: $field"
        }
    }

    # Validate repo path exists
    if (-not (Test-Path $Config.repoPath)) {
        throw "Repository path does not exist: $($Config.repoPath)"
    }

    Write-Verbose "Configuration validated"
}

function Initialize-ProjectState {
    <#
    .SYNOPSIS
        Initializes state files for a new project
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [object]$Config
    )

    $stateDir = Join-Path $Config.repoPath ".claude-automation"

    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    # Create initial state file
    $state = @{
        projectName = $ProjectName
        currentPhase = "not-started"
        phaseStartedAt = $null
        status = "Idle"
        lastActivity = $null
        todosRemaining = 0
        todosCompleted = 0
        decisions = 0
        commits = 0
        apiCalls = 0
        totalCost = 0.0
        errors = @()
        warnings = @()
        currentBranch = $null
        lastCommand = $null
    }

    $statePath = Join-Path $stateDir "current-state.json"
    $state | ConvertTo-Json -Depth 10 | Set-Content $statePath -Force

    # Create decision log
    $logPath = Join-Path $stateDir "decision-log.md"
    $logHeader = @"
# Decision Log - $ProjectName

Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

---

"@
    $logHeader | Set-Content $logPath -Force

    Write-Verbose "Project state initialized at $stateDir"
}

# Entry point
Register-Project -Name $ProjectName -ConfigurationPath $ConfigPath

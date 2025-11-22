<#
.SYNOPSIS
    Lists all registered projects

.DESCRIPTION
    Displays all projects registered with the Claude Code Watchdog

.EXAMPLE
    .\Get-RegisteredProjects.ps1

.NOTES
    Part of the Claude Code Watchdog project
#>

$scriptPath = Join-Path $PSScriptRoot "src/Registry/Get-RegisteredProjects.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Get-RegisteredProjects.ps1 not found at $scriptPath"
    exit 1
}

# Source the function
. $scriptPath

# Get and display projects
$projects = Get-RegisteredProjects

if ($projects.Count -eq 0) {
    Write-Host "No projects registered yet." -ForegroundColor Yellow
    Write-Host "Use .\Register-Project.ps1 to add a project." -ForegroundColor Gray
}
else {
    Write-Host "`n📋 Registered Projects ($($projects.Count)):`n" -ForegroundColor Cyan

    foreach ($project in $projects) {
        Write-Host "  🔹 $($project.Name)" -ForegroundColor White
        Write-Host "     Status: $($project.Status)" -ForegroundColor Gray
        Write-Host "     Config: $($project.ConfigPath)" -ForegroundColor Gray
        Write-Host "     Registered: $($project.RegisteredAt)" -ForegroundColor Gray

        if ($project.SessionId) {
            Write-Host "     Session: $($project.SessionId)" -ForegroundColor Gray
        }

        if ($project.LastChecked) {
            Write-Host "     Last Checked: $($project.LastChecked)" -ForegroundColor Gray
        }

        Write-Host ""
    }
}

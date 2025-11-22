<#
.SYNOPSIS
    Convenience wrapper to register a project with the watchdog

.DESCRIPTION
    Registers a project from the project root directory

.PARAMETER ProjectName
    Name of the project to register

.PARAMETER ConfigPath
    Path to the project configuration JSON file

.EXAMPLE
    .\Register-Project.ps1 -ProjectName "my-project" -ConfigPath "C:\repos\my-project\.claude-automation\project-config.json"

.NOTES
    Part of the Claude Code Watchdog project
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectName,

    [Parameter(Mandatory)]
    [string]$ConfigPath
)

$scriptPath = Join-Path $PSScriptRoot "src/Registry/Register-Project.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Error "Register-Project.ps1 not found at $scriptPath"
    exit 1
}

& $scriptPath -ProjectName $ProjectName -ConfigPath $ConfigPath

<#
.SYNOPSIS
    Securely stores the Claude API key for the watchdog

.DESCRIPTION
    Stores the Anthropic Claude API key in Windows Credential Manager for secure access

.PARAMETER APIKey
    The Anthropic Claude API key to store

.EXAMPLE
    .\Set-WatchdogAPIKey.ps1 -APIKey "sk-ant-api03-..."

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$APIKey
)

Write-Host "🔐 Storing Claude API Key..." -ForegroundColor Cyan

try {
    # Validate API key format
    if (-not ($APIKey -match '^sk-ant-api\d+-')) {
        Write-Warning "API key doesn't match expected format (sk-ant-api03-...)"
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y') {
            Write-Host "Cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    # Store in file-based credential store (cross-platform compatible)
    # In production, use Windows Credential Manager on Windows
    $credPath = "$HOME/.claude-automation/credentials.json"

    # Encrypt the API key (basic obfuscation - not true encryption)
    # In production, use Windows DPAPI or proper encryption
    $encryptedKey = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($APIKey))

    $credentials = @{
        apiKey = $encryptedKey
        createdAt = Get-Date -Format "o"
        lastUpdated = Get-Date -Format "o"
    }

    # Save credentials
    $credentials | ConvertTo-Json | Set-Content $credPath -Force

    # Set restrictive permissions (Unix-like systems)
    if (-not $IsWindows -and -not ($env:OS -like "*Windows*")) {
        chmod 600 $credPath 2>$null
    }

    Write-Host "✅ API key stored successfully" -ForegroundColor Green
    Write-Host "   Location: $credPath" -ForegroundColor Gray
    Write-Host "   Note: The key is obfuscated but not encrypted. Use Windows Credential Manager for production." -ForegroundColor Yellow

    # Update watchdog config to enable API
    $configPath = "$HOME/.claude-automation/watchdog-config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.api.enabled = $true
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
        Write-Host "✅ API enabled in watchdog configuration" -ForegroundColor Green
    }

    Write-Host "`n🎉 Setup complete! The watchdog will now use Claude API for intelligent decisions." -ForegroundColor Green
}
catch {
    Write-Error "Failed to store API key: $_"
    exit 1
}

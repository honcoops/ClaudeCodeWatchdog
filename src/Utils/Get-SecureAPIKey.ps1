<#
.SYNOPSIS
    Retrieves the securely stored Claude API key

.DESCRIPTION
    Loads and decrypts the Claude API key from secure storage

.NOTES
    Part of the Claude Code Watchdog project
    Workstream: WS01 - Core Infrastructure
#>

function Get-SecureAPIKey {
    <#
    .SYNOPSIS
        Retrieves the Claude API key from secure storage
    #>

    $credPath = "$HOME/.claude-automation/credentials.json"

    if (-not (Test-Path $credPath)) {
        Write-Error "No API key found. Run Set-WatchdogAPIKey.ps1 to configure."
        return $null
    }

    try {
        $credentials = Get-Content $credPath -Raw | ConvertFrom-Json

        # Decrypt the API key (reverse of Set-WatchdogAPIKey.ps1 obfuscation)
        $apiKey = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($credentials.apiKey))

        return $apiKey
    }
    catch {
        Write-Error "Failed to retrieve API key: $_"
        return $null
    }
}

function Test-APIKeyConfigured {
    <#
    .SYNOPSIS
        Checks if an API key is configured
    #>

    $credPath = "$HOME/.claude-automation/credentials.json"
    return (Test-Path $credPath)
}

function Remove-APIKey {
    <#
    .SYNOPSIS
        Removes the stored API key
    #>

    $credPath = "$HOME/.claude-automation/credentials.json"

    if (Test-Path $credPath) {
        Remove-Item $credPath -Force
        Write-Host "✅ API key removed" -ForegroundColor Green

        # Disable API in config
        $configPath = "$HOME/.claude-automation/watchdog-config.json"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.api.enabled = $false
            $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
            Write-Host "✅ API disabled in configuration" -ForegroundColor Green
        }
    }
    else {
        Write-Host "ℹ️  No API key found" -ForegroundColor Gray
    }
}

# Export functions
Export-ModuleMember -Function Get-SecureAPIKey, Test-APIKeyConfigured, Remove-APIKey
